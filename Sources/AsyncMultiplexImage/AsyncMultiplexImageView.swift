
#if canImport(UIKit)
import UIKit

open class AsyncMultiplexImageView: UIView {

  public protocol OffloadStrategy {
    func offloads(using state: borrowing State) -> Bool
  }

  public struct OffloadInvisibleStrategy: OffloadStrategy {

    public init() {

    }

    public func offloads(using state: borrowing State) -> Bool {
      state.isInDisplay == false
    }
  }

  public struct State: ~Copyable {

    /// Whether the app is in background state
    public var isInBackground: Bool = false

    /// Whether the view is in view hierarchy
    public var isInDisplay: Bool = false
  }

  // MARK: - Properties

  public let downloader: any AsyncMultiplexImageDownloader
  public let offloadStrategy: (any OffloadStrategy)?

  private var task: Task<Void, Never>?

  private var currentUsingNetworkImage: MultiplexImage?
  private var currentUsingImage: UIImage?

  private var currentUsingContentSize: CGSize?
  private let clearsContentBeforeDownload: Bool

  private let imageView: UIImageView = .init()

  private var state: State = .init() {
    didSet {
      onUpdateState(state: state)
    }
  }

  // MARK: - Initializers

  public init(
    downloader: any AsyncMultiplexImageDownloader,
    offloadStrategy: (any OffloadStrategy)? = nil,
    clearsContentBeforeDownload: Bool = true
  ) {

    self.downloader = downloader
    self.offloadStrategy = offloadStrategy
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

  private func onUpdateState(state: borrowing State) {

    if state.isInBackground || state.isInDisplay == false {

      let offloads = offloadStrategy?.offloads(using: state)

      if let offloads, offloads {
        self.task?.cancel()
        self.task = nil
        unloadNetworkImage()
      }

    } else {
      if let _ = currentUsingNetworkImage {
        startDownload()
      }
    }

  }

  open override func layoutSubviews() {
    super.layoutSubviews()

    if let _ = currentUsingNetworkImage, bounds.size != currentUsingContentSize {
      currentUsingContentSize = bounds.size
      startDownload()
    }
  }

  open override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    state.isInDisplay = newWindow != nil
  }

  @objc
  private func didEnterBackground() {
    state.isInBackground = true
  }

  @objc
  private func willEnterForeground() {
    state.isInBackground = false
  }

  public func setMultiplexImage(_ image: MultiplexImage) {
    currentUsingNetworkImage = image
    startDownload()
  }

  public func setImage(_ image: UIImage) {

    if clearsContentBeforeDownload {
      imageView.image = nil
    }

    currentUsingNetworkImage = nil
    currentUsingImage = image
    imageView.image = image
    
    self.task?.cancel()
    self.task = nil
    
  }

  public func clearImage() {
    currentUsingNetworkImage = nil
    imageView.image = nil
    
    self.task?.cancel()
    self.task = nil
  }

  private func startDownload() {

    guard let image = currentUsingNetworkImage else {
      return
    }

    let newSize = bounds.size

    guard newSize.height > 0 && newSize.width > 0 else {
      return
    }

    // making new candidates
    let context = MultiplexImage.Context(
      targetSize: newSize,
      displayScale: UIScreen.main.scale
    )
    
    let urls = image.makeURLs(context: context)

    let candidates = urls.enumerated().map { i, e in
      AsyncMultiplexImageCandidate(index: i, urlRequest: .init(url: e))
    }

    // start download

    let currentTask = Task { [downloader, capturedImage = image] in
      // this instance will be alive until finish
      let container = ResultContainer()
      let stream = await container.makeStream(
        candidates: candidates,
        downloader: downloader,
        displaySize: newSize
      )

      do {
        for try await item in stream {

          // TODO: support custom animation

          if capturedImage == self.currentUsingNetworkImage {

            await MainActor.run {

              guard Task.isCancelled == false else {
                return
              }

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

        }

        Log.debug(.uiKit, "download finished")
      } catch {
        // FIXME: Error handling
      }
    }

    self.task = currentTask
  }

  private func unloadNetworkImage() {

    guard let _ = currentUsingNetworkImage else {
      return
    }

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
