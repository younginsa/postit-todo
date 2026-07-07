import SwiftUI

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let tint: Color
    let dx: CGFloat      // 가로 속도
    let dy: CGFloat      // 처음 세로 속도(위로 = 음수)
    let size: CGFloat
    let rot: Double      // 회전량
    let delay: Double    // 약간씩 시차
    let isSparkle: Bool  // true = ✦ 반짝이, false = 작은 가루 점
    let twinkle: Double  // 반짝임 위상
}

/// 삭제할 때 흰빛 '별가루(star dust)'가 팡 흩어지며 반짝이다 사라진다. 한 번 재생.
struct ConfettiView: View {
    var debugProgress: Double? = nil
    @State private var prog: Double = 0

    // 네온 파스텔 — 밝은 파스텔 + 글로우로 네온처럼 반짝인다.
    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.62, blue: 0.85),   // 네온 핑크
        Color(red: 0.62, green: 1.00, blue: 0.85),   // 민트
        Color(red: 0.78, green: 0.66, blue: 1.00),   // 라벤더
        Color(red: 0.62, green: 0.85, blue: 1.00),   // 스카이
        Color(red: 1.00, green: 0.84, blue: 0.58),   // 피치
        Color(red: 0.98, green: 0.98, blue: 0.60)    // 레몬
    ]

    private let pieces: [ConfettiPiece] = (0..<26).map { _ in
        ConfettiPiece(
            tint: palette.randomElement() ?? .white,
            dx: CGFloat.random(in: -130...130),
            dy: CGFloat.random(in: -250 ... -110),
            size: CGFloat.random(in: 5...13),
            rot: Double.random(in: 0.5...2.5),
            delay: Double.random(in: 0...0.08),
            isSparkle: Double.random(in: 0...1) < 0.62,
            twinkle: Double.random(in: 0...6.28)
        )
    }

    private let gravity: CGFloat = 360

    var body: some View {
        let p = debugProgress ?? prog
        ZStack {
            ForEach(pieces) { piece in
                let local = max(0, min(1, (p - piece.delay) / (1 - piece.delay)))
                let x = piece.dx * local
                let y = piece.dy * local + gravity * local * local
                let fade = local < 0.55 ? 1 : max(0, 1 - (local - 0.55) / 0.45)
                // 깜빡깜빡 반짝임
                let twinkle = 0.5 + 0.5 * sin(piece.twinkle + local * 16)
                Group {
                    if piece.isSparkle {
                        Image(systemName: "sparkle")
                            .font(.system(size: piece.size))
                            .foregroundStyle(piece.tint)
                    } else {
                        Circle()
                            .fill(piece.tint)
                            .frame(width: piece.size * 0.45, height: piece.size * 0.45)
                    }
                }
                .shadow(color: piece.tint.opacity(0.95), radius: 4)   // 네온 글로우(빛번짐)
                .rotationEffect(.degrees(piece.rot * local * 360))
                .offset(x: x, y: y)
                .opacity(local <= 0 ? 0 : fade * twinkle)
            }
        }
        .task {
            guard debugProgress == nil else { return }
            let steps = 42
            for s in 0...steps {
                prog = Double(s) / Double(steps)
                try? await Task.sleep(nanoseconds: 16_000_000)   // ~60fps, 총 ≈0.67초
            }
        }
    }
}
