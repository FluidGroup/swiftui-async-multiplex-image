import XCTest
import SwiftUI

@testable import AsyncMultiplexImage

final class swiftui_AsyncMultiplexImageTests: XCTestCase {

  func testUpdateTriggerIgnoresSubpixelFloatingPointNoise() {
    let first = AsyncMultiplexImageUpdateTrigger(
      displaySize: CGSize(width: 378, height: 529.3333333333334),
      displayScale: 2,
      image: nil
    )
    let second = AsyncMultiplexImageUpdateTrigger(
      displaySize: CGSize(width: 378, height: 529.3333333333333),
      displayScale: 2,
      image: nil
    )

    XCTAssertEqual(first, second)
  }

  func testUpdateTriggerDetectsPhysicalPixelSizeChange() {
    let first = AsyncMultiplexImageUpdateTrigger(
      displaySize: CGSize(width: 378, height: 529),
      displayScale: 2,
      image: nil
    )
    let second = AsyncMultiplexImageUpdateTrigger(
      displaySize: CGSize(width: 378, height: 529.5),
      displayScale: 2,
      image: nil
    )

    XCTAssertNotEqual(first, second)
  }
}
