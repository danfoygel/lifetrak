//
//  ContentView.swift
//  lifetrak
//
//  Created by Dan Foygel on 2/28/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("Hello, Dird!")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Parsley is a nice chimalin skimanimkinmalin")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
