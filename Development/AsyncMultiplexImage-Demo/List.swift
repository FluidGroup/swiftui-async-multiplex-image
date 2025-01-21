import AsyncMultiplexImage
import AsyncMultiplexImage_Nuke
import SwiftUI

struct StressGrid<Cell: CellType>: View {

  @State var items: [Entity] = Entity.batch()

  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        LazyVGrid(
          columns: [
            .init(.flexible(minimum: 0, maximum: .infinity), spacing: 2),
            .init(.flexible(minimum: 0, maximum: .infinity), spacing: 2),
            .init(.flexible(minimum: 0, maximum: .infinity), spacing: 2),
            .init(.flexible(minimum: 0, maximum: .infinity), spacing: 2),
          ], spacing: 2
        ) {
          ForEach(items) { entity in
            Cell(entity: entity)            
          }
        }
      }
      .onPreferenceChange(AnchorPreferenceKey.self, perform: { v in
        guard let v = v else {
          return
        }
        let bounds = proxy[v]
        print(bounds)
      })
    }
  }

}

#Preview {
  StressGrid<Cell_1>()
}

#Preview {
  StressGrid<Cell_3>()
}

let imageURLString =
  "https://images.unsplash.com/photo-1567095761054-7a02e69e5c43?q=80&w=800&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

protocol CellType: View {
  init(entity: Entity)
}

struct Cell_1: View, CellType {
  
  let entity: Entity
  
  var body: some View {
    AsyncMultiplexImageNuke(imageRepresentation: .remote(entity.image))
      .frame(height: 100)           
  }
}


struct Cell_2: View, CellType {

  let entity: Entity

  var body: some View {
    VStack {
      AsyncMultiplexImageNuke(imageRepresentation: .remote(entity.image))
        .frame(height: 100)
        .clipShape(
          RoundedRectangle(
            cornerRadius: 20,
            style: .continuous
          )
        )
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)      
    }
    .padding()
  }
}

struct Cell_3: View, CellType {
  
  final class Object: ObservableObject {
    
    @Published var value: Int = 0
    
    init() {
      print("Object.init")    
    }
    
    deinit {
//      print("Object.deinit")
    
    }
  }
  
  let entity: Entity
  
  @State private var value: Int = 0
  @StateObject private var object = Object()
  
  var body: some View {
    let _ = Self._printChanges()
    VStack {   
      Button("Up \(value)") {
        value += 1
      }  
      Button("Up \(object.value)") {
        object.value += 1
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
    (0..<100000).map { _ in
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
