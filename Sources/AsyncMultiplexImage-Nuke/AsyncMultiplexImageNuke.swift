import AsyncMultiplexImage
import SwiftUI

public struct AsyncMultiplexImageNuke: View {

  public let image: MultiplexImage

  public init(image: MultiplexImage) {
    self.image = image
  }

  public var body: some View {
    AsyncMultiplexImage(
      multiplexImage: image,
      downloader: AsyncMultiplexImageNukeDownloader(pipeline: .shared, debugDelay: 0)
    ) { phase in
      Group {
        switch phase {
        case .empty:
          Rectangle()
            .foregroundColor(Color.init(.displayP3, white: 0.9, opacity: 1))
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
          Rectangle()
            .foregroundColor(Color.init(.displayP3, white: 0.9, opacity: 1))
        }
      }
    }
  }

}

#Preview {
  AsyncMultiplexImageNuke(image: .init(constant: URL(string: "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8")!))
}
