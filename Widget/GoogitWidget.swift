import WidgetKit
import SwiftUI

struct GoogitEntry: TimelineEntry {
    let date: Date
    let notes: [Note]   // 현재 페이지의 메모(최대 3개)
    let page: Int
    let pageCount: Int
}

struct GoogitProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoogitEntry {
        GoogitEntry(date: Date(), notes: [], page: 0, pageCount: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoogitEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoogitEntry>) -> Void) {
        // 데이터/페이지 변경 시 reloadAllTimelines()로 갱신되므로 자동 만료 불필요.
        completion(Timeline(entries: [makeEntry()], policy: .never))
    }

    private func makeEntry() -> GoogitEntry {
        let all = NoteStore.loadNotes()
        let pageCount = NoteStore.pageCount(for: all.count)
        let page = all.isEmpty ? 0 : ((NoteStore.loadPageIndex() % pageCount) + pageCount) % pageCount
        let start = page * NoteStore.pageSize
        let slice = start < all.count ? Array(all[start..<min(start + NoteStore.pageSize, all.count)]) : []
        return GoogitEntry(date: Date(), notes: slice, page: page, pageCount: pageCount)
    }
}

struct GoogitWidgetEntryView: View {
    var entry: GoogitEntry

    var body: some View {
        Group {
            if let note = entry.notes.first {
                // [도넛 링 + 가운데 ✓] | 메모 + 진행(현재/전체).  ✓ 탭 = 현재 메모 삭제(다음으로).
                HStack(spacing: 12) {
                    Button(intent: DeleteCurrentNoteIntent()) {
                        DonutRing(progress: Double(entry.page + 1) / Double(max(entry.pageCount, 1)))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text)
                            .font(.system(size: 15, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.65)
                        Text("\(entry.page + 1) / \(entry.pageCount)")
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.55)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.16))
                }
            } else {
                Text("구깃 — 비어있음")
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

/// 도넛 진행 링 + 가운데 체크(✓). 잠금화면 모노톤이라 흰색으로만 렌더된다.
struct DonutRing: View {
    let progress: Double   // 0~1 (현재 메모 위치 / 전체)

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.28), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.03, min(1, progress)))
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
        }
    }
}

struct GoogitWidget: Widget {
    let kind = "GoogitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoogitProvider()) { entry in
            GoogitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("구깃")
        .description("잠금화면의 최신 메모. ✓를 탭하면 완료돼요.")
        .supportedFamilies([.accessoryRectangular])
    }
}
