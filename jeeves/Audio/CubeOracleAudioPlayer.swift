import Foundation
import AVFoundation

@MainActor
final class CubeOracleAudioPlayer {
    private var player: AVAudioPlayer?

    func playSound(profile: SoundProfile, soundId: String) {
        guard let url = resolveURL(soundId: soundId) else {
            return
        }

        do {
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.enableRate = true
            audio.volume = Float(max(0, min(1, profile.volume)))
            let pitch = max(-1200, min(1200, profile.pitchShift))
            let rate = max(0.5, min(2.0, pow(2.0, pitch / 1200.0)))
            audio.rate = Float(rate)
            audio.prepareToPlay()
            audio.play()
            player = audio
        } catch {
            player = nil
        }
    }

    private func resolveURL(soundId: String) -> URL? {
        let clean = soundId.replacingOccurrences(of: ":", with: "_")
        let number = soundId.split(separator: ":").last.map(String.init) ?? "000"
        let padded = String(format: "%03d", Int(number) ?? 0)
        let candidates = [clean, "SND_\(padded)", soundId]
        let exts = ["wav", "mp3", "m4a", "aiff"]

        for name in candidates {
            for ext in exts {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }
        return nil
    }
}
