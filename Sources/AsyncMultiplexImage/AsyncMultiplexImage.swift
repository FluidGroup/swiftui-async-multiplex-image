import Foundation
import SwiftUI
import SwiftUISupportBackport
import os.log

enum Log {
  
  static func debug(
    file: StaticString = #file,
    line: UInt = #line,
    _ log: OSLog,
    _ object: @autoclosure () -> Any
  ) {
    os_log(
      .default,
      log: log,
      "%{public}@\n%{public}@:%{public}@",
      "\(object())",
      "\(file)",
      "\(line.description)"
    )
  }
  
  static func error(
    file: StaticString = #file,
    line: UInt = #line,
    _ log: OSLog,
    _ object: @autoclosure () -> Any
  ) {
    os_log(
      .error,
      log: log,
      "%{public}@\n%{public}@:%{public}@",
      "\(object())",
      "\(file)",
      "\(line.description)"
    )
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
  
  static let generic: OSLog = makeOSLogInDebug(isEnabled: false) {
    OSLog.init(subsystem: "app.muukii", category: "default")
  }
  static let view: OSLog = makeOSLogInDebug {
    OSLog.init(subsystem: "app.muukii", category: "SwiftUIVersion")
  }
  
  static let uiKit: OSLog = makeOSLogInDebug {
    OSLog.init(subsystem: "app.muukii", category: "UIKitVersion")
  }
  
}

public struct DownloadResult: Sendable {
  
  public struct Metrics: Sendable, Equatable {
    
    public let isFromCache: Bool
    public let time: TimeInterval
    
  }
    
  public let image: UIImage
  public let metrics: Metrics
    
  public init(
    image: UIImage,
    isFromCache: Bool,
    time: TimeInterval
  ) { 
    self.image = image
    self.metrics = .init(
      isFromCache: isFromCache,
      time: time
    )

  }
}

public protocol AsyncMultiplexImageDownloader: Actor {
  
  func download(
    candidate: AsyncMultiplexImageCandidate,
    displaySize: CGSize
  ) async throws
  -> DownloadResult
  
}

public enum Source: Equatable, Sendable {
  case local
  case remote(DownloadResult.Metrics)
}

public enum AsyncMultiplexImagePhase {
  case empty
  case progress(Image, Source)
  case success(Image, Source)
  case failure(Error)
}

public struct AsyncMultiplexImageCandidate: Hashable, Sendable {
  
  public let index: Int
  public let urlRequest: URLRequest
  
}

public enum ImageRepresentation: Equatable {
  case remote(MultiplexImage)
  case loaded(Image)
}

public struct AsyncMultiplexImage<
  Content: AsyncMultiplexImageContent, Downloader: AsyncMultiplexImageDownloader
>: View {
  
  private let imageRepresentation: ImageRepresentation
  private let downloader: Downloader
  private let content: Content
  
  private let clearsContentBeforeDownload: Bool
  
  // convenience init
  public init(
    multiplexImage: MultiplexImage,
    downloader: Downloader,
    clearsContentBeforeDownload: Bool = true,
    content: Content
  ) {
    self.init(
      imageRepresentation: .remote(multiplexImage),
      downloader: downloader,
      clearsContentBeforeDownload: clearsContentBeforeDownload,
      content: content
    )
  }
  
  public init(
    imageRepresentation: ImageRepresentation,
    downloader: Downloader,
    clearsContentBeforeDownload: Bool = true,
    content: Content
  ) {
    
    self.clearsContentBeforeDownload = clearsContentBeforeDownload
    self.imageRepresentation = imageRepresentation
    self.downloader = downloader
    self.content = content
    
  }
  
  public var body: some View {
    _AsyncMultiplexImage(
      clearsContentBeforeDownload: clearsContentBeforeDownload,
      imageRepresentation: imageRepresentation,
      downloader: downloader,
      content: content
    )
  }
  
}

private struct _AsyncMultiplexImage<
  Content: AsyncMultiplexImageContent, Downloader: AsyncMultiplexImageDownloader
>: View {
  
  private struct UpdateTrigger: Equatable {
    let size: CGSize
    let image: ImageRepresentation
  }
  
  @State private var item: ResultContainer.ItemSwiftUI?
  
  @State private var displaySize: CGSize = .zero  
  @Environment(\.displayScale) var displayScale
  
  private let imageRepresentation: ImageRepresentation
  private let downloader: Downloader
  private let content: Content
  private let clearsContentBeforeDownload: Bool
  
  public init(
    clearsContentBeforeDownload: Bool,
    imageRepresentation: ImageRepresentation,
    downloader: Downloader,
    content: Content
  ) {
    
    self.clearsContentBeforeDownload = clearsContentBeforeDownload
    self.imageRepresentation = imageRepresentation
    self.downloader = downloader
    self.content = content
  }
  
  private static func phase(from: ResultContainer.ItemSwiftUI?) -> AsyncMultiplexImagePhase {
    
    guard let from else {
      return .empty
    }
    
    switch from.phase {
    case .progress(let image, let source):
      return .progress(image, source)
    case .final(let image, let source):
      return .success(image, source)
    }
  }
      
  public var body: some View {
    
    Color.clear
      .overlay(
        content.body(
          phase: Self.phase(from: item)
        )
        .frame(width: displaySize.width, height: displaySize.height)     
      )
      .onGeometryChange(
        for: CGSize.self,
        of: \.size,
        action: { newValue in
          displaySize = newValue
        }
      )
      .task(
        id: UpdateTrigger(
          size: displaySize,
          image: imageRepresentation
        ),
        {
          
          if let item,
             case .final = item.phase,
             item.representation == imageRepresentation {
            // already final item loaded
            return
          }
          
          await withTaskCancellationHandler { 
            
            let newSize = displaySize
            
            guard newSize.height > 0 && newSize.width > 0 else {
              return
            }
            
            if clearsContentBeforeDownload {
              var transaction = Transaction()
              transaction.disablesAnimations = true
              withTransaction(transaction) {
                self.item = nil
              }
            }
            
            switch imageRepresentation {
            case .remote(let multiplexImage):
              
              let displayScale = self.displayScale
              let candidates = await pushBackground {               
                
                // making new candidates
                let context = MultiplexImage.Context(
                  targetSize: newSize,
                  displayScale: displayScale
                )
                
                let urls = multiplexImage.makeURLs(context: context)
                
                let candidates = urls.enumerated().map { i, e in
                  AsyncMultiplexImageCandidate(index: i, urlRequest: .init(url: e))
                }
                
                return candidates
              }
              
              guard Task.isCancelled == false else {
                return
              }
              
              let stream = await DownloadManager.shared.start(
                source: multiplexImage,
                candidates: candidates,
                downloader: downloader,
                displaySize: newSize
              )
              
              guard Task.isCancelled == false else {
                return
              }
              
              do {
                for try await item in stream {
                  
                  guard Task.isCancelled == false else {
                    return
                  }
                  
                  await MainActor.run {
                    self.item = .init(
                      representation: imageRepresentation,
                      phase: item.swiftUI
                    )
                  }
                }
              } catch {
                // FIXME: Error handling
              }                    
              
            case .loaded(let image):
              
              self.item = .init(
                representation: imageRepresentation,
                phase: .final(image, .local)
              )
              
            }
          } onCancel: { 
            // handle cancel
          }             
          
        })     
      .clipped(antialiased: true)
    //      .onDisappear { 
    //        self.task?.cancel()
    //        self.task = nil
    //      }
    
  }
  
}

private func pushBackground<Result>(task: @Sendable () -> sending Result) async -> sending Result {
  task()
}
