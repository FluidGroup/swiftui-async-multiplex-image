//
//  DownloadManager.swift
//  AsyncMultiplexImage
//
//  Created by Muukii on 2025/01/21.
//
import SwiftUI

actor DownloadManager {
  
  @MainActor
  static let shared = DownloadManager()
  
  private init() {}
  
  func start(
    source: MultiplexImage,
    candidates: [AsyncMultiplexImageCandidate],
    downloader: any AsyncMultiplexImageDownloader,
    displaySize: CGSize
  ) async -> sending AsyncThrowingStream<ResultContainer.Item, any Error> {
    
    // this instance will be alive until finish
    let container = ResultContainer()
    
    let stream = await container.makeStream(
      candidates: candidates,
      downloader: downloader,
      displaySize: displaySize
    )
    
    return stream
    
  }
  
}

actor ResultContainer {
  
  enum Item: Sendable {
    case progress(UIImage, Source)
    case final(UIImage, Source)
    
    var swiftUI: ItemSwiftUI.Phase {
      switch self {
      case .progress(let image, let source):
        return .progress(.init(uiImage: image).renderingMode(.original), source)
      case .final(let image, let source):
        return .final(.init(uiImage: image).renderingMode(.original), source)
      }
    }
  }
  
  struct ItemSwiftUI: Equatable {
         
    enum Phase: Equatable {
      case progress(Image, Source)
      case final(Image, Source)
    }
    
    let representation: ImageRepresentation
    let phase: Phase
    
  }
  
  private var referenceCount: UInt64 = 0
  
  private var lastCandidate: AsyncMultiplexImageCandidate? = nil
  
  private var idealImageTask: Task<Void, Never>?
  private var progressImagesTask: Task<Void, Never>?
  
  deinit {
    idealImageTask?.cancel()
    progressImagesTask?.cancel()
  }
  
  func incrementReference() {
    referenceCount += 1
  }
  
  func decrementReference() {
    referenceCount -= 1
  }
  
  func makeStream<Downloader: AsyncMultiplexImageDownloader>(
    candidates: [AsyncMultiplexImageCandidate],
    downloader: Downloader,
    displaySize: CGSize
  ) -> AsyncThrowingStream<Item, Error> {
    
    Log.debug(.`generic`, "Load: \(candidates.map { $0.urlRequest })")
    
    return .init { [self] continuation in
      
      continuation.onTermination = { [self] termination in
        
        switch termination {
        case .finished, .cancelled:
          Task {
            await self.idealImageTask?.cancel()
            await self.progressImagesTask?.cancel()
          }
        @unknown default:
          break
        }
        
      }
      
      guard let idealCandidate = candidates.first else {
        continuation.finish()
        return
      }
      
      let idealImage = Task {
        
        do {
          let result = try await downloader.download(
            candidate: idealCandidate,
            displaySize: displaySize
          )
          
          progressImagesTask?.cancel()
          
          Log.debug(.`generic`, "Loaded ideal")
          
          lastCandidate = idealCandidate
          continuation.yield(.final(result.image, .remote(result.metrics)))
        } catch {
          continuation.yield(with: .failure(error))
        }
        
        continuation.finish()
        
      }
      
      idealImageTask = idealImage
      
      let progressCandidates = candidates.dropFirst(1)
      
      guard progressCandidates.isEmpty == false else {
        return
      }
      
      let progressImages = Task {
        
        // download images sequentially from lower image
        for candidate in progressCandidates.reversed() {
          do {
            
            guard Task.isCancelled == false else {
              Log.debug(.`generic`, "Cancelled progress images")
              return
            }
            
            Log.debug(.`generic`, "Load progress image => \(candidate.index)")
            let result = try await downloader.download(
              candidate: candidate,
              displaySize: displaySize
            )
            
            guard Task.isCancelled == false else {
              Log.debug(.`generic`, "Cancelled progress images")
              return
            }
            
            if let lastCandidate, lastCandidate.index > candidate.index {
              continuation.finish()
              return
            }
            
            lastCandidate = idealCandidate
            
            let yieldResult = continuation.yield(.progress(result.image, .remote(result.metrics)))
            
            Log.debug(.`generic`, "Loaded progress image => \(candidate.index), \(yieldResult)")
          } catch {
            
          }
        }
        
      }
      
      progressImagesTask = progressImages
      
    }
  }
}
