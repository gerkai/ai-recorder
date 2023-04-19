//
//  audioRecorder.swift
//  test3
//
//  Created by Geng Szoa on 4/11/23.
//  Copyright © 2023 lingzhou125@gmail.com. All rights reserved.
//

import Foundation
import AVFoundation
import SwiftUI


class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder!
    @Published var isRecording = false
    var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    
    private var silenceDetectionTimer: Timer?
    private let silenceThreshold: Float = -45.0 // Adjust this value to adjust the sensitivity of the silence detection
    private let silenceDetectionInterval: TimeInterval = 0.1 // Adjust this value to change the frequency of silence checks
    
    // Add properties for dynamic silence detection
    private let silenceDetectionWindowSize: Int = 30
    private var powerHistory: [Float] = []
    private var rollingAverage: Float = 0.0
    
    //for adjust the gain
    private var peakPowerHistory: [Float] = []
    
    @State private var appStartTime: DispatchTime = DispatchTime.now()

    
    @Published var transcription = ""
    @Published var normalizedPower: CGFloat = 0.0
    @Published var currentSegmentIndex: Int = 0
    @Published var orderedTranscriptions: [Int: String] = [:]
    
   

    
    func elapsedMilliseconds() -> UInt64 {
        let currentTime = DispatchTime.now()
        let elapsedTime = currentTime.uptimeNanoseconds - appStartTime.uptimeNanoseconds
        return elapsedTime / 1_000_000
    }

    private let whisperQueue: WhisperQueue
    private let whisperState: WhisperState // Add whisperState variable

    init(whisperState: WhisperState) {
        self.whisperState = whisperState
        self.whisperQueue = WhisperQueue(whisperState: whisperState)
        super.init()
        cleanUpAudioFiles()
    }

    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    func startRecording() {
        
        print("Recording started at: \(elapsedMilliseconds())")
        setupAudioSession()
        
        
        //prevent screen from shutting off
        UIApplication.shared.isIdleTimerDisabled = true

        
        let uniqueFilename = UUID().uuidString + ".wav"
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let audioFilename = documentsPath.appendingPathComponent(uniqueFilename)
                print("Recording file URL: \(audioFilename)")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ] as [String : Any]

        do {
                    audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                    audioRecorder.delegate = self
                    audioRecorder.isMeteringEnabled = true // Enable metering to detect silence
                    audioRecorder.record()
                    isRecording = true

                    // Start silence detection timer
                    silenceDetectionTimer = Timer.scheduledTimer(withTimeInterval: silenceDetectionInterval, repeats: true) { _ in
                        self.checkForSilence()
                    }
                } catch {
                    print("Could not start recording")
                }
    }

    func stopRecording(shouldTranscribe: Bool = false) {
        //allow phone screen to shut off again
        UIApplication.shared.isIdleTimerDisabled = false

        
        
        print("Recording stopped at: \(elapsedMilliseconds())")
        audioRecorder.stop()
        isRecording = false

        // Stop the silence detection timer
        silenceDetectionTimer?.invalidate()
        silenceDetectionTimer = nil

        if shouldTranscribe {
            let audioFileURL = audioRecorder.url

            // Transcribe the last bit of audio
            print("Sending audio for transcription")
            transcribeAudioFile(url: audioFileURL)
        }
    }
    
    func pausePlaying() {
        audioPlayer?.pause()
        isRecording = false
    }
    
    func resumePlaying() {
        audioPlayer?.play()
        isRecording = true
    }
    
    func getCurrentTime() -> TimeInterval {
        return audioPlayer?.duration ?? 1;
    }

    
    
    func cleanUpAudioFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "wav" {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Error cleaning up audio files: \(error)")
        }
    }
    
    private func checkForSilence() {
            audioRecorder.updateMeters()
            let currentPower = audioRecorder.averagePower(forChannel: 0)
            let currentPeakPower = audioRecorder.peakPower(forChannel: 0)

            //for live meter
            let normalizedPower = ((currentPower + 160) / 160)
            self.normalizedPower = CGFloat(min(max(normalizedPower, 0), 1))

            // Update the rolling average and peak power history
           updateRollingAverage(currentPower, currentPeakPower: currentPeakPower)

            // Calculate dynamic threshold based on the rolling average
            let dynamicThreshold = rollingAverage - 8
        
         


        
            if currentPower < dynamicThreshold {
            // Detected silence
            let audioFileURL = audioRecorder.url
                
            // Calculate the recording duration
            let duration = audioRecorder.currentTime

            // Stop the current recording and start a new one
            stopRecording(shouldTranscribe: false)
                // Start a new recording
                startRecording()

            // Only send the audio file for transcription if t  he duration is longer than the threshold
                let durationThreshold: TimeInterval = 0.8 // Adjust the threshold value as needed
            if duration > durationThreshold {
                print("Sending audio for transcription")
                transcribeAudioFile(url: audioFileURL)
            } else {
                try? FileManager.default.removeItem(at: audioFileURL)
                print("Audio duration is too short for transcription")
            }
                //listFilesInDocumentDirectory()
            
        }
    }

    func listFilesInDocumentDirectory() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)

            for fileURL in fileURLs {
                print("File: \(fileURL.lastPathComponent)")
            }
        } catch {
            print("Error listing files in document directory: \(error)")
        }
    }

    
    private func updateRollingAverage(_ currentPower: Float, currentPeakPower: Float) {
        powerHistory.append(currentPower)
        peakPowerHistory.append(currentPeakPower)

        if powerHistory.count > silenceDetectionWindowSize {
            rollingAverage += (currentPower - powerHistory.removeFirst()) / Float(silenceDetectionWindowSize)
        } else {
            rollingAverage = (rollingAverage * Float(powerHistory.count - 1) + currentPower) / Float(powerHistory.count)
        }
    }
        

    private func transcribeAudioFile(url: URL) {
        whisperQueue.addTranscriptionRequest(url: url) { transcription in
            DispatchQueue.main.async {
                if !self.transcription.isEmpty {
                    self.transcription += "\n"
                }
                self.transcription += "\(duration / 60):\(duration % 60)$$$\(transcription)"
                print("Transcription: \(transcription)")
            }
        }
    }



  
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
         
        }
    }
}

extension AudioRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
