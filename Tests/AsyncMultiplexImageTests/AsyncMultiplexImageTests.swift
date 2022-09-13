import XCTest
import SwiftUI

@testable import AsyncMultiplexImage

public struct SlowDownloader: AsyncMultiplexImageDownloader {
    
  public init() {
  }
  
  public func download(candidate: AsyncMultiplexImageCandidate) async throws -> Image {
    try? await Task.sleep(nanoseconds: 5_000_000_000 - ((UInt64(candidate.index) * 1_000_000_000)))
    return Image(uiImage: .init())
  }
  
}

final class swiftui_AsyncMultiplexImageTests: XCTestCase {
  func testExample() throws {
 
  }
}
