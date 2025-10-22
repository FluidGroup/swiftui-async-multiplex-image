import AsyncMultiplexImage
import AsyncMultiplexImage_Nuke
import Nuke
import SwiftUI

struct OptionalImageDemo: View, PreviewProvider {
  var body: some View {
    ContentView()
  }

  static var previews: some View {
    Self()
      .previewDisplayName("Optional Image Demo")
  }

  private struct ContentView: View {

    @State private var imageRepresentation: ImageRepresentation? = nil

    private let imageURLs = [
      "https://images.unsplash.com/photo-1660668377331-da480e5339a0",
      "https://images.unsplash.com/photo-1658214764191-b002b517e9e5",
      "https://images.unsplash.com/photo-1587126396803-be14d33e49cf",
    ]

    var body: some View {
      VStack(spacing: 20) {

        // Current state indicator
        Text("Current state: \(stateDescription)")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.top)

        // Image view
        AsyncMultiplexImage(
          imageRepresentation: imageRepresentation,
          downloader: _SlowDownloader(pipeline: .shared),
          content: PlaceholderContent()
        )
        .frame(height: 400)
        .clipped()

        // Control buttons
        VStack(spacing: 12) {
          HStack(spacing: 12) {
            ForEach(0..<imageURLs.count, id: \.self) { index in
              Button("Load Image \(index + 1)") {
                loadImage(index: index)
              }
              .buttonStyle(.bordered)
            }
          }

          Button("Clear") {
            clearImage()
          }
          .buttonStyle(.borderedProminent)
          .tint(.red)
        }
        .padding(.horizontal)

        Spacer()
      }
      .navigationTitle("Optional Image Demo")
    }

    private var stateDescription: String {
      if let imageRepresentation {
        switch imageRepresentation {
        case .remote(let multiplexImage):
          return "some(remote: \(multiplexImage.identifier.prefix(30))...)"
        case .loaded:
          return "some(loaded)"
        }
      } else {
        return "nil"
      }
    }

    private func loadImage(index: Int) {
      let urlString = imageURLs[index]
      imageRepresentation = .remote(
        MultiplexImage(
          identifier: urlString,
          urls: buildURLs(urlString)
        )
      )
    }

    private func clearImage() {
      imageRepresentation = nil
    }
  }

  // Custom content with placeholder
  private struct PlaceholderContent: AsyncMultiplexImageContent {

    func body(phase: AsyncMultiplexImagePhase) -> some View {
      switch phase {
      case .empty:
        ZStack {
          Color.gray.opacity(0.2)

          VStack(spacing: 12) {
            Image(systemName: "photo")
              .font(.system(size: 60))
              .foregroundColor(.gray)

            Text("No Image (Placeholder)")
              .font(.headline)
              .foregroundColor(.secondary)

            Text("Tap 'Load Image' to display an image")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

      case .progress(let image, _):
        image
          .resizable()
          .scaledToFill()
          .transition(.opacity.animation(.easeInOut))

      case .success(let image, _):
        image
          .resizable()
          .scaledToFill()
          .transition(.opacity.animation(.easeInOut))

      case .failure:
        ZStack {
          Color.red.opacity(0.2)

          VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 60))
              .foregroundColor(.red)

            Text("Failed to load image")
              .font(.headline)
              .foregroundColor(.secondary)
          }
        }
      }
    }
  }
}
