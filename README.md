# AsyncMultiplexImage for SwiftUI

<img width="200" src="https://user-images.githubusercontent.com/1888355/189911326-6ce3b24a-ba0a-4b5f-aa1d-7c048e8c64cd.gif"/>

This library provides an asynchronous image loading solution for SwiftUI applications. It supports loading multiple image resolutions and automatically handles displaying the most appropriate image based on the available space. The library uses Swift's concurrency model, including actors and tasks, to manage image downloading efficiently.

## Features

- Asynchronous image downloading
- Supports multiple image resolutions
- Efficient image loading using Swift's concurrency model
- Logging utilities for debugging and error handling

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/YourGitHubUsername/AsyncMultiplexImage.git", from: "1.0.0")
]
```

## Starter

```
import AsyncMultiplexImage

AsyncMultiplexImageNuke(image: .init(constant: URL(...)))
```

## Usage

1. Import the library:

```swift
import AsyncMultiplexImage
```

2. Define a `MultiplexImage` with a unique identifier and a closure that returns a list of URLs for different image resolutions:

```swift
let multiplexImage = MultiplexImage(identifier: "imageID", urlsProvider: { _ in
    [URL(string: "https://example.com/image_small.png")!,
     URL(string: "https://example.com/image_medium.png")!,
     URL(string: "https://example.com/image_large.png")!]
})
```

3. Create an `AsyncMultiplexImage` view using the `MultiplexImage` and a custom downloader conforming to `AsyncMultiplexImageDownloader`:

```swift
struct MyImageView: View {
    let multiplexImage: MultiplexImage
    let downloader: MyImageDownloader

    var body: some View {
        AsyncMultiplexImage(multiplexImage: multiplexImage, downloader: downloader) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .progress(let image):
                image.resizable()
            case .success(let image):
                image.resizable()
            case .failure(let error):
                Text("Error: \(error.localizedDescription)")
            }
        }
    }
}
```

4. Implement a custom image downloader conforming to `AsyncMultiplexImageDownloader`:

```swift
class MyImageDownloader: AsyncMultiplexImageDownloader {
    func download(candidate: AsyncMultiplexImageCandidate) async throws -> Image {
        // Download the image and return a SwiftUI.Image instance
    }
}
```

## License

This library is available under the MIT License. See the [LICENSE](LICENSE) file for more information.
