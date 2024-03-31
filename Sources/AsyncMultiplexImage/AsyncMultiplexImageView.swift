
#if canImport(UIKit)
import UIKit

open class AsyncMultiplexImageView: UIImageView {

  // MARK: - Properties

  public let downloader: any AsyncMultiplexImageDownloader

  private let viewModel: _AsyncMultiplexImageViewModel = .init()

  private var currentUsingImage: MultiplexImage?
  private var currentUsingContentSize: CGSize?
  private let clearsContentBeforeDownload: Bool
  private var stashedImage: UIImage? = nil

  // MARK: - Initializers

  public init(
    downloader: any AsyncMultiplexImageDownloader,
    clearsContentBeforeDownload: Bool = true,
    unloadsImageOnBackground: Bool = false
  ) {
    
    self.downloader = downloader
    self.clearsContentBeforeDownload = clearsContentBeforeDownload

    super.init(frame: .null)

    self.clipsToBounds = true
    self.contentMode = .scaleAspectFill

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(willEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )

  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    Log.debug(.uiKit, "deinit \(self)")
  }

  // MARK: - Functions

  open override func layoutSubviews() {
    super.layoutSubviews()

    if let _ = currentUsingImage, bounds.size != currentUsingContentSize {
      currentUsingContentSize = bounds.size
      startDownload()
    }
  }

  @objc
  private func didEnterBackground() {
    unloadImage()
  }

  @objc
  private func willEnterForeground() {
    startDownload()
  }

  public func setMultiplexImage(_ image: MultiplexImage) {
    currentUsingImage = image
    startDownload()
  }

  private func startDownload() {

    guard let image = currentUsingImage else {
      return
    }

    let newSize = bounds.size

    guard newSize.height > 0 && newSize.width > 0 else {
      return
    }

    if clearsContentBeforeDownload {
      self.image = nil
    }

    // making new candidates
    let urls = image._urlsProvider(newSize)

    let candidates = urls.enumerated().map { i, e in
      AsyncMultiplexImageCandidate(index: i, urlRequest: .init(url: e))
    }

    // start download

    let currentTask = Task { @MainActor [downloader] in
      // this instance will be alive until finish
      let container = ResultContainer()
      let stream = await container.make(
        candidates: candidates,
        downloader: downloader,
        displaySize: newSize
      )

      do {
        for try await item in stream {

          // TODO:

          switch item {
          case .progress(let image):
            self.image = image
          case .final(let image):
            self.image = image
          }

        }
      } catch {
        // FIXME: Error handling
      }
    }

    viewModel.registerCurrentTask(currentTask)
  }

  private func unloadImage() {

    weak var _image = self.image
    self.image = nil

    #if DEBUG
    if _image != nil {
      Log.debug(.uiKit, "\(String(describing: _image)) was not deallocated afeter unload")
    }
    #endif

  }
}
#endif
