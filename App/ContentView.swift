import SwiftUI
import WidgetKit
import UIKit

/// 종이 그레인 텍스처. 앱 시작 때 작은 노이즈 타일을 한 번 만들어 캐시 → 가볍게 반복(tile).
enum PaperTexture {
    static let tile: Image = {
        let n = 110
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: n, height: n))
        let ui = renderer.image { ctx in
            let c = ctx.cgContext
            for x in 0..<n {
                for y in 0..<n {
                    let v = CGFloat.random(in: 0...1)
                    if v < 0.55 { continue }                 // 대부분 투명
                    let alpha = (v - 0.55) * 0.16            // 아주 옅은 점만
                    let white: CGFloat = v < 0.78 ? 0.25 : 0.96   // 어두운/밝은 알갱이 섞기
                    c.setFillColor(UIColor(white: white, alpha: alpha).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        return Image(uiImage: ui).resizable(resizingMode: .tile)
    }()
}

struct ContentView: View {
    @EnvironmentObject private var store: NoteStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = ""
    @State private var crumpling: Set<UUID> = []
    @FocusState private var inputFocused: Bool

    // 드래그(집어 옮기기 / 색칠). @GestureState: 손 떼면 자동 초기화 → 붕 뜬 채 굳지 않음.
    @GestureState private var drag: ActiveDrag? = nil
    @State private var lastDrag: ActiveDrag? = nil
    @State private var lastLiftAt: Date? = nil
    @State private var hapticHover: Int? = nil
    @State private var pickedColor: Int? = nil          // 드래그 중 물감에 닿아 '묻힌' 색
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var paletteFrames: [Int: CGRect] = [:]
    @State private var selectedCategory: Int? = nil      // 색 탭 필터 (nil = 전체)

    private let rootSpace = "root"
    private var isDragging: Bool { drag != nil }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                wall
                palette
                inputBar
            }
            .coordinateSpace(name: rootSpace)

            // 손가락 따라다니는 '집어 든 메모' (묻힌 색 미리보기)
            if let d = drag, let note = store.notes.first(where: { $0.id == d.id }) {
                let preview = pickedColor ?? hoverIndex(d)
                let shown = preview.map { note.recolored($0) } ?? note
                let w = rowFrames[d.id]?.width ?? UIScreen.main.bounds.width - 36
                PostItView(note: shown)
                    .frame(width: w)
                    .scaleEffect(1.06)
                    .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 9)
                    .position(d.location)
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
        }
        .background(
            PostItPalette.canvas
                .overlay(PaperTexture.tile.opacity(0.5))
                .ignoresSafeArea()
        )
        .preferredColorScheme(.light)   // 라이트 전용 (다크 모드 따라가지 않음)
        .onAppear {
            if debugProgress != nil && store.notes.isEmpty { store.add("회의 자료 준비") }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reload()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .onChange(of: isDragging) { _, active in
            if active {
                lastLiftAt = Date()
                Feedback.lift()
            } else {
                if let d = lastDrag { commit(d) }
                lastDrag = nil
                hapticHover = nil
                pickedColor = nil
            }
        }
        .onChange(of: hoverIndexValue) { _, new in
            if let new {
                if new != hapticHover { Feedback.tick(); hapticHover = new }
                pickedColor = new       // 물감에 닿으면 그 색을 묻힌다(떼도 유지)
            } else {
                hapticHover = nil
            }
        }
        .onPreferenceChange(RowFrameKey.self) { rowFrames = $0 }
        .onPreferenceChange(PaletteFrameKey.self) { paletteFrames = $0 }
    }

    // MARK: - 포스트잇 벽
    private var wall: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(displayNotes) { note in
                    PostItView(
                        note: note,
                        isCrumpling: crumpling.contains(note.id) || isDebugTarget(note),
                        isGhost: drag?.id == note.id,
                        debugProgress: isDebugTarget(note) ? debugProgress : nil
                    )
                    .overlay { gripHandle(for: note) }   // 오른쪽 ☰ 손잡이만 드래그
                    .background(
                        GeometryReader { p in
                            Color.clear.preference(
                                key: RowFrameKey.self,
                                value: [note.id: p.frame(in: .named(rootSpace))]
                            )
                        }
                    )
                    .onTapGesture { crumple(note) }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .identity
                    ))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: orderToken)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollDisabled(isDragging)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if store.notes.isEmpty {
                Text("머릿속을 비워보세요.\n아래에 적고 엔터.")
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else if baseNotes.isEmpty {
                Text("이 색 메모가 없어요.\n색을 다시 탭하면 전체로 돌아가요.")
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 색 팔레트 (탭=필터, 메모를 끌어다 대면=색칠)
    private var palette: some View {
        VStack(spacing: 7) {
            Text(paletteHint)
                .font(.caption2)
                .foregroundStyle(hoverIndexValue != nil ? .primary : .secondary)
                .animation(.easeInOut(duration: 0.15), value: hoverIndexValue)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
                .animation(.easeInOut(duration: 0.15), value: selectedCategory)

            HStack(spacing: 18) {
                ForEach(PostItPalette.colors.indices, id: \.self) { i in
                    paintBlob(i)
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(PostItPalette.canvas)
        .overlay(alignment: .top) {
            Rectangle().fill(.separator).frame(height: 0.5)
        }
    }

    private var paletteHint: String {
        if hoverIndexValue != nil { return String(localized: "이 색으로 칠하기 🎨") }
        if isDragging && pickedColor != nil { return String(localized: "색 묻힌 채 이동 중 — 놓으면 적용") }
        if selectedCategory != nil { return String(localized: "이 색 메모만 보는 중 · 색 다시 탭 = 전체") }
        return String(localized: "색 탭 = 그 색만 보기 · 메모 끌어 색에 콕 = 색칠")
    }

    private func paintBlob(_ i: Int) -> some View {
        let color = PostItPalette.colors[i]
        let hovered = hoverIndexValue == i
        let selected = selectedCategory == i
        return Circle()
            .fill(color)
            .frame(width: 26, height: 26)
            .overlay(
                Circle().strokeBorder(PostItPalette.ink.opacity(selected ? 0.7 : (hovered ? 0.4 : 0.12)),
                                      lineWidth: (selected || hovered) ? 2.5 : 1)
            )
            .shadow(color: .black.opacity(hovered ? 0.18 : 0),
                    radius: hovered ? 6 : 0, x: 0, y: hovered ? 3 : 0)
            .scaleEffect(hovered ? 1.4 : (selected ? 1.18 : 1))
            .background(
                GeometryReader { p in
                    Color.clear.preference(
                        key: PaletteFrameKey.self,
                        value: [i: p.frame(in: .named(rootSpace))]
                    )
                }
            )
            .onTapGesture { toggleFilter(i) }
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: hovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }

    private func toggleFilter(_ i: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedCategory = (selectedCategory == i) ? nil : i
        }
        Feedback.tick()
    }

    // MARK: - 하단 입력 바
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("머릿속 메모…", text: $draft)
                .font(.system(size: 17, design: .rounded))
                .focused($inputFocused)
                .submitLabel(.send)
                .onChange(of: draft) { _, newValue in
                    if newValue.count > NoteStore.maxLength {
                        draft = String(newValue.prefix(NoteStore.maxLength))
                    }
                }
                .onSubmit(add)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                // 배경색 없이 옅은 테두리만 — 종이 위에서 살짝 보이게
                .overlay(Capsule().strokeBorder(PostItPalette.ink.opacity(0.15), lineWidth: 1))

            if !draft.isEmpty {
                Text("\(draft.count)/\(NoteStore.maxLength)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(draft.count >= NoteStore.maxLength ? .orange : .secondary)
            }

            Button(action: add) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(trimmed.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PostItPalette.canvas)
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var debugProgress: Double? {
        guard let v = ProcessInfo.processInfo.environment["CONF_P"], let d = Double(v) else { return nil }
        return d
    }
    private func isDebugTarget(_ note: Note) -> Bool {
        debugProgress != nil && note.id == store.notes.first?.id
    }

    /// 추가: 벽 맨 위에 pop. 현재 필터 색이 있으면 그 색(카테고리)으로 생성.
    private func add() {
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            store.add(draft, colorIndex: selectedCategory)
        }
        draft = ""
        inputFocused = true
    }

    /// 구기기 = 짧은 탭 → 별가루 + 햅틱 + 소리 → 영구 삭제.
    private func crumple(_ note: Note) {
        if isDragging { return }
        if let t = lastLiftAt, Date().timeIntervalSince(t) < 0.7 { return }
        guard !crumpling.contains(note.id) else { return }
        Feedback.crumple()
        withAnimation(.easeOut(duration: 0.25)) {
            _ = crumpling.insert(note.id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                store.crumple(note)
            }
            crumpling.remove(note.id)
        }
    }

    // MARK: - 집어 옮기기 / 색칠 (오른쪽 ☰ 손잡이 전용)

    private func gripHandle(for note: Note) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(PostItPalette.ink.opacity(drag?.id == note.id ? 0.5 : 0.28))
            .padding(.horizontal, 15)
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture(for: note))
            // 카드와 같은 각도로 기울여 손잡이도 오른쪽 정가운데
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .rotationEffect(.degrees(PostItPalette.tilt(for: note)))
    }

    private func dragGesture(for note: Note) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(rootSpace))
            .updating($drag) { value, state, _ in
                if state == nil {
                    state = ActiveDrag(id: note.id, location: value.location, startOrder: currentSlots())
                } else {
                    state?.location = value.location
                }
            }
            .onChanged { value in
                if lastDrag == nil {
                    lastDrag = ActiveDrag(id: note.id, location: value.location, startOrder: currentSlots())
                } else {
                    lastDrag?.location = value.location
                }
            }
    }

    /// 손 뗐을 때: 묻힌 색이 있으면 색칠 + (필터 아닐 때) 새 순서 저장.
    private func commit(_ d: ActiveDrag) {
        var didSomething = false
        if let ci = pickedColor {
            store.setColorIndex(ci, for: d.id)
            didSomething = true
        }
        // 필터 중이 아닐 때만 자리 이동 반영(필터 중엔 부분 목록이라 정렬 생략)
        if selectedCategory == nil, hoverIndex(d) == nil {
            let ordered = reordered(using: d)
            if ordered.map(\.id) != store.notes.map(\.id) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    store.applyOrder(ordered)
                }
                didSomething = true
            }
        }
        if didSomething { Feedback.tick() }
    }

    // MARK: - 파생 계산

    /// 필터 적용된 기본 목록(색 탭 시 그 색만).
    private var baseNotes: [Note] {
        guard let cat = selectedCategory else { return store.notes }
        return store.notes.filter { PostItPalette.colorIndex(for: $0) == cat }
    }

    /// 화면에 보일 순서(드래그 중이고 필터 아닐 때만 미리보기 재정렬).
    private var displayNotes: [Note] {
        guard selectedCategory == nil, let d = drag, hoverIndex(d) == nil else { return baseNotes }
        return reordered(using: d)
    }
    private var orderToken: [UUID] { displayNotes.map(\.id) }

    private var hoverIndexValue: Int? {
        guard let d = drag else { return nil }
        return hoverIndex(d)
    }
    private func hoverIndex(_ d: ActiveDrag) -> Int? {
        paletteFrames.first(where: { $0.value.insetBy(dx: -12, dy: -14).contains(d.location) })?.key
    }

    private func reordered(using d: ActiveDrag) -> [Note] {
        guard let dragged = store.notes.first(where: { $0.id == d.id }) else { return store.notes }
        let others = d.startOrder.filter { $0.id != d.id }
        let idx = min(others.filter { $0.midY < d.location.y }.count, others.count)
        var arr = store.notes.filter { $0.id != d.id }
        arr.insert(dragged, at: min(idx, arr.count))
        return arr
    }

    private func currentSlots() -> [DragSlot] {
        rowFrames.map { DragSlot(id: $0.key, midY: $0.value.midY) }.sorted { $0.midY < $1.midY }
    }
}

// MARK: - 드래그 상태 & 위치 수집용

struct ActiveDrag {
    let id: UUID
    var location: CGPoint
    let startOrder: [DragSlot]
}

struct DragSlot {
    let id: UUID
    let midY: CGFloat
}

struct RowFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct PaletteFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
