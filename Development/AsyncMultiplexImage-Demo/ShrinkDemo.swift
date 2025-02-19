import AsyncMultiplexImage
//
//  ShrinkDemo.swift
//  AsyncMultiplexImage-Demo
//
//  Created by Muukii on 2025/02/19.
//
import SwiftUI

struct BookShrink: View, PreviewProvider {
  var body: some View {
    ContentView()
  }

  static var previews: some View {
    Self()
      .previewDisplayName(nil)
  }

  private struct ContentView: View {
    
    @State private var isPressing = false

    var body: some View {
      AsyncMultiplexImage(
        multiplexImage: .init(
          identifier: "https://images.unsplash.com/photo-1660668377331-da480e5339a0",
          urls: buildURLs("https://images.unsplash.com/photo-1660668377331-da480e5339a0")
        ),
        downloader: _SlowDownloader(pipeline: .shared),
        content: AsyncMultiplexImageBasicContent()
      )
      .scaleEffect(isPressing ? 0.5 : 1)
      .padding(20)
      ._onButtonGesture(
        pressing: { isPressing in 
          withAnimation(.spring) {
            self.isPressing = isPressing
          }
      }) { 
        
      }

    }
  }
}
