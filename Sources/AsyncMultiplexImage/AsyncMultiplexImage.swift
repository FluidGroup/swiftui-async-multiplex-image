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

public protocol AsyncMultiplexImageDownloader: Actor {

  func download(candidate: AsyncMultiplexImageCandidate, displaySize: CGSize) async throws
    -> UIImage

}

public enum AsyncMultiplexImagePhase {
  case empty
  case progress(Image)
  case success(Image)
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
    let isInDisplay: Bool
  }

  @State private var item: ResultContainer.ItemSwiftUI?
  @State private var task: Task<(), Never>?
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

  public var body: some View {

    Color.clear
      .overlay(
        content.body(
          phase: {
            switch item {
            case .none:
              return .empty
            case .some(.progress(let image)):
              return .progress(image)
            case .some(.final(let image)):
              return .success(image)
            }
          }()
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
      .onChangeWithPrevious(
        of: UpdateTrigger(
          size: displaySize,
          image: imageRepresentation,
          isInDisplay: true
        ),
        emitsInitial: true,
        perform: {
          trigger,
          _ in

          let newSize = trigger.size

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

          switch trigger.image {
          case .remote(let multiplexImage):

            self.task?.cancel()
            self.task = nil

            let task = Task.detached {

              // making new candidates
              let context = await MultiplexImage.Context(
                targetSize: newSize,
                displayScale: displayScale
              )
              
              let urls = multiplexImage._urlsProvider(context)

              let candidates = urls.enumerated().map { i, e in
                AsyncMultiplexImageCandidate(index: i, urlRequest: .init(url: e))
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
                    self.item = item.swiftUI
                  }
                }
              } catch {
                // FIXME: Error handling
              }

            }

            self.task = task

          case .loaded(let image):

            self.task?.cancel()
            self.task = nil
            self.item = .final(image)

          }
        }
      )
      .clipped(antialiased: true)

  }

}
