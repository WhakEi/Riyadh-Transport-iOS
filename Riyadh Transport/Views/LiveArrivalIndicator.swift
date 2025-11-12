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
                Image(animationImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundColor(colorForMinutes(minutes))
                    .rotation3DEffect(.degrees(isRTL ? 180 : 0), axis: (x: 0.0, y: 1.0, z: 0.0))
            } else if status == "normal" {
                Image(systemName: "clock").foregroundColor(.primary).font(.system(size: 14))
            } else if status == "checking" {
                ProgressView().scaleEffect(0.8)
            }

            VStack(alignment: .leading, spacing: 2) {
                if status != "checking" {
                    Text(timeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(colorForMinutes(minutes))
                    upcomingArrivalsView
                } else {
                    Text(localizedString("checking_arrivals")).font(.caption).foregroundColor(.secondary)
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
        if minutes == 0 { return localizedString("arriving_now") }
        else if minutes < 59 { return String(format: localizedString("minutes_short"), minutes) }
        else { return formattedTime(from: minutes) }
    }

    @ViewBuilder
    private var upcomingArrivalsView: some View {
        if let upcoming = upcomingArrivals, !upcoming.isEmpty {
            // FIX: Use modern Text interpolation instead of '+'
            HStack(spacing: 4) {
                ForEach(upcoming.indices, id: \.self) { index in
                    let minutes = upcoming[index]
                    if minutes < 59 {
                        Text(String(format: localizedString("minutes_short"), minutes))
                            .foregroundColor(colorForMinutes(minutes))
                    } else {
                        Text(formattedTime(from: minutes))
                            .foregroundColor(.primary)
                    }
                    if index < upcoming.count - 1 {
                        Text(",").foregroundColor(.secondary)
                    }
                }
            }
            .font(.caption2)
        }
    }
    
    private func formattedTime(from minutes: Int) -> String {
        let futureTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let formatter = DateFormatter(); formatter.timeStyle = .short
        return formatter.string(from: futureTime)
    }
    
    private func colorForMinutes(_ minutes: Int) -> Color {
        guard status == "live" else { return .primary }
        return .green
    }

    private func startAnimation() {
        guard timer == nil, status == "live" else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) { animationPhase += 1 }
        }
    }
    
    private func stopAnimation() { timer?.invalidate(); timer = nil }
}

#Preview {
    VStack(spacing: 20) {
        LiveArrivalIndicator(minutes: 1, status: "live", upcomingArrivals: [5, 10, 70])
        LiveArrivalIndicator(minutes: 15, status: "live", upcomingArrivals: [25, 35, 45])
        LiveArrivalIndicator(minutes: 70, status: "normal", upcomingArrivals: [90, 150])
    }
    .padding()
}
