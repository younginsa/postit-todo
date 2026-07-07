import SwiftUI

/// 종이 구기기 애니메이션 — uhqz06.gif에서 추출(검정 배경 제거·워터마크 제거·고해상도).
/// 처음 프레임(메모 모양일 때)만 메모 사각형으로 마스킹하고,
/// 공처럼 작아지는 뒷 프레임부터는 마스킹을 풀어 동그란 공이 잘리지 않게 한다.
struct CrumpleAnimationView: View {
    var tint: Color = .white
    var noteSize: CGSize
    var debugFrame: Int? = nil
    @State private var idx = 0

    static let frameCount = 6
    static let frameStep: UInt64 = 33_000_000   // 33ms/프레임 ≈ 0.2초
    static let maskUntil = 1                     // 0~1프레임만 마스킹(약 0.1초), 이후 공은 안 자름
    static let sizeScale = 0.60                  // 구김 전체 크기 비율

    private static let images: [UIImage] = (0..<frameCount).compactMap {
        UIImage(named: String(format: "crumple_%02d", $0))
    }
    static let aspect: Double = {
        guard let f = images.first, f.size.height > 0 else { return 1.4 }
        return f.size.width / f.size.height
    }()

    var body: some View {
        let i = min(debugFrame ?? idx, Self.images.count - 1)
        let masked = i <= Self.maskUntil
        Group {
            if i >= 0, i < Self.images.count {
                Image(uiImage: Self.images[i])
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(Self.aspect, contentMode: .fit)
                    .frame(width: noteSize.width * Self.sizeScale,
                           height: noteSize.width * Self.sizeScale / Self.aspect)
                    .colorMultiply(tint)
            }
        }
        .frame(width: noteSize.width, height: noteSize.height, alignment: .center)
        .modifier(MaybeClip(active: masked))
        .task {
            guard debugFrame == nil else { return }
            for f in 0..<Self.frameCount {
                idx = f
                try? await Task.sleep(nanoseconds: Self.frameStep)
            }
        }
    }
}

/// active일 때만 메모 사각형으로 클립.
struct MaybeClip: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active {
            content.clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            content
        }
    }
}
