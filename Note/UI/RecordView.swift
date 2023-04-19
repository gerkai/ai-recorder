    //
    //  RecordView.swift
    //  test3
    //
    //  Created by oniangel on 4/12/23.
    //  Copyright © 2023 lingzhou125@gmail.com. All rights reserved.
    //

import SwiftUI




struct SoundMeterView: View {
    let width: CGFloat;
    let numberOfSegments: Int
    let currentValue: CGFloat
    
    let spacing = 10.0;
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<numberOfSegments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6)
                    .fill(self.segmentColor(for: index))
                    .frame(width: self.segmentWidth(), height: 20)
            }
        }
    }
    
    private func segmentWidth() -> CGFloat {
        let cellWidth = (width - CGFloat(numberOfSegments - 1) * spacing) / CGFloat(numberOfSegments);
        return cellWidth < 5.0 ? 5.0: cellWidth;
    }
    
    private func segmentColor(for index: Int) -> Color {
        let step = 0.4 / CGFloat(numberOfSegments)
        let threshold = pow(step * CGFloat(index + 1), 0.1)
        
        if currentValue >= threshold {
            return Color.green
        } else {
            return Color.gray
        }
    }
    
}

@available(iOS 16.0, *)
struct RecordView: View {
    let audioRecorder: AudioRecorder
    let isPause: Bool
    let isSized: Bool
    let onPause: () -> Void
    let onStop: () -> Void
    let onSized: () -> Void
    
    
    let size = UIScreen.main.bounds.size;
    
    init(audioRecorder: AudioRecorder, isPause: Bool, isSized: Bool, onPause: @escaping () -> Void, onStop: @escaping () -> Void, onSized: @escaping () -> Void) {
        self.audioRecorder = audioRecorder
        self.isPause =  isPause
        self.isSized = isSized
        self.onPause = onPause
        self.onStop = onStop
        self.onSized = onSized
    }
    
    func getCurrentDate() -> String {
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.dateFormat = "MMM,  MM/dd  ·  hh:mm"
        
        return formatter.string(from: currentDate)
    }
    
    var transactionView: some View {
        
        let transactions = audioRecorder.transcription.components(separatedBy: "\n");
        
        return VStack(alignment: .leading){
            ForEach(transactions.indices, id: \.self) { index in
                if (transactions[index].contains("$$$")) {
                    Text(transactions[index].split(separator: "$$$")[0])
                        .id(index)
                        .foregroundColor(.gray)
                        .font(.system(size: 13 ))
                        
                    Text(transactions[index].split(separator: "$$$")[1] )
                        .id(index)
                        .foregroundColor(.white)
                        .font(.system(size: 15 ))
                        .padding(.bottom, 5)
                }
                else {
                    Text(transactions[index])
                        .id(index)
                        .foregroundColor(.white)
                        .font(.system(size: 15))
                        .padding(.bottom, 5)
                }
            }
        }
    }
    
    var body: some View {
        
        VStack {
            
            if (isSized) {
                Button(action: {
                    onSized()
                }) {
                    Image(systemName: "chevron.compact.up")
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                VStack {
                    
                    HStack {
                        Button(action: {
                            onPause()
                        }) {
                            Image(systemName: !isPause ? "pause" : "mic")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                        
                        Button(action: {
                            onStop()
                        }) {
                            Image(systemName:  "stop.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        SoundMeterView(width: 200,numberOfSegments: 15, currentValue: audioRecorder.normalizedPower)
                        
                        Text("\(duration / 60):\(duration % 60)")
                            .padding(.leading, 10)
                            .padding(.trailing, 20)
                            .foregroundColor(.white)
                    }
                    
                    
                }
                .frame(width: size.width - 30, height: 60)
                .background(Color(hex: 0x202025))
                .cornerRadius(8)
                .padding(.bottom, 50)
            }
            else{
                
                HStack {
                    Spacer()
                    Button(action: {
                    }) {
                        Image(systemName:  "person.crop.circle.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                    }) {
                        Image(systemName:  "arrow.up.backward.and.arrow.down.forward")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(90))
                    }
                    .padding(.horizontal, 20)
                    
                    Button(action: {
                    }) {
                        Image(systemName:  "ellipsis")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 20)
                    
                }
                .frame(width: size.width, height: 80)
                .background(Color(hex: 0x202025))
                
                ScrollView {
                    ScrollViewReader { scrollViewProxy in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Note")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                
                                
                                Spacer()
                                
                                Button(action: {
                                }) {
                                    Image("diamond")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(6)
                                        .border(.gray, width: 1)
                                }
                            }
                            .padding(.bottom, 30)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                                
                                Text("\(getCurrentDate())")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 15, design: .rounded))
                                    .padding(.trailing, 20)
                                
                                Image(systemName: "person.text.rectangle")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                                
                                Text("User")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 15, design: .rounded))
                                
                            }
                            .padding(.bottom, 20)
                            
                            transactionView
                            
                        }
                        .onChange(of: audioRecorder.transcription) { _ in
                            DispatchQueue.main.async {
                                withAnimation {
                                    let lastIndex = audioRecorder.transcription.components(separatedBy: "\n").count - 1
                                    scrollViewProxy.scrollTo(lastIndex, anchor: .bottom)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .frame(width: size.width, height: size.height - 400)
                .padding(.vertical, 30)
                
                VStack {
                    
                    HStack {
                        
                        SoundMeterView(width: 200,numberOfSegments: 15, currentValue: audioRecorder.normalizedPower)
                        
                        Text("\(duration / 60):\(duration % 60)")
                            .padding(.leading, 10)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 20)
                    
                    HStack {
                        Button(action: {
                            onPause()
                        }) {
                            Image(systemName: !isPause ? "pause" : "mic")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                        
                        Button(action: {
                            onStop()
                        }) {
                            Image(systemName:  "stop.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                        }) {
                            Image(systemName:  "pencil.line")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                        }
                        
                        Button(action: {
                        }) {
                            Image(systemName:  "ellipsis.message")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 15)
                        
                        Button(action: {
                        }) {
                            Image(systemName:  "photo.artframe")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 20)
                        
                        
                    }
                }
                .frame(width: size.width - 30, height: 100)
                .background(Color(hex: 0x202025))
                .cornerRadius(8)
                .padding(.bottom, 50)
                
            }
            
            
            
            
        }
        .frame(width: size.width)
        .background(Color(hex: 0x1C1C1E))
        
        
    }
    
    
}
