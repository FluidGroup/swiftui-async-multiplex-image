# swiftui-AsyncMultiplexImage

Still in prototyping, a component that displays multiple images from lower to higher quality.

![Simulator Screen Recording - iPhone 8 - 2022-09-13 at 21 50 55](https://user-images.githubusercontent.com/1888355/189911326-6ce3b24a-ba0a-4b5f-aa1d-7c048e8c64cd.gif)

this component comes from [Texture/ASMultiplexImageNode](https://github.com/TextureGroup/Texture/blob/master/Source/ASMultiplexImageNode.h)

## Example

```
AsyncMultiplexImage(
  urls: [
  ...,
  ...,
  ...,
  ],
  downloader: ... /* do not create an instance here */
)
```
