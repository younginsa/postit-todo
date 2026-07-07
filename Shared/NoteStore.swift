import Foundation
import WidgetKit

/// 메모 저장소. 추가 / 구기기(삭제) / 순서 바꾸기 / 색칠(카테고리).
/// 저장은 App Group 공유 UserDefaults에 JSON으로. (양이 적으니 DB 불필요)
/// 저장된 배열 순서 = 화면에 보이는 순서(수동 정렬).
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []

    /// 입력 글자 수 제한.
    static let maxLength = 40

    init() {
        migrateOrderIfNeeded()
        reload()
    }

    /// 공유 저장소에서 다시 읽어온다.
    func reload() {
        notes = NoteStore.loadNotes()
    }

    /// 추가: 40자로 자르고, 빈 문자열이면 무시. 맨 위(앞)에 꽂는다. 추가 후 위젯 갱신.
    /// colorIndex가 주어지면 그 카테고리 색으로 생성(현재 필터 색 등).
    func add(_ text: String, colorIndex: Int? = nil) {
        let trimmed = String(text.prefix(NoteStore.maxLength))
        guard !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        var current = NoteStore.loadNotes()
        current.insert(Note(text: trimmed, colorIndex: colorIndex), at: 0)   // 새 메모 = 맨 위
        NoteStore.saveNotes(current)
        NoteStore.savePageIndex(0)   // 새 메모가 보이도록 위젯을 첫 페이지로
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 구기기 = 영구 삭제. isDone 같은 플래그 없음. 삭제 후 위젯 갱신.
    func crumple(_ note: Note) {
        var current = NoteStore.loadNotes()
        current.removeAll { $0.id == note.id }
        NoteStore.saveNotes(current)
        NoteStore.savePageIndex(0)
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 드래그로 바꾼 순서를 그대로 저장. 위젯도 첫 페이지로 맞춰 새 1번이 보이게.
    func applyOrder(_ ordered: [Note]) {
        notes = ordered
        NoteStore.saveNotes(ordered)
        NoteStore.savePageIndex(0)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 메모를 물감 색으로 칠한다.
    func setColorIndex(_ index: Int, for id: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        var current = notes
        current[i].colorIndex = index
        notes = current
        NoteStore.saveNotes(current)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - 공유 저장소 (앱 + 위젯 공용)

    /// 저장된 순서 그대로 돌려준다(수동 정렬 보존). 정렬하지 않는다.
    static func loadNotes() -> [Note] {
        guard let data = AppGroup.defaults.data(forKey: AppGroup.notesKey),
              let decoded = try? JSONDecoder().decode([Note].self, from: data)
        else { return [] }
        return decoded
    }

    static func saveNotes(_ notes: [Note]) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        AppGroup.defaults.set(data, forKey: AppGroup.notesKey)
    }

    /// 1회성 이전: 예전엔 항상 최신순으로 보였으니, 업데이트 직후 한 번
    /// 최신순으로 고정해 저장한다(그 뒤로는 수동 순서 유지).
    private func migrateOrderIfNeeded() {
        let d = AppGroup.defaults
        guard !d.bool(forKey: NoteStore.orderMigratedKey) else { return }
        var current = NoteStore.loadNotes()
        current.sort { $0.createdAt > $1.createdAt }
        NoteStore.saveNotes(current)
        d.set(true, forKey: NoteStore.orderMigratedKey)
    }
    private static let orderMigratedKey = "orderMigrated_v1"

    // MARK: - 위젯 페이지 (탭 순환)

    static let pageSize = 1   // 위젯: 한 번에 한 장

    static func loadPageIndex() -> Int {
        AppGroup.defaults.integer(forKey: AppGroup.pageIndexKey)
    }

    static func savePageIndex(_ i: Int) {
        AppGroup.defaults.set(i, forKey: AppGroup.pageIndexKey)
    }

    /// 메모 수 기준 전체 페이지 수(최소 1).
    static func pageCount(for count: Int) -> Int {
        max(1, Int(ceil(Double(count) / Double(pageSize))))
    }
}
