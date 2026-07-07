import SwiftUI
import UIKit

/// 포스트잇 색/기울기. 메모 id에서 안정적으로 결정 → 실행해도 같은 메모는 같은 색.
/// 앱과 위젯이 같은 색을 쓰도록 Shared에 둔다. 색은 라이트/다크에 따라 자동 전환.
enum PostItPalette {
    // 톤다운된 '무드 페이퍼' 팔레트. 라이트=밝은 종이색 / 다크=깊고 차분한 색(글자는 밝게).
    static let colors: [Color] = [
        adaptive(light: (0.961, 0.871, 0.659), dark: (0.431, 0.357, 0.180)),  // 머스타드
        adaptive(light: (0.957, 0.824, 0.831), dark: (0.431, 0.271, 0.282)),  // 더스티 로즈
        adaptive(light: (0.800, 0.875, 0.780), dark: (0.286, 0.361, 0.267)),  // 세이지
        adaptive(light: (0.824, 0.878, 0.894), dark: (0.267, 0.337, 0.361)),  // 더스티 블루
        adaptive(light: (0.929, 0.780, 0.608), dark: (0.431, 0.329, 0.212)),  // 주황(톤다운)
        adaptive(light: (0.902, 0.863, 0.937), dark: (0.325, 0.282, 0.380)),  // 라일락
    ]

    /// 배경(종이 캔버스): 라이트 아이보리 / 다크 웜 차콜.
    static let canvas = adaptive(light: (0.961, 0.949, 0.922), dark: (0.110, 0.106, 0.094))
    /// 글자색(잉크): 라이트 다크차콜 / 다크 웜 오프화이트.
    static let ink = adaptive(light: (0.227, 0.208, 0.184), dark: (0.925, 0.902, 0.855))

    /// 라이트/다크에 따라 자동으로 바뀌는 색.
    private static func adaptive(light: (CGFloat, CGFloat, CGFloat),
                                 dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }

    /// UUID 바이트 합 → 실행 간에도 안정적인 시드.
    private static func seed(for note: Note) -> Int {
        let u = note.id.uuid
        let bytes = [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
                     u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
        return bytes.reduce(0) { $0 + Int($1) }
    }

    /// 메모의 카테고리(색) 인덱스. 직접 칠한 색이 있으면 그것, 없으면 id 기반 자동 색.
    static func colorIndex(for note: Note) -> Int {
        if let i = note.colorIndex, colors.indices.contains(i) { return i }
        return seed(for: note) % colors.count
    }

    static func color(for note: Note) -> Color {
        colors[colorIndex(for: note)]
    }

    /// -1.5 ~ +1.5도 아주 살짝 기울기(차분하게).
    static func tilt(for note: Note) -> Double {
        (Double(seed(for: note) % 7) - 3) * 0.5
    }
}
