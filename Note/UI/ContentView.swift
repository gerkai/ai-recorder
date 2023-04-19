    //
    //  ContentView.swift
    //  test3
    //
    //  Created by Geng Szoa on 4/6/23.
    //

import SwiftUI
import AVFoundation


var duration: Int = 0

@available(iOS 16.0, *)
struct ContentView: View {
    @State private var fileURL: URL?
    @State private var model: String = "whisper-1"
    @State private var status: String = ""
    @State private var response: String = ""
    @State private var isButtonEnabled = true
    @State var scanResult = "No QR code detected"
    
    @State private var transcribeEnabled: Bool = true
    @StateObject private var audioRecorder = AudioRecorder(whisperState: .init())
    
    
    
    
    @State var isRecord = true
    @State var isPause = true
    @State var isSized = false
    
    
    @State private var sheetHeight: CGFloat  = 400
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    
    
    func onStartRecord() {
        isRecord.toggle()
        audioRecorder.startRecording()
        isPause = false
        
    }
    
    
    func onPauseRecord() {
        if(!audioRecorder.isRecording) {
            audioRecorder.startRecording()
            isPause = false
            
        }
        else {
            if (isPause) {
                isPause = false
                self.transcribeEnabled = false
                audioRecorder.pausePlaying()
            }
            else {
                isPause = true
                self.transcribeEnabled = true
                audioRecorder.resumePlaying()
            }
        }
        
    }
    
    func onStopRecord() {
        self.transcribeEnabled = false
        audioRecorder.startRecording()
        audioRecorder.transcription = ""
        duration = 0
        isSized = false
        isRecord = false;
    }
    
    func onSized() {
        isSized = false
    }
    
    var body: some View {
        
        
        VStack(alignment: .center) {
            
            Button("Generate Note") {
                self.transcribeEnabled = true
                print(audioRecorder.transcription)
                callOpenAI(prompt: audioRecorder.transcription)
            }
            .disabled(transcribeEnabled)
            .padding(.top, 100)
            .foregroundColor(.white)
            
            Button(action: onStartRecord) {
                Image(systemName: "mic.circle")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
            }
            .padding(.top, 100)
            .sheet(isPresented: $isRecord) {
                RecordView(
                    audioRecorder:audioRecorder, isPause: isPause, isSized: isSized, onPause: onPauseRecord, onStop: onStopRecord, onSized: onSized)
                .background(Color(hex: 0x1C1C1E))
                .presentationDetents(isSized ? [.height(150)] : [.large])
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            let yOffset = gesture.translation.height
                            sheetHeight = max(100, 400 - yOffset)
                        }
                        .onEnded { gesture in
                            if sheetHeight < 250 {
                                isSized.toggle()
                            } else {
                                isSized = false
                            }
                        }
                )
                .onReceive(timer) { _ in
                    if (isRecord && !isPause) {
                        duration += 1
                    }
                }
                
            }
            
            
            Text(status)
                .padding()
            ScrollView{Text(response)
                    .padding()
            }
            
            RoundedButton(scanResult: $scanResult, isButtonEnabled: $isButtonEnabled)
            
            Spacer()
            
            Text("Scan Result: \(scanResult)")
                .padding(.bottom, 10)
            
        }
        .onChange(of: scanResult) { newValue in
            if newValue != "No QR code detected" {
                sendPostRequest()
            }
        }
        .frame(width: UIScreen.main.bounds.size.width)
        
        
    }
    
    
    
    
    
    func sendPostRequest() {
        let urlString = "https://soaper.ai/qr.aspx"
        
        guard var urlComponents = URLComponents(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        let keyQueryItem = URLQueryItem(name: "key", value: scanResult)
        let responseQueryItem = URLQueryItem(name: "response", value: response)
        urlComponents.queryItems = [keyQueryItem, responseQueryItem]
        
        guard let url = urlComponents.url else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "key": scanResult,
            "response": response
        ]
        print(scanResult)
        print(response)
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            
        } catch let error {
            print(error.localizedDescription)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            
                //let responseString = String(data: data, encoding: .utf8)
                //DispatchQueue.main.async {
                //    self.response = responseString ?? ""
                //}
        }
        
        task.resume()
        print("Full POST request URL: \(urlComponents.string ?? "Invalid URL")")
    }
    
    
    private func callOpenAI(prompt: String) {
        print("calling chatgpt...")
        self.status = "Generating Note..."
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let apiKey = "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" // Replace this with your actual API key
        print ("request sent")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                
                ["role": "user", "content": "write the subjective portion of a soap note based on the following transcript: \(prompt). if information is not included in the transcript, explicitly state that it is not provided."]
            ],
            "max_tokens": 1500,
            "temperature": 0,
            "top_p": 1,
            "n": 1
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                print(data)
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    print(json)
                    
                    if let completions = json?["choices"] as? [[String: Any]] {
                        if let message = completions.first?["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            DispatchQueue.main.async {
                                self.response = content.trimmingCharacters(in: .whitespacesAndNewlines)
                                isButtonEnabled = true
                                self.status = ""
                            }
                        }
                    }
                }
                catch {
                    print("Error decoding JSON")
                    self.status = "Sorry, an error occured"
                }
            } else {
                print("Error: \(error?.localizedDescription ?? "Unknown error")")
                self.status = "Sorry, an error occured"
            }
        }.resume()
    }
    
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct TranscriptionResponse: Codable {
    let text: String
}


@available(iOS 16.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
