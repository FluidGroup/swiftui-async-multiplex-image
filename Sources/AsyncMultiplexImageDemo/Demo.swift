import AsyncMultiplexImage
import AsyncMultiplexImage_Nuke
import SwiftUI

let baseURLString = "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8"

struct AsyncMultiplexImage_Previews: PreviewProvider {
  static var previews: some View {
    AsyncMultiplexImage(
      urls: [
        URL(
          string:
            "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&q=80"
        )!
      ],
      downloader: AsyncMultiplexImageNukeDownloader(pipeline: .shared)
    )
  }
}
