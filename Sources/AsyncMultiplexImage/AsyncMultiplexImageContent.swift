import SwiftUI

public protocol AsyncMultiplexImageContent {

  associatedtype Content: View

  @ViewBuilder
  func body(phase: AsyncMultiplexImagePhase) -> Content
}

public struct AsyncMultiplexImageBasicContent: AsyncMultiplexImageContent {
  
  public init() {}
  
  public func body(phase: AsyncMultiplexImagePhase) -> some View {
    switch phase {
    case .empty:
      Rectangle().fill(.clear)
    case .progress(let image, _):
      image
        .resizable()
        .scaledToFill()
        .transition(.opacity.animation(.bouncy))
    case .success(let image, _):
      image
        .resizable()
        .scaledToFill()
        .transition(.opacity.animation(.bouncy))
    case .failure:
      Rectangle().fill(.clear)
    }
  }
  
}
