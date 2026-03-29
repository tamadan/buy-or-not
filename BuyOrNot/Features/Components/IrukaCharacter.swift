import SwiftUI

/// イルカキャラクターの表情
/// NOTE: IrukaCharacter は将来的に別のキャラクターモデルへの差し替えを想定しています。
/// 差し替える場合は IrukaCharacter struct をまるごと置き換えてください。
/// 呼び出し側は mood / comment / size の3パラメータのみに依存しています。
enum IrukaMood {
    case concerned   // 心配顔（通常）
    case alarmed     // 驚き顔（止める時）
    case smug        // ドヤ顔（論理で止めた時）
    case pleading    // お願い顔（「それでも買う」押す前）
    case greeting    // 笑顔（トップ画面の挨拶）
}

// MARK: - IrukaCharacter

/// イルカキャラクター + 吹き出し
struct IrukaCharacter: View {
    let mood: IrukaMood
    let comment: String
    var size: CGFloat = 120

    @State private var bounceY: CGFloat = 0
    @State private var tiltDeg: Double = 0
    @State private var scaleVal: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            SpeechBubble(text: comment)
                .padding(.horizontal, 24)

            DolphinView(mood: mood, size: size)
                .offset(y: bounceY)
                .rotationEffect(.degrees(tiltDeg))
                .scaleEffect(scaleVal)
                .onAppear { startAnimation() }
        }
    }

    private func startAnimation() {
        switch mood {
        case .concerned:
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                bounceY = -5
                tiltDeg = 2
            }
        case .alarmed:
            withAnimation(.easeInOut(duration: 0.11).repeatForever(autoreverses: true)) {
                tiltDeg = 8
            }
        case .smug:
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                bounceY = -4
                tiltDeg = -3
            }
        case .pleading:
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                bounceY = -3
                scaleVal = 0.96
            }
        case .greeting:
            withAnimation(.interpolatingSpring(stiffness: 110, damping: 7).repeatForever(autoreverses: true)) {
                bounceY = -10
            }
        }
    }
}

// MARK: - Dolphin View（画像ベース + 表情オーバーレイ）

private struct DolphinView: View {
    let mood: IrukaMood
    let size: CGFloat

    // 顔パーツの位置定数（画像サイズに対する比率）
    // ずれを感じたらここの値を調整してください
    private var eyeSize:   CGFloat { size * 0.105 }  // 画像の白目円を完全に覆うため大きめに
    private var leftEyeX:  CGFloat { size * 0.375 }
    private var rightEyeX: CGFloat { size * 0.625 }
    private var eyeY:      CGFloat { size * 0.445 }
    private var browY:     CGFloat { size * 0.378 }
    private var mouthY:    CGFloat { size * 0.638 }
    private var cheekY:    CGFloat { size * 0.515 }

    private var leftBrowAngle: Double {
        switch mood {
        case .concerned: return  12
        case .alarmed:   return -12
        case .smug:      return   4
        case .pleading:  return  22
        case .greeting:  return  -8
        }
    }
    private var rightBrowAngle: Double {
        switch mood {
        case .concerned: return -12
        case .alarmed:   return  12
        case .smug:      return -18
        case .pleading:  return -22
        case .greeting:  return   8
        }
    }

    var body: some View {
        ZStack {
            // ── 土台画像 ──────────────────────────────────────────
            Image("iruka_base")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)

            // ── 目（左）────────────────────────────────────────────
            EyeView(mood: mood, size: eyeSize)
                .position(x: leftEyeX, y: eyeY)

            // ── 目（右）────────────────────────────────────────────
            EyeView(mood: mood, size: eyeSize)
                .position(x: rightEyeX, y: eyeY)

            // ── 眉（左）────────────────────────────────────────────
            Capsule()
                .fill(Color(hex: "2C3E50"))
                .frame(width: eyeSize * 1.1, height: eyeSize * 0.22)
                .rotationEffect(.degrees(leftBrowAngle))
                .position(x: leftEyeX, y: browY)

            // ── 眉（右）────────────────────────────────────────────
            Capsule()
                .fill(Color(hex: "2C3E50"))
                .frame(width: eyeSize * 1.1, height: eyeSize * 0.22)
                .rotationEffect(.degrees(rightBrowAngle))
                .position(x: rightEyeX, y: browY)

            // ── ほっぺ ─────────────────────────────────────────────
            Ellipse()
                .fill(Color.pink.opacity(mood == .pleading ? 0.55 : 0.28))
                .frame(width: size * 0.088, height: size * 0.058)
                .position(x: size * 0.292, y: cheekY)
            Ellipse()
                .fill(Color.pink.opacity(mood == .pleading ? 0.55 : 0.28))
                .frame(width: size * 0.088, height: size * 0.058)
                .position(x: size * 0.708, y: cheekY)

            // ── 口 ────────────────────────────────────────────────
            MouthView(mood: mood, size: size * 0.20)
                .position(x: size * 0.500, y: mouthY)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Eye

private struct EyeView: View {
    let mood: IrukaMood
    let size: CGFloat

    var body: some View {
        switch mood {
        case .concerned:
            ZStack {
                Circle().fill(.white).frame(width: size * 1.2)
                Circle().fill(Color(hex: "2C3E50")).frame(width: size * 0.82)
                Circle().fill(.white).frame(width: size * 0.28)
                    .offset(x: -size * 0.14, y: -size * 0.14)
            }

        case .alarmed:
            ZStack {
                Circle().fill(.white).frame(width: size * 1.55)
                Circle().fill(Color(hex: "2C3E50")).frame(width: size * 0.75)
                Circle().fill(.white).frame(width: size * 0.26)
                    .offset(x: -size * 0.1, y: -size * 0.14)
            }

        case .smug:
            ZStack {
                Capsule().fill(.white).frame(width: size * 1.3, height: size * 0.75)
                Capsule().fill(Color(hex: "2C3E50")).frame(width: size * 0.75, height: size * 0.42)
            }

        case .pleading:
            ZStack {
                Circle().fill(.white).frame(width: size * 1.5)
                Circle().fill(Color(hex: "2C3E50")).frame(width: size * 1.1)
                Circle().fill(Color(hex: "5BA3DC").opacity(0.35)).frame(width: size * 0.7)
                Circle().fill(.white).frame(width: size * 0.38)
                    .offset(x: -size * 0.2, y: -size * 0.2)
                Circle().fill(.white.opacity(0.55)).frame(width: size * 0.2)
                    .offset(x: size * 0.18, y: size * 0.12)
            }

        case .greeting:
            // ^^ 笑い目（アーチ型）— 白背景で画像の白目円を隠してからアーチを描く
            ZStack {
                Circle().fill(.white).frame(width: size * 1.5)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size * 0.5))
                    path.addQuadCurve(
                        to: CGPoint(x: size * 1.1, y: size * 0.5),
                        control: CGPoint(x: size * 0.55, y: 0)
                    )
                }
                .stroke(Color(hex: "2C3E50"),
                        style: StrokeStyle(lineWidth: size * 0.22, lineCap: .round))
                .frame(width: size * 1.1, height: size * 0.6)
            }
        }
    }
}

// MARK: - Mouth

private struct MouthView: View {
    let mood: IrukaMood
    let size: CGFloat

    var body: some View {
        switch mood {
        case .concerned:
            Path { path in
                path.move(to: CGPoint(x: 0, y: size * 0.18))
                path.addQuadCurve(
                    to: CGPoint(x: size, y: size * 0.18),
                    control: CGPoint(x: size * 0.5, y: size * 0.44)
                )
            }
            .stroke(Color(hex: "2C3E50"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size, height: size * 0.5)

        case .alarmed:
            Ellipse()
                .fill(Color(hex: "2C3E50"))
                .frame(width: size * 0.3, height: size * 0.36)

        case .smug:
            Path { path in
                path.move(to: CGPoint(x: size * 0.1, y: size * 0.25))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.85, y: 0),
                    control: CGPoint(x: size * 0.4, y: size * 0.52)
                )
            }
            .stroke(Color(hex: "2C3E50"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size * 0.85, height: size * 0.52)

        case .pleading:
            Path { path in
                path.move(to: CGPoint(x: size * 0.1, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.8, y: 0),
                    control: CGPoint(x: size * 0.45, y: size * 0.42)
                )
            }
            .stroke(Color(hex: "2C3E50"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size * 0.8, height: size * 0.42)

        case .greeting:
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: size, y: 0),
                    control: CGPoint(x: size * 0.5, y: size * 0.62)
                )
            }
            .stroke(Color(hex: "2C3E50"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: size, height: size * 0.62)
        }
    }
}

// MARK: - Speech Bubble

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color(.label))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                )

            Triangle()
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 16, height: 10)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
        }
    }
}

// MARK: - Triangle

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview("Concerned") {
    IrukaCharacter(mood: .concerned, comment: "いるか？それ？")
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Alarmed") {
    IrukaCharacter(mood: .alarmed, comment: "ちょっと待って！！")
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Smug") {
    IrukaCharacter(mood: .smug, comment: "3日待ってまだ欲しかったら\n買えばいいんじゃない？")
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Pleading") {
    IrukaCharacter(mood: .pleading, comment: "ほんとに買うの…？")
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Greeting") {
    IrukaCharacter(mood: .greeting, comment: "なにか買おうとしてる？")
        .padding()
        .background(Color(.systemGroupedBackground))
}
