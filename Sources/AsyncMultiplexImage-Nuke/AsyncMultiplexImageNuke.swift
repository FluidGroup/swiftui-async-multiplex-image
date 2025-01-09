import AsyncMultiplexImage
import SwiftUI

public struct AsyncMultiplexImageNuke: View {

  public let imageRepresentation: ImageRepresentation

  public init(imageRepresentation: ImageRepresentation) {
    self.imageRepresentation = imageRepresentation
  }

  public var body: some View {
    AsyncMultiplexImage(
      imageRepresentation: imageRepresentation,
      downloader: AsyncMultiplexImageNukeDownloader.shared
    ) { phase in
      Group {
        switch phase {
        case .empty:
          EmptyView()
        case .progress(let image):
          image
            .resizable()
            .scaledToFill()
            .transition(.opacity.animation(.bouncy))
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
            .transition(.opacity.animation(.bouncy))          
        case .failure:
          EmptyView()
        }
      }
    }
  }

}

#Preview {
  AsyncMultiplexImageNuke(
    imageRepresentation: .remote(
      .init(
        constant: URL(
          string:
            "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8"
        )!
      )
    )
  )
}

#Preview("Rotating") {
  HStack {
    
    Rectangle()
      .frame(width: 100, height: 100)
      .rotationEffect(.degrees(10))
    
    AsyncMultiplexImageNuke(
      imageRepresentation: .remote(
        .init(
          constant: URL(
            string:
              "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8"
          )!
        )
      )
    )
    .frame(width: 100, height: 100)
    .rotationEffect(.degrees(10))
    .clipped(antialiased: true)
    
    AsyncMultiplexImageNuke(
      imageRepresentation: .remote(
        .init(
          constant: URL(
            string:
              "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8"
          )!
        )
      )
    )
    .frame(width: 100, height: 100)
    .rotationEffect(.degrees(20))
    
    AsyncMultiplexImageNuke(
      imageRepresentation: .remote(
        .init(
          constant: URL(
            string:
              "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8"
          )!
        )
      )
    )
    .frame(width: 100, height: 100)
    .rotationEffect(.degrees(30))
  }
}

#Preview {
  AsyncMultiplexImageNuke(
    imageRepresentation: .loaded(Image(systemName: "photo"))
  )
}
