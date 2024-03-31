
#if canImport(UIKit)
import UIKit

open class AsyncMultiplexImageView: UIView {

  // MARK: - Properties

  public let downloader: any AsyncMultiplexImageDownloader

  private let viewModel: _AsyncMultiplexImageViewModel = .init()

  private var currentUsingImage: MultiplexImage?
  private var currentUsingContentSize: CGSize?
  private let clearsContentBeforeDownload: Bool

  private let imageView: UIImageView = .init()

  // MARK: - Initializers

  public init(
    downloader: any AsyncMultiplexImageDownloader,
    clearsContentBeforeDownload: Bool = true,
    unloadsImageOnBackground: Bool = false
  ) {
    
    self.downloader = downloader
    self.clearsContentBeforeDownload = clearsContentBeforeDownload

    super.init(frame: .null)

    imageView.clipsToBounds = true
    imageView.contentMode = .scaleAspectFill

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

    addSubview(imageView)
    imageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: topAnchor),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
      imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
    ])

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
      imageView.image = nil
    }

    // making new candidates
    let urls = image._urlsProvider(newSize)

    let candidates = urls.enumerated().map { i, e in
      AsyncMultiplexImageCandidate(index: i, urlRequest: .init(url: e))
    }

    // start download

    let currentTask = Task { [downloader] in
      // this instance will be alive until finish
      let container = ResultContainer()
      let stream = await container.make(
        candidates: candidates,
        downloader: downloader,
        displaySize: newSize
      )

      do {
        for try await item in stream {

          // TODO: support custom animation

          await MainActor.run {
            CATransaction.begin()
            let transition = CATransition()
            transition.duration = 0.13
            switch item {
            case .progress(let image):
              imageView.image = image
            case .final(let image):
              imageView.image = image
            }
            self.layer.add(transition, forKey: "transition")
            CATransaction.commit()
          }

        }

        Log.debug(.uiKit, "download finished")
      } catch {
        // FIXME: Error handling
      }
    }

    viewModel.registerCurrentTask(currentTask)
  }

  private func unloadImage() {

    weak var _image = imageView.image
    imageView.image = nil

    #if DEBUG
    if _image != nil {
      Log.debug(.uiKit, "\(String(describing: _image)) was not deallocated afeter unload")
    }
    #endif

  }
}
#endif
