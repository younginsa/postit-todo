import AppIntents
import WidgetKit

/// 위젯 탭 → 다음 3개 페이지로. 끝까지 가면 처음으로 순환.
/// iOS 17 interactive widget: Button(intent:)에 연결된다.
struct CyclePageIntent: AppIntent {
    static var title: LocalizedStringResource = "다음 페이지"

    func perform() async throws -> some IntentResult {
        let count = NoteStore.loadNotes().count
        let pages = NoteStore.pageCount(for: count)
        let next = (NoteStore.loadPageIndex() + 1) % pages
        NoteStore.savePageIndex(next)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 이전 메모로. 처음에서 누르면 마지막으로 순환.
struct PrevPageIntent: AppIntent {
    static var title: LocalizedStringResource = "이전 메모"

    func perform() async throws -> some IntentResult {
        let count = NoteStore.loadNotes().count
        let pages = NoteStore.pageCount(for: count)
        let prev = (NoteStore.loadPageIndex() - 1 + pages) % pages
        NoteStore.savePageIndex(prev)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 위젯에서 지금 보이는 메모를 삭제하고 다음 메모를 보여준다.
struct DeleteCurrentNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "메모 삭제"

    func perform() async throws -> some IntentResult {
        var notes = NoteStore.loadNotes()   // 최신순
        guard !notes.isEmpty else { return .result() }

        let pages = NoteStore.pageCount(for: notes.count)
        let page = ((NoteStore.loadPageIndex() % pages) + pages) % pages
        let target = notes[page]
        notes.removeAll { $0.id == target.id }
        NoteStore.saveNotes(notes)

        // 삭제 후 같은 자리(=다음 메모)를 보여주되, 끝을 넘으면 마지막으로.
        let newCount = notes.count
        let newPage = newCount == 0 ? 0 : min(page, newCount - 1)
        NoteStore.savePageIndex(newPage)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
