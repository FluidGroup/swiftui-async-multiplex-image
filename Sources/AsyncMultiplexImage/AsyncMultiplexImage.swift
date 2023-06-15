import Foundation
import SwiftUI
import os.log
import SwiftUISupport

enum Log {
  
  static func debug(
    file: StaticString = #file,
    line: UInt = #line,
    _ log: OSLog,
    _ object: @autoclosure () -> Any
  ) {
    os_log(.default, log: log, "%{public}@\n%{public}@:%{public}@", "\(object())", "\(file)", "\(line.description)")
  }
  
  static func error(
    file: StaticString = #file,
    line: UInt = #line,
    _ log: OSLog,
    _ object: @autoclosure () -> Any
  ) {
    os_log(.error, log: log, "%{public}@\n%{public}@:%{public}@", "\(object())", "\(file)", "\(line.description)")
  }
  
}

extension OSLog {
  
  @inline(__always)
  private static func makeOSLogInDebug(isEnabled: Bool = true, _ factory: () -> OSLog) -> OSLog {
#if DEBUG
    if ProcessInfo.processInfo.environment["ASYNC_MULTIPLEX_IMAGE_LOG_ENABLED"] == "1" {
      return factory()
    } else {
      return .disabled
    }
#else
    return .disabled
#endif
  }
  
  static let generic: OSLog = makeOSLogInDebug { OSLog.init(subsystem: "app.muukii", category: "default") }
  static let view: OSLog = makeOSLogInDebug { OSLog.init(subsystem: "app.muukii", category: "View") }
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

public struct MultiplexImage: Hashable {
  
  public static func == (lhs: MultiplexImage, rhs: MultiplexImage) -> Bool {
    lhs.identifier == rhs.identifier
  }
  
  public func hash(into hasher: inout Hasher) {
    identifier.hash(into: &hasher)
  }
  
  public let identifier: String
  
  fileprivate private(set) var _urlsProvider: @MainActor (CGSize) -> [URL]
  
  public init(
    identifier: String,
    urlsProvider: @escaping @MainActor (CGSize) -> [URL]
  ) {
    self.identifier = identifier
    self._urlsProvider = urlsProvider
  }
  
  public init(identifier: String, urls: [URL]) {
    self.init(identifier: identifier, urlsProvider: { _ in urls })
  }
  
}

public struct AsyncMultiplexImage<Content: View, Downloader: AsyncMultiplexImageDownloader>: View {

  private let multiplexImage: MultiplexImage

  private let backing: _AsyncMultiplexImage<Content, Downloader>

  public init(
    multiplexImage: MultiplexImage,
    downloader: Downloader,
    @ViewBuilder content: @escaping (AsyncMultiplexImagePhase) -> Content
  ) {

    self.multiplexImage = multiplexImage
    self.backing = _AsyncMultiplexImage(multiplexImage: multiplexImage, downloader: downloader, content: content)
  }

  public var body: some View {
    backing
      .id(multiplexImage)
  }

}

private struct _AsyncMultiplexImage<Content: View, Downloader: AsyncMultiplexImageDownloader>: View {

  @State private var candidates: [AsyncMultiplexImageCandidate] = []
    
  @State private var internalView: _internal_AsyncMultiplexImage<Content, Downloader>?
  
  private let multiplexImage: MultiplexImage
  private let downloader: Downloader
  private let content: (AsyncMultiplexImagePhase) -> Content
  
  public init(
    multiplexImage: MultiplexImage,
    downloader: Downloader,
    @ViewBuilder content: @escaping (AsyncMultiplexImagePhase) -> Content
  ) {
    
    self.multiplexImage = multiplexImage
    self.downloader = downloader
    self.content = content
  }
 
  public var body: some View {
    GeometryReader { proxy in
      Group {
        if let internalView {
          internalView
        } else {
          // for <= iOS 14
          Color.clear
        }
      }
      .onChangeWithPrevious(of: proxy.size, emitsInitial: true, perform: { newSize, _ in
        
        let urls = multiplexImage._urlsProvider(newSize)
        
        let candidates = urls.enumerated().map { i, e in AsyncMultiplexImageCandidate(index: i, urlRequest: .init(url: e)) }
        
        self.candidates = candidates
        self.internalView = .init(candidates: candidates, downloader: downloader, content: content)
      })
    }
    .id(multiplexImage)
  }
  
}

@_spi(Internal)
public struct _internal_AsyncMultiplexImage<Content: View, Downloader: AsyncMultiplexImageDownloader>: View {
  
  @State private var item: ResultContainer.Item?
  @State private var task: Task<Void, Never>?
  
  private let downloader: Downloader
  private let candidates: [AsyncMultiplexImageCandidate]
  private let content: (AsyncMultiplexImagePhase) -> Content
  
  /// Primitive initializer
  init(
    candidates: [AsyncMultiplexImageCandidate],
    downloader: Downloader,
    @ViewBuilder content: @escaping (AsyncMultiplexImagePhase) -> Content
  ) {
    self.candidates = candidates
    self.downloader = downloader
    self.content = content
  }
    
  public var body: some View {
    
    GeometryReader { proxy in
      content({
        switch item {
        case .none:
          return .empty
        case .some(.progress(let image)):
          return .progress(image.renderingMode(.original))
        case .some(.final(let image)):
          return .success(image.renderingMode(.original))
        }
      }())
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .clipped()
    .onAppear {
                  
      let currentTask = Task {
        // this instance will be alive until finish
        let container = ResultContainer()
        let stream = await container.make(candidates: candidates, on: downloader)
       
        do {
          for try await item in stream {
            self.item = item
          }
        } catch {
          // FIXME: Error handling
        }
      }
      
      task = currentTask
    }
    .onDisappear {
      task?.cancel()
    }
    
  }
  
}

actor ResultContainer {
  
  enum Item {
    case progress(Image)
    case final(Image)
  }
  
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
  ) -> AsyncThrowingStream<Item, Error> {
    
    Log.debug(.`generic`, "Load: \(candidates.map { $0.urlRequest })")
    
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

          Log.debug(.`generic`, "Loaded ideal")

          lastCandidate = idealCandidate
          continuation.yield(.final(result))
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
              Log.debug(.`generic`, "Cancelled progress images")
              return
            }
            
            Log.debug(.`generic`, "Load progress image => \(candidate.index)")
            let result = try await downloader.download(candidate: candidate)
            
            guard Task.isCancelled == false else {
              Log.debug(.`generic`, "Cancelled progress images")
              return
            }
            
            if let lastCandidate, lastCandidate.index > candidate.index {
              continuation.finish()
              return
            }
            
            
            lastCandidate = idealCandidate
            
            let yieldResult = continuation.yield(.progress(result))
            
            Log.debug(.`generic`, "Loaded progress image => \(candidate.index), \(yieldResult)")
          } catch {
            
          }
        }
        
      }
      
      progressImagesTask = progressImages
      
    }
  }
}

