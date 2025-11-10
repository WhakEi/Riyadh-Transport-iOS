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
    let upcomingArrivals: [Int]?
    @State private var animationPhase = 0
    @State private var timer: Timer?

    private let isRTL = UserDefaults.standard.string(forKey: "selectedLanguage") == "ar"

    var body: some View {
        HStack(spacing: 4) {
            if status == "live" {
                // Animated arrival indicator using custom images
                Image(animationImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .rotation3DEffect(
                        .degrees(isRTL ? 180 : 0),
                        axis: (x: 0.0, y: 1.0, z: 0.0) // Flips horizontally for RTL
                    )
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

            VStack(alignment: .leading, spacing: 2) {
                if status != "checking" {
                    Text(timeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(status == "live" ? .green : .primary)

                    // Display the mixed-format upcoming arrivals text
                    upcomingArrivalsView
                    
                } else {
                    Text(localizedString("checking_arrivals"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear(perform: startAnimation)
        .onDisappear(perform: stopAnimation)
    }

    private var animationImageName: String {
        let imageNames = ["lt3", "lt2", "lt1"]
        return imageNames[animationPhase % imageNames.count]
    }

    private var timeText: String {
        if minutes == 0 {
            return localizedString("arriving_now")
        } else if minutes < 59 {
            return String(format: localizedString("minutes_short"), minutes)
        } else {
            // For 59+ minutes, show actual time
            return formattedTime(from: minutes)
        }
    }

    // New ViewBuilder for the upcoming arrivals subtitle
    @ViewBuilder
    private var upcomingArrivalsView: some View {
        if let upcoming = upcomingArrivals, !upcoming.isEmpty {
            // This builds a single Text view by combining multiple formatted Text components
            upcoming.reduce(Text("")) { (combined, minutes) -> Text in
                let part: Text
                
                if minutes < 59 {
                    part = Text(String(format: localizedString("minutes_short"), minutes))
                        .foregroundColor(.green)
                } else {
                    part = Text(formattedTime(from: minutes))
                        .foregroundColor(.primary)
                }
                
                // Add a comma separator if this is not the first element
                if combined == Text("") {
                    return part
                } else {
                    return combined + Text(", ").foregroundColor(.secondary) + part
                }
            }
            .font(.caption2)
        }
    }
    
    // Helper function to format minutes into a time string (e.g., "5:00 PM")
    private func formattedTime(from minutes: Int) -> String {
        let futureTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: futureTime)
    }

    private func startAnimation() {
        guard timer == nil, status == "live" else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                animationPhase += 1
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    VStack(spacing: 20) {
        LiveArrivalIndicator(minutes: 0, status: "live", upcomingArrivals: [10, 22])
        LiveArrivalIndicator(minutes: 5, status: "live", upcomingArrivals: [20, 70, 125]) // Mixed
        LiveArrivalIndicator(minutes: 15, status: "live", upcomingArrivals: [25, 35, 45])
        LiveArrivalIndicator(minutes: 70, status: "normal", upcomingArrivals: [90, 150]) // All times
        LiveArrivalIndicator(minutes: 0, status: "checking", upcomingArrivals: nil)
    }
    .padding()
}
