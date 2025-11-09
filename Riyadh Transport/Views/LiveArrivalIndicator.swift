//
//  LiveArrivalIndicator.swift
//  Riyadh Transport
//
//  Animated indicator for live arrivals
//

import SwiftUI

/// Animated indicator showing live arrival times
struct LiveArrivalIndicator: View {
    let minutes: Int
    let status: String?
    @State private var animationPhase = 0
    
    private let isRTL = UserDefaults.standard.string(forKey: "selectedLanguage") == "ar"
    
    var body: some View {
        HStack(spacing: 4) {
            if status == "live" {
                // Animated arrival indicator
                Image(systemName: animationIconName)
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                    .onAppear {
                        startAnimation()
                    }
            } else if status == "normal" {
                // Clock icon for arrivals 59+ mins away
                Image(systemName: "clock")
                    .foregroundColor(.primary)
                    .font(.system(size: 14))
            } else if status == "checking" {
                // Loading indicator
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            if status != "checking" {
                Text(timeText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(status == "live" ? .green : .primary)
            } else {
                Text(localizedString("checking_arrivals"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var animationIconName: String {
        // Cycle through 3 phases
        let icons = isRTL ? ["arrow.left", "arrow.left.circle", "arrow.left.circle.fill"] :
                            ["arrow.right", "arrow.right.circle", "arrow.right.circle.fill"]
        return icons[animationPhase % 3]
    }
    
    private var timeText: String {
        if minutes == 0 {
            return localizedString("arriving_now")
        } else if minutes < 59 {
            return String(format: localizedString("minutes_short"), minutes)
        } else {
            // For 59+ minutes, show actual time
            let futureTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: futureTime)
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation {
                animationPhase += 1
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        LiveArrivalIndicator(minutes: 0, status: "live")
        LiveArrivalIndicator(minutes: 5, status: "live")
        LiveArrivalIndicator(minutes: 15, status: "live")
        LiveArrivalIndicator(minutes: 70, status: "normal")
        LiveArrivalIndicator(minutes: 0, status: "checking")
    }
    .padding()
}
