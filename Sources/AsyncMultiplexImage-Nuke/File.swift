
import Foundation
import Nuke
import AsyncMultiplexImage
import SwiftUI

public struct AsyncMultiplexImageNukeDownloader: AsyncMultiplexImageDownloader {
    
  public let pipeline: ImagePipeline
  
  public init(pipeline: ImagePipeline) {
    self.pipeline = pipeline
  }

  public func download(request: URLRequest) async throws -> Image {
    let response = try await pipeline.image(for: .init(urlRequest: request))
    return .init(uiImage: response.image)
  }
  
}
