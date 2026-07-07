import UIKit
import AVFoundation

/// 구기기 손맛: 햅틱(medium) + 종이 소리.
enum Feedback {
    private static var player: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "crumple", withExtension: "wav") else { return nil }
        let p = try? AVAudioPlayer(contentsOf: url)
        p?.prepareToPlay()
        return p
    }()

    private static let haptic = UIImpactFeedbackGenerator(style: .medium)
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let rigidGen = UIImpactFeedbackGenerator(style: .rigid)

    /// 메모를 집어 들 때(꾹 누르기 성공) — 단단한 '톡'.
    static func lift() {
        rigidGen.prepare()
        rigidGen.impactOccurred()
    }

    /// 자리 옮김 / 물감 닿음 — 가벼운 '틱'.
    static func tick() {
        lightGen.impactOccurred()
    }

    static func crumple() {
        haptic.impactOccurred()
        guard let player else { return }
        // 다른 앱 소리와 섞이고, 무음 스위치는 존중(.ambient).
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player.currentTime = 0
        player.play()
    }
}
