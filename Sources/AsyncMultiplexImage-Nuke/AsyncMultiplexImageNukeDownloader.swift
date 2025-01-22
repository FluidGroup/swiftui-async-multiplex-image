import AsyncMultiplexImage
import Foundation
import Nuke
import SwiftUI

public actor AsyncMultiplexImageNukeDownloader: AsyncMultiplexImageDownloader {
  
  public static let `shared` = AsyncMultiplexImageNukeDownloader(pipeline: .shared, debugDelay: 0)

  public let pipeline: ImagePipeline
  public let debugDelay: TimeInterval
  
  public init(
    pipeline: ImagePipeline,
    debugDelay: TimeInterval
  ) {
    self.pipeline = pipeline
    self.debugDelay = debugDelay
  }

  public func download(
    candidate: AsyncMultiplexImageCandidate,
    displaySize: CGSize
  ) async throws -> UIImage {

    #if DEBUG

    try? await Task.sleep(nanoseconds: UInt64(debugDelay * 1_000_000_000))

    #endif

    let task = pipeline.imageTask(with: .init(
        urlRequest: candidate.urlRequest,
        processors: [
          ImageProcessors.Resize(
            size: displaySize,
            unit: .points,
            contentMode: .aspectFill,
            crop: false,
            upscale: false
          )
        ]
      )
    )
    
    let result = try await task.image
        
    return result
  }
  
}
