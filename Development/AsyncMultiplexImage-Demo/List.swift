import AsyncMultiplexImage
import AsyncMultiplexImage_Nuke
//
//  List.swift
//  AsyncMultiplexImage-Demo
//
//  Created by Muukii on 2024/06/13.
//
import SwiftUI

struct UsingList: View {

  @State var items: [Entity] = Entity.batch()

  var body: some View {
    ScrollView {
      LazyVGrid(
        columns: [
          .init(.flexible(minimum: 0, maximum: .infinity), spacing: 16),
          .init(.flexible(minimum: 0, maximum: .infinity), spacing: 16),
          .init(.flexible(minimum: 0, maximum: .infinity), spacing: 16),
          .init(.flexible(minimum: 0, maximum: .infinity), spacing: 16),
        ], spacing: 16
      ) {
        ForEach(items) { entity in
          if entity.id == items.last?.id {
            Cell(entity: entity)
              .onAppear {
                Task {
                  let newItems = await Entity.delayBatch()
                  items.append(contentsOf: newItems)
                }
              }
          } else {
            Cell(entity: entity)
          }
        }
      }
    }
  }

}

#Preview {
  UsingList()
}

let imageURLString =
  "https://images.unsplash.com/photo-1567095761054-7a02e69e5c43?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

struct Cell: View {

  let entity: Entity

  var body: some View {
    VStack {
      AsyncMultiplexImageNuke(imageRepresentation: .remote(entity.image))
        .frame(height: 100)
      HStack {
        Image(systemName: "globe")
          .imageScale(.large)
          .foregroundStyle(.tint)
        Text(entity.name)
      }
    }
    .padding()
  }
}

struct Entity: Identifiable {

  let id: UUID
  let name: String
  let image: MultiplexImage

  static func make() -> Self {
    return .init(
      id: .init(),
      name: "Hello",
      image: .init(
        constant: URL(string: imageURLString + "&tag=\(UUID().uuidString)")!
      )
    )
  }

  static func batch() -> [Self] {
    (0..<100).map { _ in
      .make()
    }
  }

  static nonisolated func delayBatch() async -> [Self] {
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    return (0..<100).map { _ in
      .make()
    }
  }
}
