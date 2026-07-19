import AVFoundation
import AppKit

/// Procedural music + SFX. No external audio files required.
@MainActor
final class AudioManager {
    static let shared = AudioManager()

    var muted = false {
        didSet { applyMuteState() }
    }

    var musicEnabled = true {
        didSet { applyMuteState() }
    }

    var sfxEnabled = true

    var musicVolume: Float = 0.28 {
        didSet { musicMixer.outputVolume = muted || !musicEnabled ? 0 : musicVolume }
    }

    var sfxVolume: Float = 0.5 {
        didSet { sfxMixer.outputVolume = muted || !sfxEnabled ? 0 : sfxVolume }
    }

    enum MusicTrack: Equatable {
        case title, space, combat, docked, none
    }

    enum Sound {
        case laser, hit, hurt, pickup, explode, dock, undock, jump, mine, select, win
        case freelaneEnter, freelaneExit, stationTurret, tractor
    }

    private let engine = AVAudioEngine()
    private let musicMixer = AVAudioMixerNode()
    private let sfxMixer = AVAudioMixerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private let sfxPlayers: [AVAudioPlayerNode]
    private let format: AVAudioFormat
    private var nextSFX = 0
    private var sfxCache: [Sound: AVAudioPCMBuffer] = [:]
    private var musicCache: [MusicTrack: AVAudioPCMBuffer] = [:]
    private var currentTrack: MusicTrack = .none
    private var engineStarted = false

    private init() {
        let sampleRate = 44_100.0
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        sfxPlayers = (0..<8).map { _ in AVAudioPlayerNode() }

        engine.attach(musicMixer)
        engine.attach(sfxMixer)
        engine.attach(musicPlayer)
        for p in sfxPlayers { engine.attach(p) }

        let main = engine.mainMixerNode
        engine.connect(musicMixer, to: main, format: format)
        engine.connect(sfxMixer, to: main, format: format)
        engine.connect(musicPlayer, to: musicMixer, format: format)
        for p in sfxPlayers {
            engine.connect(p, to: sfxMixer, format: format)
        }

        musicMixer.outputVolume = musicVolume
        sfxMixer.outputVolume = sfxVolume
        main.outputVolume = 1

        preloadSFX()
        startEngine()
    }

    private func startEngine() {
        guard !engineStarted else { return }
        do {
            try engine.start()
            engineStarted = true
        } catch {}
    }

    private func applyMuteState() {
        musicMixer.outputVolume = (muted || !musicEnabled) ? 0 : musicVolume
        sfxMixer.outputVolume = (muted || !sfxEnabled) ? 0 : sfxVolume
        if !(muted || !musicEnabled), currentTrack != .none, !musicPlayer.isPlaying {
            resumeMusic()
        }
    }

    func syncMusic(phase: GamePhase, system: String, inCombat: Bool, docked: Bool) {
        let track: MusicTrack
        switch phase {
        case .title, .howToPlay, .settings, .galaxyMap, .systemMap, .photo, .saveSlots, .loadSlots, .logbook:
            track = .title
        case .docked:
            track = .docked
        case .dead:
            track = .none
        case .playing, .paused:
            track = inCombat ? .combat : .space
        }
        playMusic(track)
        _ = system
        _ = docked
    }

    func playMusic(_ track: MusicTrack) {
        guard track != currentTrack else { return }
        musicPlayer.stop()
        currentTrack = track
        guard track != .none else { return }
        startEngine()
        let buffer = musicBuffer(for: track)
        musicPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
        if !muted && musicEnabled {
            musicPlayer.play()
        }
    }

    private func resumeMusic() {
        guard currentTrack != .none else { return }
        if !musicPlayer.isPlaying {
            let buffer = musicBuffer(for: currentTrack)
            musicPlayer.scheduleBuffer(buffer, at: nil, options: .loops)
            musicPlayer.play()
        }
    }

    func play(_ sound: Sound) {
        guard sfxEnabled, !muted else { return }
        startEngine()
        guard let buffer = sfxCache[sound] else { return }
        let player = sfxPlayers[nextSFX % sfxPlayers.count]
        nextSFX += 1
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    // MARK: - Synthesis

    private func preloadSFX() {
        sfxCache[.laser] = toneBurst(freqs: [880, 1200], duration: 0.08, volume: 0.25, noise: 0.3)
        sfxCache[.hit] = noiseBurst(duration: 0.06, volume: 0.3, filter: 0.5)
        sfxCache[.hurt] = toneBurst(freqs: [220, 180, 140], duration: 0.18, volume: 0.35, noise: 0.2)
        sfxCache[.pickup] = toneBurst(freqs: [523, 659, 784], duration: 0.15, volume: 0.3, noise: 0.1)
        sfxCache[.explode] = noiseBurst(duration: 0.4, volume: 0.4, filter: 0.2)
        sfxCache[.dock] = toneBurst(freqs: [330, 440, 550], duration: 0.25, volume: 0.28, noise: 0.1)
        sfxCache[.undock] = toneBurst(freqs: [550, 440, 330], duration: 0.2, volume: 0.28, noise: 0.1)
        sfxCache[.jump] = toneBurst(freqs: [200, 400, 800, 1200], duration: 0.45, volume: 0.32, noise: 0.15)
        sfxCache[.mine] = noiseBurst(duration: 0.1, volume: 0.22, filter: 0.35)
        sfxCache[.select] = toneBurst(freqs: [660], duration: 0.05, volume: 0.2, noise: 0)
        sfxCache[.win] = toneBurst(freqs: [523, 659, 784, 1046], duration: 0.35, volume: 0.32, noise: 0.05)
        // Freelane lock — rising whoosh / power-on
        sfxCache[.freelaneEnter] = toneBurst(freqs: [180, 320, 540, 880, 1200], duration: 0.42, volume: 0.34, noise: 0.12)
        // Freelane drop — descending cutoff
        sfxCache[.freelaneExit] = toneBurst(freqs: [900, 500, 280, 140], duration: 0.28, volume: 0.32, noise: 0.18)
        // Station turret — heavy twin-cannon bark
        sfxCache[.stationTurret] = toneBurst(freqs: [240, 180, 520, 400], duration: 0.14, volume: 0.38, noise: 0.25)
        // Tractor lock — soft magnetic latch
        sfxCache[.tractor] = toneBurst(freqs: [440, 554, 659, 880], duration: 0.22, volume: 0.30, noise: 0.08)
    }

    private func musicBuffer(for track: MusicTrack) -> AVAudioPCMBuffer {
        if let cached = musicCache[track] { return cached }
        let buffer: AVAudioPCMBuffer
        switch track {
        case .title:
            buffer = makeMusic(bpm: 72, bars: 4, root: 48, mode: .minor, density: 0.4, bass: true)
        case .space:
            buffer = makeMusic(bpm: 90, bars: 4, root: 45, mode: .minor, density: 0.35, bass: true)
        case .combat:
            buffer = makeMusic(bpm: 130, bars: 4, root: 43, mode: .phrygian, density: 0.7, bass: true)
        case .docked:
            buffer = makeMusic(bpm: 80, bars: 4, root: 50, mode: .major, density: 0.3, bass: false)
        case .none:
            buffer = silentBuffer(duration: 0.5)
        }
        musicCache[track] = buffer
        return buffer
    }

    private enum ScaleMode { case major, minor, phrygian }

    private func scaleNotes(root: Int, mode: ScaleMode) -> [Int] {
        switch mode {
        case .major: return [0, 2, 4, 5, 7, 9, 11].map { root + $0 }
        case .minor: return [0, 2, 3, 5, 7, 8, 10].map { root + $0 }
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10].map { root + $0 }
        }
    }

    private func makeMusic(bpm: Double, bars: Int, root: Int, mode: ScaleMode, density: Float, bass: Bool) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let beat = 60.0 / bpm
        let totalBeats = Double(bars * 4)
        let duration = totalBeats * beat
        let frameCount = AVAudioFrameCount(duration * sr)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return buffer }

        let frames = Int(frameCount)
        for i in 0..<frames { data[i] = 0 }

        let notes = scaleNotes(root: root, mode: mode)
        let steps = bars * 16 // 16th notes
        let stepDur = beat / 4.0

        var rng = SeededRNG(seed: root * 1000 + Int(bpm))

        for step in 0..<steps {
            let t0 = Double(step) * stepDur
            // Kick on quarters
            if step % 4 == 0, bass {
                addTone(data: data, frames: frames, sr: sr, start: t0, dur: 0.12, freq: 55, vol: 0.22, noise: 0.05)
            }
            // Hat
            if step % 2 == 1 {
                addNoise(data: data, frames: frames, sr: sr, start: t0, dur: 0.03, vol: 0.06)
            }
            // Melody
            if rng.nextFloat(0...1) < density {
                let n = notes[Int(rng.next() % UInt64(notes.count))]
                let oct = (step % 8 < 4) ? 0 : 12
                let freq = midiToFreq(n + oct)
                let vol: Float = 0.08 + rng.nextFloat(0...0.06)
                addTone(data: data, frames: frames, sr: sr, start: t0, dur: stepDur * 1.5, freq: freq, vol: vol, noise: 0.02)
            }
            // Pad chord on bar starts
            if step % 16 == 0 {
                for off in [0, 3, 7] {
                    let freq = midiToFreq(root + off)
                    addTone(data: data, frames: frames, sr: sr, start: t0, dur: beat * 3.5, freq: freq, vol: 0.04, noise: 0.01)
                }
            }
        }

        // Soft limiter
        for i in 0..<Int(frameCount) {
            data[i] = max(-0.9, min(0.9, data[i]))
        }
        return buffer
    }

    private func toneBurst(freqs: [Double], duration: Double, volume: Float, noise: Float) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sr)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return buffer }
        for i in 0..<Int(frameCount) { data[i] = 0 }
        let frames = Int(frameCount)
        let slice = duration / Double(max(1, freqs.count))
        for (i, f) in freqs.enumerated() {
            addTone(data: data, frames: frames, sr: sr, start: Double(i) * slice * 0.7, dur: slice * 1.2, freq: f, vol: volume, noise: noise)
        }
        return buffer
    }

    private func noiseBurst(duration: Double, volume: Float, filter: Float) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sr)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return buffer }
        var rng = SeededRNG(seed: Int(duration * 1000))
        var low: Float = 0
        for i in 0..<Int(frameCount) {
            let env = 1 - Float(i) / Float(frameCount)
            let n = rng.nextFloat(-1...1)
            low = low * filter + n * (1 - filter)
            data[i] = low * volume * env * env
        }
        return buffer
    }

    private func silentBuffer(duration: Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        return buffer
    }

    private func addTone(data: UnsafeMutablePointer<Float>, frames: Int, sr: Double, start: Double, dur: Double, freq: Double, vol: Float, noise: Float) {
        let startF = max(0, Int(start * sr))
        let n = Int(dur * sr)
        var rng = SeededRNG(seed: Int(freq * 10 + start * 100))
        for i in 0..<n {
            let idx = startF + i
            guard idx < frames else { break }
            let t = Double(i) / sr
            let env = Float(sin(min(1, t / 0.01) * .pi / 2)) * Float(exp(-t * 3.5 / max(0.05, dur)))
            let sample = Float(sin(2 * .pi * freq * t)) * vol * env
            let nse = noise > 0 ? rng.nextFloat(-1...1) * noise * env * vol : 0
            data[idx] += sample + nse
        }
    }

    private func addNoise(data: UnsafeMutablePointer<Float>, frames: Int, sr: Double, start: Double, dur: Double, vol: Float) {
        let startF = max(0, Int(start * sr))
        let n = Int(dur * sr)
        var rng = SeededRNG(seed: startF)
        for i in 0..<n {
            let idx = startF + i
            guard idx < frames else { break }
            let env = 1 - Float(i) / Float(max(1, n))
            data[idx] += rng.nextFloat(-1...1) * vol * env
        }
    }

    private func midiToFreq(_ midi: Int) -> Double {
        440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
    }
}
