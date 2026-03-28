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

// MARK: - Dolphin View

private struct DolphinView: View {
    let mood: IrukaMood
    let size: CGFloat

    var body: some View {
        ZStack {
            // 背びれ
            DorsalFin()
                .fill(LinearGradient(
                    colors: [Color(hex: "5BA3DC"), Color(hex: "3578B5")],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: size * 0.26, height: size * 0.2)
                .offset(y: -size * 0.46)

            // メインボディ（楕円）
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(hex: "6DB8EC"), Color(hex: "3A7BBF")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: size * 0.88, height: size * 0.76)
                .shadow(color: Color(hex: "3A7BBF").opacity(0.3), radius: 12, y: 6)

            // お腹（明るい楕円）
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(hex: "D8EEFA"), Color(hex: "A8D5F0")],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: size * 0.46, height: size * 0.48)
                .offset(y: size * 0.11)

            // 顔パーツ
            VStack(spacing: size * 0.055) {
                HStack(spacing: size * 0.18) {
                    EyeWithBrow(mood: mood, size: size * 0.13, isLeft: true)
                    EyeWithBrow(mood: mood, size: size * 0.13, isLeft: false)
                }
                MouthView(mood: mood, size: size * 0.28)
            }
            .offset(y: -size * 0.08)

            // ほっぺ
            HStack(spacing: size * 0.42) {
                Ellipse()
                    .fill(Color.pink.opacity(mood == .pleading ? 0.5 : 0.25))
                    .frame(width: size * 0.12, height: size * 0.08)
                Ellipse()
                    .fill(Color.pink.opacity(mood == .pleading ? 0.5 : 0.25))
                    .frame(width: size * 0.12, height: size * 0.08)
            }
            .offset(y: size * 0.08)

            // 胸ヒレ（左右）- ボディ下寄りの側面から横向きに張り出す
            // SwiftUI: Y↓ なのでポジティブ y オフセット = 画面下方 = ボディ下部
            ForEach([CGFloat(-1), CGFloat(1)], id: \.self) { sign in
                PectoralFin(isLeft: sign < 0)
                    .fill(LinearGradient(
                        colors: [Color(hex: "5BA3DC"), Color(hex: "3578B5")],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: size * 0.28, height: size * 0.20)
                    .offset(x: sign * size * 0.56, y: size * 0.18)
            }

            // スナウト（クチバシ）
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(hex: "8BCAE8"), Color(hex: "5BA3DC")],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: size * 0.22, height: size * 0.13)
                .offset(y: size * 0.43)
        }
        .frame(width: size, height: size * 1.05)
    }
}

// MARK: - Dorsal Fin Shape

private struct DorsalFin: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let w = rect.width
            let h = rect.height
            path.move(to: CGPoint(x: w * 0.12, y: h))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.52, y: 0),
                control: CGPoint(x: w * 0.08, y: h * 0.2)
            )
            path.addQuadCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.9),
                control: CGPoint(x: w * 0.82, y: h * 0.12)
            )
            path.closeSubpath()
        }
    }
}

// MARK: - Pectoral Fin Shape

private struct PectoralFin: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        // 付け根: ボディ側の端（isLeft なら右端 = x≈w、isRight なら左端 = x≈0）
        let rootX: CGFloat = isLeft ? w * 0.85 : w * 0.15
        let tipX:  CGFloat = isLeft ? 0         : w

        return Path { path in
            // 付け根の上縁
            path.move(to: CGPoint(x: rootX, y: h * 0.20))
            // 上縁カーブ → 先端上
            path.addQuadCurve(
                to:      CGPoint(x: tipX + (rootX - tipX) * 0.12, y: h * 0.28),
                control: CGPoint(x: rootX + (tipX - rootX) * 0.50, y: h * 0.05)
            )
            // 先端の丸み（上→下）
            path.addQuadCurve(
                to:      CGPoint(x: tipX + (rootX - tipX) * 0.12, y: h * 0.72),
                control: CGPoint(x: tipX - (rootX - tipX) * 0.08, y: h * 0.50)
            )
            // 下縁カーブ → 付け根の下縁
            path.addQuadCurve(
                to:      CGPoint(x: rootX, y: h * 0.80),
                control: CGPoint(x: rootX + (tipX - rootX) * 0.45, y: h * 0.95)
            )
            path.closeSubpath()
        }
    }
}

// MARK: - Eye With Brow

private struct EyeWithBrow: View {
    let mood: IrukaMood
    let size: CGFloat
    let isLeft: Bool

    private var browAngle: Double {
        switch mood {
        case .concerned: return isLeft ? 12 : -12    // ハの字（困り）
        case .alarmed:   return isLeft ? -12 : 12    // 逆ハの字（驚き）
        case .smug:      return isLeft ? 4 : -18     // 片眉上げ
        case .pleading:  return isLeft ? 22 : -22    // 強ハの字（お願い）
        case .greeting:  return isLeft ? -8 : 8      // ハの字（嬉しい）
        }
    }

    var body: some View {
        VStack(spacing: size * 0.22) {
            Capsule()
                .fill(Color(hex: "2C3E50"))
                .frame(width: size * 1.1, height: size * 0.22)
                .rotationEffect(.degrees(browAngle))
            EyeView(mood: mood, size: size)
        }
    }
}

// MARK: - Eye

private struct EyeView: View {
    let mood: IrukaMood
    let size: CGFloat

    var body: some View {
        switch mood {
        case .concerned:
            // 少し困り気味の丸目
            ZStack {
                Circle().fill(.white).frame(width: size * 1.2)
                Circle().fill(Color(hex: "2C3E50")).frame(width: size * 0.82)
                Circle().fill(.white).frame(width: size * 0.28)
                    .offset(x: -size * 0.14, y: -size * 0.14)
            }

        case .alarmed:
            // 大きな驚き目（白目多め）
            ZStack {
                Circle().fill(.white).frame(width: size * 1.55)
                Circle().fill(Color(hex: "2C3E50")).frame(width: size * 0.75)
                Circle().fill(.white).frame(width: size * 0.26)
                    .offset(x: -size * 0.1, y: -size * 0.14)
            }

        case .smug:
            // 半目（横長の眠そうな目）
            ZStack {
                Capsule().fill(.white).frame(width: size * 1.3, height: size * 0.75)
                Capsule().fill(Color(hex: "2C3E50")).frame(width: size * 0.75, height: size * 0.42)
            }

        case .pleading:
            // うるうる目（大きめ瞳＋ハイライト2つ）
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
            // ^^ 笑い目（アーチ型）
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

// MARK: - Mouth

private struct MouthView: View {
    let mood: IrukaMood
    let size: CGFloat

    var body: some View {
        switch mood {
        case .concerned:
            // 緩やかなへの字
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
            // O型口（びっくり）
            Ellipse()
                .fill(Color(hex: "2C3E50"))
                .frame(width: size * 0.3, height: size * 0.36)

        case .smug:
            // 片側ニヤリ
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
            // への字（困り口）
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
            // 大きな笑顔（ドルフィンスマイル）
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
