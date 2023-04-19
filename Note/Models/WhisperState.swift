import Foundation
import SwiftUI
import AVFoundation

@MainActor
class WhisperState: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isModelLoaded = false
    @Published var messageLog = ""
    @Published var canTranscribe = false
    @Published var isRecording = false
    
    private var whisperContext: WhisperContext?
    private let recorder = Recorder()
    private var recordedFile: URL? = nil
    private var audioPlayer: AVAudioPlayer?
    
   
    
    private var modelUrl: URL? {
        //Bundle.main.url(forResource: "ggml-tiny.en", withExtension: "bin", subdirectory: "models")
        //Bundle.main.url(forResource: "ggml-small.en", withExtension: "bin", subdirectory: "models")
        Bundle.main.url(forResource: "ggml-base", withExtension: "bin", subdirectory: "models")
    }
    
    private var sampleUrl: URL? {
        Bundle.main.url(forResource: "jfk", withExtension: "wav", subdirectory: "samples")
    }
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    override init() {
        super.init()
        do {
            try loadModel()
            canTranscribe = true
        } catch {
            print(error.localizedDescription)
            messageLog += "\(error.localizedDescription)\n"
        }
    }
    
    private func loadModel() throws {
        messageLog += "Loading model...\n"
        if let modelUrl {
            do {
                let encodedPath = modelUrl.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modelUrl.path
                whisperContext = try WhisperContext.createContext(path: encodedPath)
            } catch {
                print("Error creating WhisperContext:", error.localizedDescription)
            }
            messageLog += "Loaded model \(modelUrl.lastPathComponent)\n"
        } else {
            messageLog += "Could not locate model\n"
        }
    }
    
  
    
    func transcribeFile(url: URL) async {
           if (!canTranscribe) {
               return
           }
           
           guard let whisperContext = whisperContext else {
               return
           }
           
           do {
               canTranscribe = false
               messageLog += "Reading wave samples...\n"
               let data = try readAudioSamples(url)
               messageLog += "Transcribing data...\n"
               await whisperContext.fullTranscribe(samples: data)
               let text = await whisperContext.getTranscription()
               
               messageLog += "Done: \(text)\n"
               
           } catch {
               print(error.localizedDescription)
               messageLog += "\(error.localizedDescription)\n"
           }
           try? FileManager.default.removeItem(at: url)
           canTranscribe = true
       }
    
    func transcribeAudio(url: URL, completion: @escaping (String) -> Void) async {
            if (!canTranscribe) {
                return
            }
            
            guard let whisperContext = whisperContext else {
                return
            }
            
            do {
                canTranscribe = false
                messageLog += "Reading wave samples...\n"
                let data = try readAudioSamples(url)
                print("got here \(url)")
                let audioFileURL = url
                    do {
                        let audioFileAttributes = try FileManager.default.attributesOfItem(atPath: audioFileURL.path)
                        if let fileSize = audioFileAttributes[.size] as? UInt64 {
                            print("File size: \(fileSize) bytes")
                        }
                    } catch {
                        print("Error retrieving file attributes: \(error)")
                    }
                messageLog += "Transcribing data...\n"
                await whisperContext.fullTranscribe(samples: data)
                let text = await whisperContext.getTranscription()
                messageLog += "Done: \(text)\n"
                
                completion(text)
            } catch {
                print(error.localizedDescription)
                messageLog += "\(error.localizedDescription)\n"
            }
            
            canTranscribe = true
        }
    
    private func readAudioSamples(_ url: URL) throws -> [Float] {
        stopPlayback()
        try startPlayback(url)
        return try decodeWaveFile(url)
    }
    
   
    
    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
#if os(macOS)
        response(true)
#else
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            response(granted)
        }
#endif
    }
    
    private func startPlayback(_ url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // MARK: AVAudioRecorderDelegate
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            Task {
                await handleRecError(error)
            }
        }
    }
    
    private func handleRecError(_ error: Error) {
        print(error.localizedDescription)
        messageLog += "\(error.localizedDescription)\n"
        isRecording = false
    }
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task {
            await onDidFinishRecording()
        }
    }
    
    private func onDidFinishRecording() {
        isRecording = false
    }
}
