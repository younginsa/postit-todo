import WidgetKit
import SwiftUI

struct GoogitEntry: TimelineEntry {
    let date: Date
    let notes: [Note]   // 현재 페이지의 메모(최대 3개)
    let page: Int
    let pageCount: Int
    var upNext: [Note] = []   // 홈 위젯 미디엄: 다음 할일 미리보기
    var total: Int = 0
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
        // 현재 메모 다음 순서의 할일 최대 4개 (끝이면 앞에서 이어서, 현재 것 제외)
        var upNext: [Note] = []
        if all.count > 1, let currentIdx = slice.first.flatMap({ n in all.firstIndex(where: { $0.id == n.id }) }) {
            for offset in 1..<all.count where upNext.count < 4 {
                upNext.append(all[(currentIdx + offset) % all.count])
            }
        }
        return GoogitEntry(date: Date(), notes: slice, page: page, pageCount: pageCount,
                           upNext: upNext, total: all.count)
    }
}

struct GoogitWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: GoogitEntry

    var body: some View {
        switch family {
        case .systemSmall:
            HomeSmallView(entry: entry)
                .containerBackground(for: .widget) { PostItPalette.canvas }
        case .systemMedium:
            HomeMediumView(entry: entry)
                .containerBackground(for: .widget) { PostItPalette.canvas }
        default:
            lockView
        }
    }

    private var lockView: some View {
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

// MARK: - 홈 화면 위젯 (③ 한 장 크게 + 다음 할일)

/// 스몰: 포스트잇 한 장이 위젯을 가득 채움. 좌하단 페이지, 우하단 ✓(완료).
struct HomeSmallView: View {
    let entry: GoogitEntry

    var body: some View {
        if let note = entry.notes.first {
            PostItCard(note: note, entry: entry, textSize: 16)
        } else {
            HomeEmptyView()
        }
    }
}

/// 미디엄: 왼쪽 포스트잇 한 장 + 오른쪽 '다음 할일' 미리보기.
struct HomeMediumView: View {
    let entry: GoogitEntry

    var body: some View {
        if let note = entry.notes.first {
            HStack(spacing: 14) {
                PostItCard(note: note, entry: entry, textSize: 15, showPage: false)
                    .frame(width: 132)

                VStack(alignment: .leading, spacing: 7) {
                    if !entry.upNext.isEmpty {
                        Text("다음 할일")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(PostItPalette.ink.opacity(0.4))
                        ForEach(entry.upNext) { next in
                            HStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(PostItPalette.color(for: next))
                                    .frame(width: 11, height: 11)
                                Text(next.text)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(PostItPalette.ink.opacity(0.75))
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Text("할일 \(entry.total)개 · 구깃")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PostItPalette.ink.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
        } else {
            HomeEmptyView()
        }
    }
}

/// 기울어진 포스트잇 카드 + ✓ 완료 버튼 (홈 위젯 공용).
struct PostItCard: View {
    let note: Note
    let entry: GoogitEntry
    var textSize: CGFloat
    var showPage: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(PostItPalette.color(for: note))
                .shadow(color: PostItPalette.ink.opacity(0.10), radius: 5, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 0) {
                Text(note.text)
                    .font(.system(size: textSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(PostItPalette.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 4)

                HStack {
                    if showPage {
                        Text(verbatim: "\(entry.page + 1) / \(entry.pageCount)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(PostItPalette.ink.opacity(0.45))
                    }
                    Spacer(minLength: 0)
                    Button(intent: DeleteCurrentNoteIntent()) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PostItPalette.ink.opacity(0.55))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(PostItPalette.ink.opacity(0.35), lineWidth: 1.6))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .rotationEffect(.degrees(PostItPalette.tilt(for: note)))
    }
}

struct HomeEmptyView: View {
    var body: some View {
        Text("머릿속을 비워보세요.\n아래에 적고 엔터.")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(PostItPalette.ink.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .supportedFamilies([.accessoryRectangular, .systemSmall, .systemMedium])
    }
}
