//
//  ContentView.swift
//  MusicShowCaseApp
//
//  Created by Wallace Colyer on 8/8/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NowPlayingView()
                .tabItem { Label("Now Playing", systemImage: "play.circle") }

            Text("Listen Now")
                .tabItem { Label("Listen Now", systemImage: "music.note.house") }

            Text("Library")
                .tabItem { Label("Library", systemImage: "square.stack.3d.up") }

            Text("Browse")
                .tabItem { Label("Browse", systemImage: "globe") }

            Text("Search")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
}
