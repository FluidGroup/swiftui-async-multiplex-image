import Foundation
import SwiftUI
import SwiftUISupport
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

  static let generic: OSLog = makeOSLogInDebug {
    OSLog.init(subsystem: "app.muukii", category: "default")
  }
  static let view: OSLog = makeOSLogInDebug {
    OSLog.init(subsystem: "app.muukii", category: "SwiftUIVersion")
  }

  static let uiKit: OSLog = makeOSLogInDebug {
    OSLog.init(subsystem: "app.muukii", category: "UIKitVersion")
  }

}

@MainActor
public final class DownloadManager {

  public static let shared: DownloadManager = .init()

}

public protocol AsyncMultiplexImageDownloader: Actor {

  func download(candidate: AsyncMultiplexImageCandidate, displaySize: CGSize) async throws -> UIImage
  
  func deprioritize(candidates: some Sequence<AsyncMultiplexImageCandidate>)
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

  private let multiplexImage: MultiplexImage
  private let downloader: Downloader
  private let content: (AsyncMultiplexImagePhase) -> Content
  private let clearsContentBeforeDownload: Bool
  // sharing
  @StateObject private var viewModel: _AsyncMultiplexImageViewModel = .init()

  public init(
    multiplexImage: MultiplexImage,
    downloader: Downloader,
    clearsContentBeforeDownload: Bool = true,
    @ViewBuilder content: @escaping (AsyncMultiplexImagePhase) -> Content
  ) {

    self.clearsContentBeforeDownload = clearsContentBeforeDownload
    self.multiplexImage = multiplexImage
    self.downloader = downloader
    self.content = content

  }

  public var body: some View {
    _AsyncMultiplexImage(
      viewModel: viewModel,
      clearsContentBeforeDownload: clearsContentBeforeDownload,
      multiplexImage: multiplexImage,
      downloader: downloader,
      content: content
    )
  }

}

@MainActor
final class _AsyncMultiplexImageViewModel: ObservableObject {

  private var task: Task<Void, Never>?

  func registerCurrentTask(_ task: Task<Void, Never>?) {
    self.cancelCurrentTask()
    self.task = task
  }

  func cancelCurrentTask() {
    guard let task else { return }
    guard task.isCancelled == false else { return }
    task.cancel()
  }

  deinit {
    guard let task else { return }
    guard task.isCancelled == false else { return }
    task.cancel()
  }

}

private struct _AsyncMultiplexImage<Content: View, Downloader: AsyncMultiplexImageDownloader>: View {

  private struct UpdateTrigger: Equatable {
    let size: CGSize
    let image: MultiplexImage
  }

  @State private var candidates: [AsyncMultiplexImageCandidate] = []
  @State private var item: ResultContainer.Item?

  let viewModel: _AsyncMultiplexImageViewModel

  private let multiplexImage: MultiplexImage
  private let downloader: Downloader
  private let content: (AsyncMultiplexImagePhase) -> Content
  private let clearsContentBeforeDownload: Bool

  public init(
    viewModel: _AsyncMultiplexImageViewModel,
    clearsContentBeforeDownload: Bool,
    multiplexImage: MultiplexImage,
    downloader: Downloader,
    @ViewBuilder content: @escaping (AsyncMultiplexImagePhase) -> Content
  ) {

    self.viewModel = viewModel
    self.clearsContentBeforeDownload = clearsContentBeforeDownload
    self.multiplexImage = multiplexImage
    self.downloader = downloader
    self.content = content
  }

  public var body: some View {

    GeometryReader { proxy in
      content(
        {
          switch item {
          case .none:
            return .empty
          case .some(.progress(let image)):
            return .progress(.init(uiImage: image).renderingMode(.original))
          case .some(.final(let image)):
            return .success(.init(uiImage: image).renderingMode(.original))
          }
        }()
      )
      .frame(width: proxy.size.width, height: proxy.size.height)
      .onChangeWithPrevious(
        of: UpdateTrigger(
          size: proxy.size,
          image: multiplexImage
        ),
        emitsInitial: true,
        perform: { trigger, _ in

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

          // making new candidates
          let urls = multiplexImage._urlsProvider(newSize)

          let candidates = urls.enumerated().map { i, e in
            AsyncMultiplexImageCandidate(index: i, urlRequest: .init(url: e))
          }

          // start download

          let currentTask = Task.detached {
            // this instance will be alive until finish
            let container = ResultContainer()
            let stream = await container.makeStream(
              candidates: candidates,
              downloader: downloader,
              displaySize: newSize
            )

            do {
              for try await item in stream {
                await MainActor.run {
                  self.item = item
                }
              }
            } catch {
              // FIXME: Error handling
            }
          }

          viewModel.registerCurrentTask(currentTask)
        }
      )
      .clipped()
      .onDisappear { 
        Task {
          await downloader.deprioritize(candidates: candidates)
        }
      }

    }
  }

}

actor ResultContainer {

  enum Item {
    case progress(UIImage)
    case final(UIImage)
  }
  
  private var lastCandidate: AsyncMultiplexImageCandidate? = nil

  private var idealImageTask: Task<Void, Never>?
  private var progressImagesTask: Task<Void, Never>?    

  deinit {
    idealImageTask?.cancel()
    progressImagesTask?.cancel()
  }
  
  func makeStream<Downloader: AsyncMultiplexImageDownloader>(
    candidates: [AsyncMultiplexImageCandidate],
    downloader: Downloader,
    displaySize: CGSize
  ) -> AsyncThrowingStream<Item, Error> {

    Log.debug(.`generic`, "Load: \(candidates.map { $0.urlRequest })")
    
    return .init { [self] continuation in

      continuation.onTermination = { [self] termination in

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
          let result = try await downloader.download(
            candidate: idealCandidate,
            displaySize: displaySize
          )

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
            let result = try await downloader.download(
              candidate: candidate,
              displaySize: displaySize
            )

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
