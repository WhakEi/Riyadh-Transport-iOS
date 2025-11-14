//
//  LineAlertView.swift
//  Riyadh Transport
//
//  View component for displaying line alerts
//

import SwiftUI

struct LineAlertView: View {
    let alert: LineAlert
    @State private var isExpanded: Bool
    
    init(alert: LineAlert) {
        self.alert = alert
        // Line-specific alerts are expanded by default, general alerts are collapsed
        self._isExpanded = State(initialValue: alert.shouldExpandByDefault)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Always visible
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(alignment: .top, spacing: 12) {
                    // Alert icon
                    Image(systemName: alert.isGeneralAlert ? "info.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(alert.isGeneralAlert ? .blue : .orange)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Title
                        Text(alert.displayTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        // Show preview of message when collapsed
                        if !isExpanded {
                            Text(alert.message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    Spacer()
                    
                    // Chevron indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    
                    // Full message
                    Text(alert.message)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    
                    // Created at timestamp
                    Text(formatDate(alert.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(alert.isGeneralAlert ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: isoString) else {
            return isoString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        
        // Use localized date formatter
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        displayFormatter.locale = Locale(identifier: selectedLanguage)
        
        return displayFormatter.string(from: date)
    }
}

struct LineAlertsListView: View {
    let alerts: [LineAlert]
    
    var body: some View {
        if !alerts.isEmpty {
            VStack(spacing: 12) {
                ForEach(alerts) { alert in
                    LineAlertView(alert: alert)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    VStack {
        LineAlertView(alert: LineAlert(
            id: "1",
            title: "[150] Detour from usual route in Courts Complex",
            message: "Bus line 150 will be taking a detour due to road maintenance. Expect delays of 10-15 minutes.",
            createdAt: "2024-01-15T10:30:00.000Z"
        ))
        
        LineAlertView(alert: LineAlert(
            id: "2",
            title: "App Server is scheduled for maintenance 4-5 AM",
            message: "The app server will be undergoing scheduled maintenance tonight from 4 AM to 5 AM. Services may be temporarily unavailable during this time.",
            createdAt: "2024-01-15T08:00:00.000Z"
        ))
    }
    .padding()
}
