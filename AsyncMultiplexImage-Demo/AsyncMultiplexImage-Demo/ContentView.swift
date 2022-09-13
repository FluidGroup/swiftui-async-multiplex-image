//
//  ContentView.swift
//  AsyncMultiplexImage-Demo
//
//  Created by Muukii on 2022/09/13.
//

import SwiftUI

import AsyncMultiplexImage
import AsyncMultiplexImage_Nuke
import SwiftUI
import Nuke

struct _SlowDownloader: AsyncMultiplexImageDownloader {
  
  let pipeline: ImagePipeline
  
  init(pipeline: ImagePipeline) {
    self.pipeline = pipeline
  }
  
  func download(candidate: AsyncMultiplexImageCandidate) async throws -> Image {
    
    switch candidate.index {
    case 0:
      try? await Task.sleep(nanoseconds: 2_000_000_000)
    case 1:
      try? await Task.sleep(nanoseconds: 1_500_000_000)
    case 2:
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    case 3:
      try? await Task.sleep(nanoseconds: 0_500_000_000)
    default:
      break
    }
    
    let response = try await pipeline.image(for: .init(urlRequest: candidate.urlRequest))
    return .init(uiImage: response.image)
  }
  
}

struct ContentView: View {
  var body: some View {
    VStack {
      AsyncMultiplexImage(
        urls: buildURLs(),
        downloader: _SlowDownloader(pipeline: .shared)
      ) { phase in
        switch phase {
        case .empty:
          Text("Loading")
        case .progress(let image):
          image
        case .success(let image):
          image
            .resizable()
            .scaledToFit()
        case .failure(let error):
          Text("Error")
        }
      }
    }
    .padding()
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

func buildURLs() -> [URL] {
  
  let baseURLString = "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8"
  
  var components = URLComponents(string: baseURLString)!
  
  return [
    "",
    "w=100",
    "w=50",
    "w=10",
  ].map {
    
    components.query = $0
    
    return components.url!
    
  }
  
}

struct AsyncMultiplexImage_Previews: PreviewProvider {
  static var previews: some View {
    AsyncMultiplexImage(
      urls: buildURLs(),
      downloader: _SlowDownloader(pipeline: .shared)
    ) { phase in
      switch phase {
      case .empty:
        Text("Loading")
      case .progress(let image):
        image
      case .success(let image):
        image
          .resizable()
          .scaledToFit()
      case .failure(let error):
        Text("Error")
      }
    }
  }
}
