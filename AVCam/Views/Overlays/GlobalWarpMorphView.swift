//
//  GlobalWarpMorphView.swift
//  AVCam
//
//  Created by Moritz Denk on 06.06.25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct GlobeWarpMorphView: View {
    @Binding var show: Bool

    @State private var globeVisible = true
    @State private var checkVisible = false
    @State private var globeRotation: Angle = .zero
    @State private var globeScale: CGFloat = 1.0
    @State private var globeOpacity: Double = 1.0
    @State private var checkScale: CGFloat = 0.7
    @State private var checkOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0

    var body: some View {
        VStack {
            if show {
                ZStack {
                    // Background blur box
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .frame(width: 240, height: 220)
                        .shadow(radius: 8)

                    VStack(spacing: 12) {
                        // Shared fixed frame for animation slot
                        ZStack {
                            Image(systemName: "globe.europe.africa.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.blue)
                                .rotationEffect(globeRotation)
                                .scaleEffect(globeScale)
                                .opacity(globeOpacity)
                                .zIndex(1)

                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.green)
                                .scaleEffect(checkScale)
                                .opacity(checkOpacity)
                                .zIndex(2)
                        }
                        .frame(height: 64) // Fixed vertical slot for animation

                        // Text also inside a fixed frame to avoid vertical shift
                        Text("Successfully Geo-Signed")
                            .font(.headline)
                            .foregroundColor(.green)
                            .opacity(textOpacity)
                            .frame(height: 24) // Keeps text space fixed even when invisible
                    }
                    .onAppear {
                        startWarpSpin()
                    }
                }
            }
        }
    }

    private func startWarpSpin() {
        // Step 1: Bounce in
        withAnimation(.easeOut(duration: 0.3)) {
            globeScale = 1.1
        }

        // Step 2: Start spin and fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.linear(duration: 0.6)) {
                globeRotation = .degrees(720)
                globeScale = 0.3
                globeOpacity = 0.0
            }

            // Step 3: Checkmark appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                checkVisible = true
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    checkScale = 1.0
                    checkOpacity = 1.0
                }

                // Fade in text
                withAnimation(.easeIn(duration: 0.4).delay(0.1)) {
                    textOpacity = 1.0
                }
            }

            // Step 4: Remove globe
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                globeVisible = false
            }

            // Step 5: Auto-dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    checkOpacity = 0.0
                    textOpacity = 0.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    reset()
                }
            }
        }
    }

    private func reset() {
        show = false
        globeVisible = true
        checkVisible = false
        globeRotation = .zero
        globeScale = 1.0
        globeOpacity = 1.0
        checkScale = 0.7
        checkOpacity = 0.0
        textOpacity = 0.0
    }
}

struct GlobeWarpMorphView_PreviewWrapper: View {
    @State private var show = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if show {
                GlobeWarpMorphView(show: $show)
            }

            VStack {
                Spacer()
                Button("Replay Animation") {
                    show = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        show = true
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .padding()
            }
        }
    }
}

struct GlobeWarpMorphView_Previews: PreviewProvider {
    static var previews: some View {
        GlobeWarpMorphView_PreviewWrapper()
    }
}
