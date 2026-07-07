import Foundation

/// 앱과 위젯이 같은 데이터를 보려면 반드시 App Group 공유 컨테이너를 써야 한다.
/// 앱 전용 저장소를 쓰면 위젯이 빈 화면이 된다.
enum AppGroup {
    /// App Group 식별자. 앱 타깃과 위젯 타깃 양쪽의 entitlement에 동일하게 들어가야 함.
    static let identifier = "group.com.younginsa.googit"

    static let notesKey = "notes"
    static let pageIndexKey = "pageIndex"

    /// 공유 UserDefaults suite. 앱/위젯 둘 다 여기로 읽고 쓴다.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
