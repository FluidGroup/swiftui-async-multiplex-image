import AsyncMultiplexImage
import AsyncMultiplexImage_Nuke
import Nuke
import SwiftUI

func buildURLs(baseURLString: String, size: CGSize) -> [URL] {

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

    Group {
      AsyncMultiplexImage(
        multiplexImage: .init(identifier: "", urlsProvider: { size in
          buildURLs(
            baseURLString:
              "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8",
            size: size
          )
        }),
        downloader: AsyncMultiplexImageNukeDownloader(pipeline: .shared, debugDelay: 2)
      ) { phase in
        switch phase {
        case .empty:
          Rectangle()
            .foregroundColor(.yellow)
            .overlay(Text("Loading"))
        case .progress(let image):
          image
            .resizable()
            .scaledToFill()
            .overlay(Text("Progress"))

        case .success(let image):
          image
            .resizable()
            .scaledToFill()
            .overlay(Text("Done"))
        case .failure(let error):
          Text("Error")
        }
      }
      .frame(width: 300, height: 300)
      .overlay(Color.red.opacity(0.3))
    }
  }
}

struct BookAlign: View, PreviewProvider {
  var body: some View {
    if #available(iOS 15, *) {
      Content()
    }
  }

  static var previews: some View {
    Self()
  }

  @available(iOS 15, *)
  private struct Content: View {

    var body: some View {
      ZStack {
        AsyncImage(
          url: .init(
            string:
              "https://images.unsplash.com/photo-1492446845049-9c50cc313f00?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8"
          )!
        ) { phase in
          switch phase {
          case .empty:
            Rectangle()
              .foregroundColor(.yellow)
              .overlay(Text("Loading"))
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
              .overlay(Text("Done"))
          case .failure(let error):
            Text("Error")
          }
        }
      }
      .frame(width: 200, height: 200)
      .overlay(Color.red.opacity(0.3))
    }
  }
}
