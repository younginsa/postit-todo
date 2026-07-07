import Foundation

/// 포스트잇 한 장. 텍스트 수정은 없음 — 틀리면 구기고 새로 추가한다.
/// 순서는 저장된 배열 순서가 곧 화면 순서다(수동 정렬 가능).
struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String      // 최대 40자 (입력 단계에서 강제)
    let createdAt: Date
    /// 사용자가 물감으로 직접 칠한 색 인덱스. nil이면 id 기반 자동 색.
    var colorIndex: Int?

    init(id: UUID = UUID(), text: String, createdAt: Date = Date(), colorIndex: Int? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.colorIndex = colorIndex
    }

    /// 색만 바꾼 복사본 (드래그 중 미리보기용).
    func recolored(_ index: Int) -> Note {
        Note(id: id, text: text, createdAt: createdAt, colorIndex: index)
    }
}
