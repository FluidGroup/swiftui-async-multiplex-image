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
  ) async throws -> DownloadResult {

    #if DEBUG

    try? await Task.sleep(nanoseconds: UInt64(debugDelay * 1_000_000_000))

    #endif

    var request = ImageRequest(
      urlRequest: candidate.urlRequest,
    )

    // Decode only the pixels needed to fill the view. The resize processor is
    // still needed to perform the final aspect-fill crop.
    request.thumbnail = .init(
      size: displaySize,
      unit: .points,
      contentMode: .aspectFill
    )

    let task = pipeline.imageTask(with: request)
    
    let begin = CACurrentMediaTime()
        
    let result = try await task.response
    
    let end = CACurrentMediaTime()
    
    let took = end - begin
    
    var isFromCache: Bool {
      switch result.cacheType {
      case .memory, .disk:
        return true
      default:
        return false
      }
    }
    
    return .init(
      image: result.image,
      isFromCache: isFromCache,
      time: took
    )
        
  }
  
}
