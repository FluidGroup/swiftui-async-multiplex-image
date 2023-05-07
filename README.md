# AsyncMultiplexImage

<img width="200" src="https://user-images.githubusercontent.com/1888355/189911326-6ce3b24a-ba0a-4b5f-aa1d-7c048e8c64cd.gif"/>


this component comes from [Texture/ASMultiplexImageNode](https://github.com/TextureGroup/Texture/blob/master/Source/ASMultiplexImageNode.h)

## Usage

```swift
AsyncMultiplexImage(
  multiplexImage: .init(identifier: <# identifier for image #>, urls: [...]),
  downloader: _SlowDownloader(pipeline: .shared)
) { phase in
  // here is your own content that displays images
}
```
