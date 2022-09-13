import Foundation
import SwiftUI
import os.log

enum Log {
  
  static func debug(_ log: OSLog, _ object: @autoclosure () -> Any) {
    os_log(.debug, log: log, "%@", "\(object())")
  }
  
  static func error(_ log: OSLog, _ object: @autoclosure () -> Any) {
    os_log(.error, log: log, "%@", "\(object())")
  }
  
}

extension OSLog {
  
  @inline(__always)
  private static func makeOSLogInDebug(isEnabled: Bool = true, _ factory: () -> OSLog) -> OSLog {
#if DEBUG
    return factory()
#else
    return .disabled
#endif
  }
  
  static let `default`: OSLog = makeOSLogInDebug { OSLog.init(subsystem: "app", category: "default") }
}

@MainActor
public final class DownloadManager {
  
  public static let shared: DownloadManager = .init()
  
}

public protocol AsyncMultiplexImageDownloader {
  
  func download(candidate: AsyncMultiplexImageCandidate) async throws -> Image
}

public enum AsyncMultiplexImagePhase {
  case empty
  case progress(Image)
  case success(Image)
  case failure(Error)
}

public struct AsyncMultiplexImageCandidate: Hashable {
  
  public let index: Int
  public let urlRequest: URLRequest

}

public struct AsyncMultiplexImage<Content: View, Downloader: AsyncMultiplexImageDownloader>: View {
  
  @State private var currentImage: Image?
  @State private var task: Task<Void, Never>?
  
  private let downloader: Downloader
  private let candidates: [AsyncMultiplexImageCandidate]
  private let content: (AsyncMultiplexImagePhase) -> Content
  
  /// Primitive initializer
  public init(
    urls: [URL],
    downloader: Downloader,
    @ViewBuilder content: @escaping (AsyncMultiplexImagePhase) -> Content
  ) {
    self.candidates = urls.enumerated().map { i, e in AsyncMultiplexImageCandidate(index: i, urlRequest: .init(url: e)) }
    self.downloader = downloader
    self.content = content
  }
  
  // TODO: tmp
  public init(
    urls: [URL],
    downloader: Downloader
  ) where Content == _ConditionalContent<_ConditionalContent<EmptyView, Image>, _ConditionalContent<Image, EmptyView>> {
    self.init(
      urls: urls,
      downloader: downloader,
      content: { phase in
        switch phase {
        case .empty:
          EmptyView()
        case .progress(let image):
          image
        case .success(let image):
          image
        case .failure:
          EmptyView()
        }
      }
    )
  }
  
  public var body: some View {
    Group {
      content({
        if let currentImage {
          return .success(currentImage)
        }
        return .empty
      }())
    }
    .onAppear {
      task?.cancel()
      
      let currentTask = Task {
        let container = ResultContainer()
        let stream = await container.make(candidates: candidates, on: downloader)
       
        do {
          for try await image in stream {
            currentImage = image
          }
        } catch {
          
        }
      }
      
      task = currentTask
    }
    .onDisappear {
      task?.cancel()
    }
    .id(candidates)
  }
  
}

actor ResultContainer {
  
  var lastCandidate: AsyncMultiplexImageCandidate? = nil
  
  var idealImageTask: Task<Void, Never>?
  var progressImagesTask: Task<Void, Never>?
  
  deinit {
    idealImageTask?.cancel()
    progressImagesTask?.cancel()
  }
    
  func make<Downloader: AsyncMultiplexImageDownloader>(
    candidates: [AsyncMultiplexImageCandidate],
    on downloader: Downloader
  ) -> AsyncThrowingStream<Image, Error> {
    
    Log.debug(.default, "Load: \(candidates.map { $0.urlRequest })")
    
    return .init { continuation in
      
      continuation.onTermination = { [weak self] termination in
        
        guard let self else { return }
        
        switch termination {
        case .finished, .cancelled:
          Task {
            await self.idealImageTask?.cancel()
            await self.progressImagesTask?.cancel()
          }
        @unknown default:
          break
        }
        
      }
      
      guard let idealCandidate = candidates.first else {
        continuation.finish()
        return
      }
      
      let idealImage = Task {
        
        do {
          let result = try await downloader.download(candidate: idealCandidate)

          progressImagesTask?.cancel()

          Log.debug(.default, "Loaded ideal")

          lastCandidate = idealCandidate
          continuation.yield(result)
        } catch {
          continuation.yield(with: .failure(error))
        }

        continuation.finish()
        
      }
      
      idealImageTask = idealImage
      
      let progressCandidates = candidates.dropFirst(1)
      
      guard progressCandidates.isEmpty == false else {
        return
      }

      let progressImages = Task {
        
        // download images sequentially from lower image
        for candidate in progressCandidates.reversed() {
          do {
            
            guard Task.isCancelled == false else {
              Log.debug(.default, "Cancelled progress images")
              return
            }
            
            Log.debug(.default, "Load progress image => \(candidate.index)")
            let result = try await downloader.download(candidate: candidate)
            
            guard Task.isCancelled == false else {
              Log.debug(.default, "Cancelled progress images")
              return
            }
            
            if let lastCandidate, lastCandidate.index > candidate.index {
              continuation.finish()
              return
            }
            
            
            lastCandidate = idealCandidate
            
            let yieldResult = continuation.yield(result)
            
            Log.debug(.default, "Loaded progress image => \(candidate.index), \(yieldResult)")
          } catch {
            
          }
        }
        
      }
      
      progressImagesTask = progressImages
      
    }
  }
}

