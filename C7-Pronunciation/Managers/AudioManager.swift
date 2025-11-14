//
//  AudioManager.swift
//  C7-Pronunciation
//
//  Created by Savio Enoson on 14/11/25.
//


import Foundation
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    
    // 1. The Singleton Instance
    static let shared = AudioManager()
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0 // Optional: For visualizers
    
    var audioURL: URL?
    private var audioRecorder: AVAudioRecorder?
    private let audioSession = AVAudioSession.sharedInstance()
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func startRecording() {
        let fileName = "recording.m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.audioURL = documentsPath.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioSession.requestRecordPermission { [weak self] allowed in
                guard let self = self, allowed else { return }
                
                DispatchQueue.main.async {
                    do {
                        self.audioRecorder = try AVAudioRecorder(url: self.audioURL!, settings: settings)
                        self.audioRecorder?.delegate = self
                        self.audioRecorder?.record()
                        self.isRecording = true
                    } catch {
                        print("Could not start recording: \(error)")
                    }
                }
            }
        } catch {
            print("Error setting up recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
    }
    
    // Delegate method to ensure file is ready
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed.")
        }
    }
}