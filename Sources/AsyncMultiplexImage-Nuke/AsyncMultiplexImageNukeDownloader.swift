
import Foundation
import Nuke
import AsyncMultiplexImage
import SwiftUI

public struct AsyncMultiplexImageNukeDownloader: AsyncMultiplexImageDownloader {
    
  public let pipeline: ImagePipeline
  public let debugDelay: TimeInterval
  
  public init(
    pipeline: ImagePipeline,
    debugDelay: TimeInterval
  ) {
    self.pipeline = pipeline
    self.debugDelay = debugDelay
  }

  public func download(candidate: AsyncMultiplexImageCandidate) async throws -> Image {
    
    #if DEBUG
    
    try? await Task.sleep(nanoseconds: UInt64(debugDelay * 1_000_000_000))
    
    #endif
    let response = try await pipeline.image(for: .init(urlRequest: candidate.urlRequest))
    return .init(uiImage: response)
  }
  
}

#if DEBUG
public struct SlowDownloader: AsyncMultiplexImageDownloader {
  
  public let pipeline: ImagePipeline
  
  public init(pipeline: ImagePipeline) {
    self.pipeline = pipeline
  }
  
  public func download(candidate: AsyncMultiplexImageCandidate) async throws -> Image {
    try? await Task.sleep(nanoseconds: 5_000_000_000 - ((UInt64(candidate.index) * 1_000_000_000)))
    let response = try await pipeline.image(for: .init(urlRequest: candidate.urlRequest))
    return .init(uiImage: response)
  }
  
}
#endif
