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
      downloader: AsyncMultiplexImageNukeDownloader.shared,
      content: AsyncMultiplexImageBasicContent()
    )
  }

}

#Preview("1") {
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

#Preview("2") {
  AsyncMultiplexImageNuke(
    imageRepresentation: .remote(
      .init(
        constant: URL(
          string:
            "https://images.unsplash.com/photo-1759395162866-8a1b6237ad6a?q=80&w=2988&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
        )!
      )
    )
  )
//  .aspectRatio(contentMode: .fill)
  .padding()
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
