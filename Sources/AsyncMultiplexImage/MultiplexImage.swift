import Foundation

public struct MultiplexImage: Hashable {

  public static func == (lhs: MultiplexImage, rhs: MultiplexImage) -> Bool {
    lhs.identifier == rhs.identifier
  }

  public func hash(into hasher: inout Hasher) {
    identifier.hash(into: &hasher)
  }

  public let identifier: String

  private(set) var _urlsProvider: @MainActor (CGSize) -> [URL]

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

// MARK: convenience init
extension MultiplexImage {

  public init(constant: URL) {
    self.identifier = constant.absoluteString
    self._urlsProvider = { _ in [constant] }
  }
}
