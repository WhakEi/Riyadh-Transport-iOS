//
//  LinesView.swift
//  Riyadh Transport
//
//  Lines browsing view
//

import SwiftUI

struct LinesView: View {
    @EnvironmentObject var lineLoader: LineStationLoader
    @State private var selectedSegment = 0 // 0: All, 1: Metro, 2: Bus
    
    private var displayedLines: [Line] {
        switch selectedSegment {
        case 0: return lineLoader.lines
        case 1: return lineLoader.lines.filter { $0.isMetro }
        case 2: return lineLoader.lines.filter { $0.isBus }
        default: return []
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Line Type", selection: $selectedSegment) {
                Text(localizedString("all")).tag(0)
                Text(localizedString("metro")).tag(1)
                Text(localizedString("bus")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if lineLoader.isLoadingList {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(displayedLines) { line in
                    if #available(iOS 16.0, *) {
                        NavigationLink(value: line) {
                            LineRow(line: line)
                        }
                    } else {
                        NavigationLink(destination: LineDetailView(line: line)) {
                            LineRow(line: line)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listStyle(.plain)
            }
        }
        .onAppear {
            lineLoader.loadLineList()
        }
    }
}

struct LineRow: View {
    let line: Line
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                .frame(width: 8)
            
            Circle()
                .fill(line.isMetro ? .blue : .green)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: line.isMetro ? "tram.fill" : "bus.fill").foregroundColor(.white).font(.system(size: 20)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(line.isBus ? String(format: localizedString("bus_line_title"), line.name ?? line.id) : line.name ?? line.id)
                    .font(.headline)
                
                if let summary = line.routeSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Show a placeholder while stations are loading in the background.
                    Text(localizedString(line.type ?? "line"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview { NavigationView { LinesView() } }
