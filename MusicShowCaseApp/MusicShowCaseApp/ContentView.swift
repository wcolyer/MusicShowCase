//
//  ContentView.swift
//  MusicShowCaseApp
//
//  Created by Wallace Colyer on 8/8/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: NowPlayingCoordinator
    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            NowPlayingView()
                .tabItem { Label("Now Playing", systemImage: "play.circle") }
                .tag(0)

            ListenNowView()
                .tabItem { Label("Listen Now", systemImage: "music.note.house") }
                .tag(1)

            Text("Library")
                .tabItem { Label("Library", systemImage: "square.stack.3d.up") }
                .tag(2)

            BrowseView()
                .tabItem { Label("Browse", systemImage: "globe") }
                .tag(3)

            Text("Search")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(4)

            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(5)
        }
    }
}

#Preview {
    ContentView()
}
