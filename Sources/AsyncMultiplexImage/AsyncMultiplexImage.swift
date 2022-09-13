import Foundation
import SwiftUI

@MainActor
public final class DownloadManager {
  
  public static let shared: DownloadManager = .init()
  
}

public protocol AsyncMultiplexImageDownloader {
  
  func download(request: URLRequest) async throws -> Image
}

public enum AsyncMultiplexImagePhase {
  case empty
  case progress(Image)
  case success(Image)
  case failure(Error)
}

struct Candidate: Hashable {
  
  let index: Int
  let url: URL
  
}

public struct AsyncMultiplexImage<Content: View, Downloader: AsyncMultiplexImageDownloader>: View {
  
  @State private var currentImage: Image?
  @State private var task: Task<Void, Never>?
  
  private let downloader: Downloader
  private let candidates: [Candidate]
  private let content: (AsyncMultiplexImagePhase) -> Content
  
  /// Primitive initializer
  public init(
    urls: [URL],
    downloader: Downloader,
    @ViewBuilder content: @escaping (AsyncMultiplexImagePhase) -> Content
  ) {
    self.candidates = urls.enumerated().map { i, e in Candidate(index: i, url: e) }
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
  
  var lastCandidate: Candidate? = nil
  
  var idealImageTask: Task<Void, Never>?
  var progressImagesTask: Task<Void, Never>?
  
  deinit {
    idealImageTask?.cancel()
    progressImagesTask?.cancel()
  }
    
  func make<Downloader: AsyncMultiplexImageDownloader>(
    candidates: [Candidate],
    on downloader: Downloader
  ) -> AsyncThrowingStream<Image, Error> {
    
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
          let result = try await downloader.download(request: .init(url: idealCandidate.url))
          
          progressImagesTask?.cancel()
          
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
            
            let result = try await downloader.download(request: .init(url: candidate.url))
            
            guard Task.isCancelled == false else {
              return
            }
            
            if let lastCandidate, lastCandidate.index < candidate.index {
              continuation.finish()
              return
            }
            
            lastCandidate = idealCandidate
            continuation.yield(result)
          } catch {
            
          }
        }
        
      }
      
      progressImagesTask = progressImages
      
    }
  }
}

func race<Downloader: AsyncMultiplexImageDownloader>(
  candidates: [Candidate],
  on downloader: Downloader
) async -> AsyncThrowingStream<Image, Error> {
  
  let container = ResultContainer()
  return await container.make(candidates: candidates, on: downloader)
  
}
