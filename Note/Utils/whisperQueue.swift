//
//  whisperQueue.swift
//  soaper.Note
//
//  Created by Geng Szoa on 4/15/23.
//

import Foundation


class WhisperQueue {
    private struct TranscriptionRequest {
        let url: URL
        let completion: (String) -> Void
    }

    private var queue: [TranscriptionRequest] = []
    private var processing = false
    private let whisperState: WhisperState

    init(whisperState: WhisperState) {
        self.whisperState = whisperState
    }

    func addTranscriptionRequest(url: URL, completion: @escaping (String) -> Void) {
        queue.append(TranscriptionRequest(url: url, completion: completion))
        processNextInQueue()
    }

    private func processNextInQueue() {
        guard !processing, !queue.isEmpty else {
            return
        }

        processing = true
        let request = queue.removeFirst()

        let url = request.url
        let completion = request.completion

        Task {
            await whisperState.transcribeAudio(url: url) { transcription in
                DispatchQueue.main.async {
                    completion(transcription.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                self.processing = false
                self.processNextInQueue()
            }
        }
    }

}

