import Foundation

public struct MultiplexImage: Hashable, Sendable {
  
  public enum URLContainer: Sendable {
    case single(URL)
    case multiple([URL])
    case dynamic(@Sendable (borrowing Context) -> [URL])
  }
  
  public struct Context: ~Copyable {
    public let targetSize: CGSize
    public let displayScale: CGFloat
    
    init(
      targetSize: consuming CGSize,
      displayScale: consuming CGFloat
    ) {
      self.targetSize = targetSize
      self.displayScale = displayScale
    }
  }

  public static func == (lhs: MultiplexImage, rhs: MultiplexImage) -> Bool {
    lhs.identifier == rhs.identifier
  }

  public func hash(into hasher: inout Hasher) {
    identifier.hash(into: &hasher)
  }

  public let identifier: String

  private let urlContainer: URLContainer
  
  /**
   User defined flag for any purpose.
   */
  public var flag: UInt64

  /**
    - Parameters:
      - identifier: The unique identifier of the image.
      - urlsProvider: The provider of the image URLs as the first item is the top priority.
   */
  public init(
    flag: UInt64 = 0,
    identifier: String,
    urlsProvider: @escaping @Sendable (borrowing Context) -> [URL]
  ) {
    self.flag = flag
    self.identifier = identifier
    self.urlContainer = .dynamic(urlsProvider)
  }

  public init(
    flag: UInt64 = 0,
    identifier: String,
    urls: [URL]
  ) {
    self.flag = flag
    self.identifier = identifier
    self.urlContainer = .multiple(urls)
  }
  
  func makeURLs(context: borrowing Context) -> [URL] {
    switch urlContainer {
    case .single(let url):
      return [url]
    case .multiple(let urls):
      return urls
    case .dynamic(let provider):
      return provider(context)
    }      
  }
  
}

// MARK: convenience init
extension MultiplexImage {

  public init(constant: URL) {
    self.flag = 0
    self.identifier = constant.absoluteString
    self.urlContainer = .single(constant)
  }
}
