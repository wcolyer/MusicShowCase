//
//  ContentView.swift
//  MusicShowCaseApp
//
//  Created by Wallace Colyer on 8/8/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: NowPlayingCoordinator
    @State private var tabSelection: Int = 0
    @State private var lastSetAttempt: (from: Int, to: Int, blocked: Bool)?
    var body: some View {
        TabView(selection: Binding(
            get: { tabSelection },
            set: { newValue in
                if let until = coordinator.lockSelectionUntil, Date() < until {
                    #if DEBUG
                    let t = String(format: "%.3f", Date.timeIntervalSinceReferenceDate)
                    print("[ContentView] \(t): attempt to set selection -> \(newValue) BLOCKED (until=\(until.timeIntervalSince1970))")
                    #endif
                    // Force UI back to coordinator's selection to avoid visual bounce
                    tabSelection = coordinator.selectedTab
                    lastSetAttempt = (from: coordinator.selectedTab, to: newValue, blocked: true)
                    return
                }
                #if DEBUG
                let t = String(format: "%.3f", Date.timeIntervalSinceReferenceDate)
                print("[ContentView] \(t): setting selection -> \(newValue)")
                #endif
                tabSelection = newValue
                (coordinator as NowPlayingCoordinator).setSelectionFromUI(newValue)
                lastSetAttempt = (from: coordinator.selectedTab, to: newValue, blocked: false)
            }
        )) {
            NowPlayingView()
                .tabItem { Label("Now Playing", systemImage: "play.circle") }
                .tag(0)
                .onAppear {
                    #if DEBUG
                    let t = String(format: "%.3f", Date.timeIntervalSinceReferenceDate)
                    print("[ContentView] \(t): NowPlaying tab onAppear, selection=\(coordinator.selectedTab)")
                    #endif
                }

            Group {
                if coordinator.selectedTab == 1 {
                    ListenNowView()
                } else {
                    NonFocusablePlaceholder()
                }
            }
                .tabItem { Label("Listen Now", systemImage: "music.note.house") }
                .tag(1)
                .onAppear {
                    #if DEBUG
                    let t = String(format: "%.3f", Date.timeIntervalSinceReferenceDate)
                    print("[ContentView] \(t): ListenNow tab onAppear, selection=\(coordinator.selectedTab)")
                    #endif
                }

            Group {
                if coordinator.selectedTab == 2 {
                    Text("Library")
                } else {
                    NonFocusablePlaceholder()
                }
            }
                .tabItem { Label("Library", systemImage: "square.stack.3d.up") }
                .tag(2)

            Group {
                if coordinator.selectedTab == 3 {
                    BrowseView()
                } else {
                    NonFocusablePlaceholder()
                }
            }
                .tabItem { Label("Browse", systemImage: "globe") }
                .tag(3)
                .onAppear {
                    #if DEBUG
                    let t = String(format: "%.3f", Date.timeIntervalSinceReferenceDate)
                    print("[ContentView] \(t): Browse tab onAppear, selection=\(coordinator.selectedTab)")
                    #endif
                }

            Group {
                if coordinator.selectedTab == 4 {
                    Text("Search")
                } else {
                    NonFocusablePlaceholder()
                }
            }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(4)

            Group {
                if coordinator.selectedTab == 5 {
                    Text("Settings")
                } else {
                    NonFocusablePlaceholder()
                }
            }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(5)
        }
        .onAppear {
            // Keep state in sync at launch
            tabSelection = coordinator.selectedTab
        }
        .onChange(of: coordinator.selectedTab) { _, newValue in
            // Push coordinator-driven changes into UI selection
            if tabSelection != newValue {
                #if DEBUG
                let t = String(format: "%.3f", Date.timeIntervalSinceReferenceDate)
                print("[ContentView] \(t): syncing tabSelection to coordinator -> \(newValue)")
                #endif
                tabSelection = newValue
            }
        }
    }
}

#Preview {
    ContentView()
}

private struct NonFocusablePlaceholder: View {
    var body: some View {
        Color.clear
            .focusable(false)
            .accessibilityHidden(true)
    }
}
