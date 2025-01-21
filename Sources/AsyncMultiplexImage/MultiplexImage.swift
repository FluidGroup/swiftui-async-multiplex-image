import Foundation

public struct MultiplexImage: Hashable, Sendable {

  public static func == (lhs: MultiplexImage, rhs: MultiplexImage) -> Bool {
    lhs.identifier == rhs.identifier
  }

  public func hash(into hasher: inout Hasher) {
    identifier.hash(into: &hasher)
  }

  public let identifier: String

  private(set) var _urlsProvider: @Sendable (CGSize) -> [URL]

  /**
    - Parameters:
      - identifier: The unique identifier of the image.
      - urlsProvider: The provider of the image URLs as the first item is the top priority.
   */
  public init(
    identifier: String,
    urlsProvider: @escaping @Sendable (CGSize) -> [URL]
  ) {
    self.identifier = identifier
    self._urlsProvider = urlsProvider
  }

  public init(identifier: String, urls: [URL]) {
    self.init(identifier: identifier, urlsProvider: { _ in urls })
  }

}

// MARK: convenience init
extension MultiplexImage {

  public init(constant: URL) {
    self.identifier = constant.absoluteString
    self._urlsProvider = { _ in [constant] }
  }
}
