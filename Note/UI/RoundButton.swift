    //
    //  RoundButton.swift
    //  test3
    //
    //  Created by oniangel on 4/13/23.
    //  Copyright © 2023 lingzhou125@gmail.com. All rights reserved.
    //

    import SwiftUI



    struct RoundedButton: View {
        @Binding var scanResult: String
        @Binding var isButtonEnabled: Bool
        
        
        var body: some View {
            Button(action: {
                presentScanner()
            }, label: {
                Image(systemName: "qrcode.viewfinder")
                    .foregroundColor(.black)
                    .padding(15)
                    .background(.white)
                    .clipShape(Circle())
            })
            .padding()
            .disabled(!isButtonEnabled)
            .opacity(isButtonEnabled ? 1.0 : 0.5) // apply opacity to button
            .onAppear {
                isButtonEnabled = false
            }
        }
        
        private func presentScanner() {
            var scannerView = QRScanner(result: $scanResult)
            let scannerVC = UIHostingController(rootView: scannerView)
            
                // Set the onQRCodeDetected callback in the QRScanner instance
            scannerView.onQRCodeDetected = { [weak scannerVC] in
                scannerVC?.dismiss(animated: true, completion: nil)
                
            }
            
            UIApplication.shared.windows.first?.rootViewController?.present(scannerVC, animated: true, completion: nil)
        }
        
        
    }
