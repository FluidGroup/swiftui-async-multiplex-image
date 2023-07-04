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
    return .init(uiImage: response)
  }
  
}

struct RootView: View {

  var body: some View {
    NavigationView {

      Group {
        VStack {
          NavigationLink(destination: { ContentView() }, label: { Text("Image")})
          NavigationLink(destination: { ContentView2() }, label: { Text("UIImageView")})
        }
      }

    }
  }
}

struct ContentView: View {
  
  @State private var basePhotoURLString: String = "https://images.unsplash.com/photo-1492446845049-9c50cc313f00"
  
  var body: some View {
    VStack {
      AsyncMultiplexImage(
        multiplexImage: .init(identifier: basePhotoURLString, urls: buildURLs(basePhotoURLString)),
        downloader: _SlowDownloader(pipeline: .shared)
      ) { phase in
        switch phase {
        case .empty:
          Text("Loading")
        case .progress(let image):
          image
            .resizable()
            .scaledToFill()
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        case .failure(let error):
          Text("Error")
        }
      }
      
      HStack {
        Button("1") {
          basePhotoURLString = "https://images.unsplash.com/photo-1660668377331-da480e5339a0"
        }
        Button("2") {
          basePhotoURLString = "https://images.unsplash.com/photo-1658214764191-b002b517e9e5"
        }
        Button("3") {
          basePhotoURLString = "https://images.unsplash.com/photo-1587126396803-be14d33e49cf"
        }
      }
    }
    .padding()
  }
}

struct ContentView2: View {

  @State private var basePhotoURLString: String = "https://images.unsplash.com/photo-1492446845049-9c50cc313f00"

  var body: some View {
    VStack {
      AsyncMultiplexImage(
        multiplexImage: .init(identifier: basePhotoURLString, urls: buildURLs(basePhotoURLString)),
        downloader: AsyncMultiplexImageNukePlatformImageDownloader(pipeline: .shared, debugDelay: 0)
      ) { phase in
        switch phase {
        case .empty:
          Text("Loading")
        case .progress(let uiImage):
          ImageView(image: uiImage, contentMode: .scaleAspectFit, tintColor: nil)
        case .success(let uiImage):
          ImageView(image: uiImage, contentMode: .scaleAspectFit, tintColor: nil)
        case .failure(let error):
          Text("Error")
        }
      }

      HStack {
        Button("1") {
          basePhotoURLString = "https://images.unsplash.com/photo-1660668377331-da480e5339a0"
        }
        Button("2") {
          basePhotoURLString = "https://images.unsplash.com/photo-1658214764191-b002b517e9e5"
        }
        Button("3") {
          basePhotoURLString = "https://images.unsplash.com/photo-1587126396803-be14d33e49cf"
        }
      }
    }
    .padding()
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
    ContentView2()
  }
}

func buildURLs(_ baseURLString: String) -> [URL] {
    
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

#if canImport(UIKit)
import SwiftUI
import UIKit

/**
 UIImageView backed ImageView

 For supporting PDF rendering
 https://stackoverflow.com/questions/61164005/why-do-pdfs-resized-in-swiftui-getting-sharp-edges
 */
public struct ImageView: View {

  let contentMode: UIView.ContentMode
  let tintColor: UIColor?
  let image: UIImage?

  public init(
    image: UIImage?,
    contentMode: UIView.ContentMode = .scaleAspectFill,
    tintColor: UIColor? = nil
  ) {
    self.image = image
    self.contentMode = contentMode
    self.tintColor = tintColor
  }

  public var body: some View {
    _ImageView(image: image, contentMode: contentMode, tintColor: tintColor)
      .aspectRatio(image?.size ?? .zero, contentMode: .fit)
  }

  private struct _ImageView: UIViewRepresentable {

    let contentMode: UIView.ContentMode
    let tintColor: UIColor?
    let image: UIImage?

    init(
      image: UIImage?,
      contentMode: UIView.ContentMode = .scaleAspectFill,
      tintColor: UIColor? = nil
    ) {
      self.image = image
      self.contentMode = contentMode
      self.tintColor = tintColor
    }

    func makeUIView(context: Context) -> UIImageView {
      let imageView = UIImageView()
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
      imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      imageView.clipsToBounds = true
      return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
      uiView.isUserInteractionEnabled = false
      uiView.contentMode = contentMode
      uiView.tintColor = tintColor
      uiView.image = image
    }

  }
}

#if DEBUG

enum Preview_ImageView: PreviewProvider {

  static var previews: some View {

    Group {
      ImageView(image: nil)
    }

  }

}

#endif

#endif
