//
//  ContentView.swift
//  AsyncMultiplexImage-Demo
//
//  Created by Muukii on 2022/09/13.
//

import AsyncMultiplexImage
import AsyncMultiplexImage_Nuke
import MondrianLayout
import Nuke
import SwiftUI
import SwiftUIHosting

actor _SlowDownloader: AsyncMultiplexImageDownloader {

  let pipeline: ImagePipeline

  init(pipeline: ImagePipeline) {
    self.pipeline = pipeline
  }

  func download(candidate: AsyncMultiplexImageCandidate, displaySize: CGSize) async throws
    -> UIImage
  {

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
    return response
  }

}

struct ContentView: View {

  var body: some View {
    NavigationView {
      Form {
        Section {
          NavigationLink("SwiftUI") {
            SwitchingDemo()
              .navigationTitle("SwiftUI")
          }
          NavigationLink("UIKit") {
            UIKitContentViewRepresentable()
          }
          
          NavigationLink("Stress 1", destination: { StressGrid<Cell_1>() })
          
          NavigationLink("Stress 2", destination: { StressGrid<Cell_2>() })
        }
        .navigationTitle("Multiplex Image")
      }
    }
  }
}

private struct SwitchingDemo: View {
  
  @State private var basePhotoURLString: String =
  "https://images.unsplash.com/photo-1492446845049-9c50cc313f00"

  var body: some View {
    VStack {
      AsyncMultiplexImage(
        multiplexImage: .init(
          identifier: basePhotoURLString,
          urls: buildURLs(basePhotoURLString)
        ),
        downloader: _SlowDownloader(pipeline: .shared),
        content: AsyncMultiplexImageBasicContent()
      )
      
      HStack {
        Button("1") {
          basePhotoURLString =
          "https://images.unsplash.com/photo-1660668377331-da480e5339a0"
        }
        Button("2") {
          basePhotoURLString =
          "https://images.unsplash.com/photo-1658214764191-b002b517e9e5"
        }
        Button("3") {
          basePhotoURLString =
          "https://images.unsplash.com/photo-1587126396803-be14d33e49cf"
        }
      }
    }
    .padding()
  }

}

struct UIKitContentViewRepresentable: UIViewRepresentable {

  func makeUIView(context: Context) -> UIKitContentView {
    .init()
  }

  func updateUIView(_ uiView: UIKitContentView, context: Context) {

  }

}

final class UIKitContentView: UIView {

  private let imageView: AsyncMultiplexImageView = .init(
    downloader: _SlowDownloader(pipeline: .shared),
    clearsContentBeforeDownload: true
  )

  init() {

    super.init(frame: .null)

    imageView.backgroundColor = .init(white: 0.5, alpha: 0.2)

    let buttonsView = SwiftUIHostingView { [imageView] in
      HStack {
        Button("1") {

          let basePhotoURLString = "https://images.unsplash.com/photo-1660668377331-da480e5339a0"

          imageView.setMultiplexImage(
            .init(
              identifier: basePhotoURLString,
              urls: buildURLs(basePhotoURLString)
            )
          )

        }
        Button("2") {
          let basePhotoURLString = "https://images.unsplash.com/photo-1658214764191-b002b517e9e5"

          imageView.setMultiplexImage(
            .init(
              identifier: basePhotoURLString,
              urls: buildURLs(basePhotoURLString)
            )
          )

        }
        Button("3") {
          let basePhotoURLString = "https://images.unsplash.com/photo-1587126396803-be14d33e49cf"

          imageView.setMultiplexImage(
            .init(
              identifier: basePhotoURLString,
              urls: buildURLs(basePhotoURLString)
            )
          )
        }
      }
    }

    Mondrian.buildSubviews(on: self) {
      VStackBlock {
        imageView
          .viewBlock
          .size(.init(width: 300, height: 300))
        buttonsView
      }
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

}

@available(iOS 17, *)#Preview("UIKit"){
  let view = AsyncMultiplexImageView(
    downloader: _SlowDownloader(pipeline: .shared),
    clearsContentBeforeDownload: true
  )
  view.setMultiplexImage(
    .init(
      identifier: "https://images.unsplash.com/photo-1660668377331-da480e5339a0",
      urls: buildURLs("https://images.unsplash.com/photo-1660668377331-da480e5339a0")
    )
  )
  view.frame = .init(origin: .zero, size: .init(width: 300, height: 300))
  return view
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
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
