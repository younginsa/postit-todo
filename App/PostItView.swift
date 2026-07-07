import SwiftUI

/// 포스트잇 한 장. 종이처럼 살짝 기울어진 '무드 페이퍼' 카드.
/// 구길 때는 카드를 감추고 그 위에 별가루(confetti)를 얹는다.
struct PostItView: View {
    let note: Note
    var isCrumpling: Bool = false
    var isGhost: Bool = false           // 집어 든 메모의 빈 자리(흐릿하게)
    var debugProgress: Double? = nil    // 디버그: confetti 진행도 고정(검증용)

    var body: some View {
        ZStack {
            Text(note.text)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(PostItPalette.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 18)
                .padding(.trailing, 46)   // 오른쪽 ☰ 손잡이 자리 확보
                .padding(.vertical, 18)
                .background(PostItPalette.color(for: note))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .rotationEffect(.degrees(PostItPalette.tilt(for: note)))   // 살짝 기울기
                // 탭하면 쏙 사라짐(빠르게 작아지며 페이드)
                .scaleEffect(isCrumpling ? 0.15 : 1)
                // 집어 들면 원래 자리는 흐릿한 빈칸으로 남는다.
                .opacity(isCrumpling ? 0 : (isGhost ? 0.28 : 1))

            if isCrumpling {
                ConfettiView(debugProgress: debugProgress)
                    .allowsHitTesting(false)
            }
        }
    }
}
