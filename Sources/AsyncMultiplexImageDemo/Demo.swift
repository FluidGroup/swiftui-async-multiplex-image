import AsyncMultiplexImage
import AsyncMultiplexImage_Nuke
import SwiftUI
import Nuke


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
      downloader: SlowDownloader(pipeline: .shared)
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
