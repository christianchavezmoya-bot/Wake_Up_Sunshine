import Foundation
import AVFoundation
import UIKit
import MediaPlayer
import AudioToolbox

/// Manages ambient background audio to keep the app alive in the background
/// This ensures wake alarms can play at maximum volume even when the phone is locked
class AmbientAudioManager: ObservableObject {
    static let shared = AmbientAudioManager()
    
    @Published var isPlaying: Bool = false
    @Published var isAlarmActive: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private var alarmPlayer: AVAudioPlayer?
    private let ambientVolume: Float = 0.01 // Minimum volume to keep app alive
    private let alarmVolume: Float = 1.0 // Maximum volume for alarm
    private var volumeView: MPVolumeView?
    
    private let debugLogger = DebugLogger.shared
    
    private init() {}
    
    // MARK: - Ambient Audio Control
    
    /// Start playing ambient audio at minimum volume to keep app alive in background
    func startAmbientAudio() {
        guard !isPlaying else {
            debugLogger.log(eventType: "ambient_audio_already_playing", message: "Ambient audio already playing")
            return
        }
        
        // Configure audio session for background playback
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            debugLogger.log(eventType: "audio_session_configured", message: "Audio session configured for background playback")
        } catch {
            debugLogger.logError(error, context: "Failed to configure audio session for ambient audio")
            return
        }
        
        // Load ambient.mp3 from bundle
        guard let soundPath = Bundle.main.path(forResource: "ambient", ofType: "mp3") else {
            debugLogger.log(eventType: "ambient_audio_file_not_found", message: "ambient.mp3 not found in bundle")
            print("[AmbientAudioManager] ambient.mp3 not found in bundle")
            return
        }
        
        let soundUrl = URL(fileURLWithPath: soundPath)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundUrl)
            audioPlayer?.numberOfLoops = -1 // Loop infinitely
            audioPlayer?.volume = ambientVolume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            debugLogger.log(eventType: "ambient_audio_started", message: "Ambient audio started at minimum volume")
            print("[AmbientAudioManager] Ambient audio started at minimum volume")
        } catch {
            debugLogger.logError(error, context: "Failed to create ambient audio player")
            print("[AmbientAudioManager] Failed to create ambient audio player: \(error)")
        }
    }
    
    /// Stop ambient audio
    func stopAmbientAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        debugLogger.log(eventType: "ambient_audio_stopped", message: "Ambient audio stopped")
        print("[AmbientAudioManager] Ambient audio stopped")
    }
    
    /// Pause ambient audio (for when alarm plays)
    func pauseAmbientAudio() {
        audioPlayer?.pause()
        isPlaying = false
        debugLogger.log(eventType: "ambient_audio_paused", message: "Ambient audio paused for alarm")
        print("[AmbientAudioManager] Ambient audio paused")
    }
    
    /// Resume ambient audio (after alarm stops)
    func resumeAmbientAudio() {
        guard let player = audioPlayer else {
            // If no player exists, start fresh
            startAmbientAudio()
            return
        }
        
        player.play()
        isPlaying = true
        debugLogger.log(eventType: "ambient_audio_resumed", message: "Ambient audio resumed")
        print("[AmbientAudioManager] Ambient audio resumed")
    }
    
    // MARK: - Alarm Control
    
    /// Play wake alarm at maximum volume
    /// - Parameters:
    ///   - soundName: The name of the alarm sound file (without extension)
    ///   - fileExtension: The file extension (default: "caf")
    func playAlarm(soundName: String, fileExtension: String = "caf") {
        // Stop ambient audio while alarm plays
        pauseAmbientAudio()
        isAlarmActive = true
        
        // Configure audio session for alarm (maximum volume, overrides silent switch)
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: []  // No mixing - take full audio focus
            )
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Set system volume to maximum
            setSystemVolumeToMax()
            
            debugLogger.log(eventType: "alarm_audio_session_configured", message: "Audio session configured for alarm at max volume")
        } catch {
            debugLogger.logError(error, context: "Failed to configure audio session for alarm")
        }
        
        // Try to load alarm sound with the provided extension, fallback to mp3 for ringing_tone
        var soundPath = Bundle.main.path(forResource: soundName, ofType: fileExtension)
        
        // Special handling for ringing_tone - try mp3 if caf not found
        if soundPath == nil && soundName == "ringing_tone" {
            soundPath = Bundle.main.path(forResource: soundName, ofType: "mp3")
        }
        
        guard let validSoundPath = soundPath else {
            debugLogger.log(eventType: "alarm_sound_not_found", message: "Alarm sound \(soundName).\(fileExtension) not found")
            print("[AmbientAudioManager] Alarm sound \(soundName).\(fileExtension) not found, using system sound")
            playSystemAlarmSound()
            return
        }
        
        let soundUrl = URL(fileURLWithPath: validSoundPath)
        
        do {
            alarmPlayer = try AVAudioPlayer(contentsOf: soundUrl)
            alarmPlayer?.numberOfLoops = -1 // Loop until stopped
            alarmPlayer?.volume = alarmVolume
            alarmPlayer?.prepareToPlay()
            alarmPlayer?.play()
            
            debugLogger.log(eventType: "alarm_started", message: "Alarm \(soundName) started at max volume")
            print("[AmbientAudioManager] Alarm \(soundName) started at max volume")
            
            // Trigger haptic feedback
            triggerHapticAlarm()
        } catch {
            debugLogger.logError(error, context: "Failed to create alarm audio player")
            print("[AmbientAudioManager] Failed to create alarm audio player: \(error)")
            playSystemAlarmSound()
        }
    }
    
    /// Stop the alarm and resume ambient audio
    func stopAlarm() {
        alarmPlayer?.stop()
        alarmPlayer = nil
        isAlarmActive = false
        
        // Clean up volume view
        volumeView?.removeFromSuperview()
        volumeView = nil
        
        debugLogger.log(eventType: "alarm_stopped", message: "Alarm stopped")
        print("[AmbientAudioManager] Alarm stopped")
        
        // Restore audio session for ambient playback
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            debugLogger.logError(error, context: "Failed to restore audio session for ambient")
        }
        
        // Resume ambient audio
        resumeAmbientAudio()
    }
    
    /// Stop alarm only (without resuming ambient) - used when app goes to background after alarm
    func stopAlarmOnly() {
        alarmPlayer?.stop()
        alarmPlayer = nil
        isAlarmActive = false
        
        // Clean up volume view
        volumeView?.removeFromSuperview()
        volumeView = nil
        
        debugLogger.log(eventType: "alarm_stopped_only", message: "Alarm stopped without resuming ambient")
    }
    
    // MARK: - System Volume Control
    
    private func setSystemVolumeToMax() {
        // Use MPVolumeView to set system volume to maximum
        // This is necessary to ensure the alarm is heard at maximum volume
        DispatchQueue.main.async {
            // Create a hidden volume view
            self.volumeView = MPVolumeView(frame: CGRect.zero)
            self.volumeView?.alpha = 0.01
            
            // Add to key window so it can access the volume slider
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(self.volumeView!)
            }
            
            // Find and set the slider
            if let slider = self.volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    slider.value = 1.0
                    self.debugLogger.log(eventType: "system_volume_set_max", message: "System volume set to maximum")
                }
            }
        }
    }
    
    // MARK: - System Sound Fallback
    
    private func playSystemAlarmSound() {
        // Play system sound as fallback with vibration
        AudioServicesPlaySystemSound(SystemSoundID(1005))
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    private func triggerHapticAlarm() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}