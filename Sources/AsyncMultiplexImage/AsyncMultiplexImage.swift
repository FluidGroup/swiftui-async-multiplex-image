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

public struct AsyncMultiplexImage<Content, Downloader: AsyncMultiplexImageDownloader>: View {
  
  struct Candidate: Equatable {
    
    let index: Int
    let url: URL
    
  }
  
  @State private var currentImage: Image?
  @State private var currentTasks: [(Candidate, Task<Void, Never>)] = []
    
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
      if let currentImage {
        currentImage
      } else {
        Text("Loading")
      }
    }
    .onAppear {
      if let url = urls.first {
        
        currentTask = Task {
          do {
            // TODO: consider re-entrancy
            let image = try await downloader.download(request: .init(url: url))
            currentImage = image
          } catch {
            
          }
        }
      }
    }
    .onDisappear {

    }
  }
}

