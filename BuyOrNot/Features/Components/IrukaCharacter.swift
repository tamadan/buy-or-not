import SwiftUI

/// イルカキャラクターの表情
/// NOTE: IrukaCharacter は将来的に別のキャラクターモデルへの差し替えを想定しています。
/// 差し替える場合は IrukaCharacter struct をまるごと置き換えてください。
/// 呼び出し側は mood / comment / size の3パラメータのみに依存しています。
enum IrukaMood {
    case concerned   // 心配顔（通常）
    case alarmed     // 驚き顔（実データで止める時）
    case smug        // ドヤ顔（論理で止めた時）
    case pleading    // お願い顔（「それでも買う」押す前）
    case greeting    // 笑顔（トップ画面の挨拶）
}

/// イルカキャラクター + 吹き出し
struct IrukaCharacter: View {
    let mood: IrukaMood
    let comment: String
    var size: CGFloat = 120

    @State private var bounceOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // 吹き出し
            SpeechBubble(text: comment)
                .padding(.horizontal, 24)

            // イルカ本体
            ZStack {
                // 体
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "69B4E8"), Color(hex: "4A90D9")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: Color(hex: "4A90D9").opacity(0.3), radius: 12, y: 6)

                // 顔パーツ
                VStack(spacing: 6) {
                    // 目
                    HStack(spacing: size * 0.2) {
                        EyeView(mood: mood, size: size * 0.12)
                        EyeView(mood: mood, size: size * 0.12)
                    }

                    // 口（くちばし的な）
                    MouthView(mood: mood, size: size * 0.3)
                }
                .offset(y: -size * 0.02)

                // ほっぺ
                HStack(spacing: size * 0.45) {
                    Circle()
                        .fill(Color.pink.opacity(0.25))
                        .frame(width: size * 0.13, height: size * 0.09)
                    Circle()
                        .fill(Color.pink.opacity(0.25))
                        .frame(width: size * 0.13, height: size * 0.09)
                }
                .offset(y: size * 0.06)
            }
            .offset(y: bounceOffset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    bounceOffset = -6
                }
            }
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
            // 普通の丸目（少し困り気味）
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: size * 1.2, height: size * 1.2)
                Circle()
                    .fill(Color(hex: "2C3E50"))
                    .frame(width: size, height: size)
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.35)
                    .offset(x: -size * 0.15, y: -size * 0.15)
            }

        case .alarmed:
            // 大きい驚き目
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: size * 1.5, height: size * 1.5)
                Circle()
                    .fill(Color(hex: "2C3E50"))
                    .frame(width: size * 0.8, height: size * 0.8)
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.35)
                    .offset(x: -size * 0.1, y: -size * 0.15)
            }

        case .smug:
            // ニヤリ半目
            Capsule()
                .fill(Color(hex: "2C3E50"))
                .frame(width: size * 1.3, height: size * 0.5)
                .offset(y: size * 0.1)

        case .pleading:
            // うるうる目
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: size * 1.4, height: size * 1.4)
                Circle()
                    .fill(Color(hex: "2C3E50"))
                    .frame(width: size * 1.0, height: size * 1.0)
                // 大きめハイライト
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.45)
                    .offset(x: -size * 0.15, y: -size * 0.15)
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: size * 0.25)
                    .offset(x: size * 0.15, y: size * 0.1)
            }

        case .greeting:
            // にっこり細目
            Capsule()
                .fill(Color(hex: "2C3E50"))
                .frame(width: size * 1.3, height: size * 0.45)
                .offset(y: -size * 0.05)
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
            // 横一文字（少し下がり気味）
            Path { path in
                path.move(to: CGPoint(x: 0, y: size * 0.3))
                path.addQuadCurve(
                    to: CGPoint(x: size, y: size * 0.3),
                    control: CGPoint(x: size * 0.5, y: size * 0.5)
                )
            }
            .stroke(Color(hex: "2C3E50"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size, height: size * 0.6)

        case .alarmed:
            // まん丸口（びっくり）
            Circle()
                .fill(Color(hex: "2C3E50"))
                .frame(width: size * 0.35, height: size * 0.35)

        case .smug:
            // ニヤリ
            Path { path in
                path.move(to: CGPoint(x: 0, y: size * 0.15))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.8, y: 0),
                    control: CGPoint(x: size * 0.4, y: size * 0.45)
                )
            }
            .stroke(Color(hex: "2C3E50"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size * 0.8, height: size * 0.5)

        case .pleading:
            // への字（お願い…）
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.7, y: 0),
                    control: CGPoint(x: size * 0.35, y: size * 0.35)
                )
            }
            .stroke(Color(hex: "2C3E50"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size * 0.7, height: size * 0.4)

        case .greeting:
            // 大きな笑顔
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: size, y: 0),
                    control: CGPoint(x: size * 0.5, y: size * 0.55)
                )
            }
            .stroke(Color(hex: "2C3E50"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size, height: size * 0.55)
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

            // 吹き出しの三角
            Triangle()
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 16, height: 10)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
        }
    }
}

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
}

#Preview("Alarmed") {
    IrukaCharacter(mood: .alarmed, comment: "レビュー荒れてるって！！")
        .padding()
}

#Preview("Smug") {
    IrukaCharacter(mood: .smug, comment: "3日待ってまだ欲しかったら\n買えばいいんじゃない？")
        .padding()
}

#Preview("Pleading") {
    IrukaCharacter(mood: .pleading, comment: "ほんとに買うの…？")
        .padding()
}
