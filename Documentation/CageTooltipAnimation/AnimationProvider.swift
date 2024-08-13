//
//  AnimationProvider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/21/24.
//

import HDL
import MolecularRenderer
import Numerics

struct AnimationProvider: MRAtomProvider {
  var background: GoldBackground
  var scenes: [FIREScene] = []
  var electronicStructureCount: Int
  
  // The starting frames for each segment of the animation.
  var startTitleFrameID: Int
  var fadeInFrameID: Int
  var animateFrameID: Int
  var fadeOutFrameID: Int
  var endTitle1FrameID: Int
  var endTitle2FrameID: Int
  var totalFrameCount: Int
  
  // Each frame where the tripods are animated.
  // - lane 0: scene ID
  // - lane 1: frame within the scene
  var tripodFrames: [SIMD2<Int>] = []
  
  init() {
    background = GoldBackground()
    
    // Specify the tooltips to render.
    let frameworkTypes: [CageFrameworkType] = [
      .adamantane(.carbon),
      .adamantane(.silicon),
      .adamantane(.germanium),
      .atrane(.tin)
    ]
    let feedstockTypes = CageFeedstockType.allCases
    
    // Initialize all of the tooltips.
    for frameworkType in frameworkTypes {
      for feedstockType in feedstockTypes {
        var sceneDesc = FIRESceneDescriptor()
        sceneDesc.cacheFolder =
        "/Users/philipturner/Documents/OpenMM/cache/CageTooltip"
        sceneDesc.feedstockType = feedstockType
        sceneDesc.frameworkType = frameworkType
        
        let scene = FIREScene(descriptor: sceneDesc)
        scenes.append(scene)
      }
    }
    
    // Count the number of frames.
    var animationFrameCount: Int = .zero
    electronicStructureCount = .zero
    for scene in scenes {
      animationFrameCount += (scene.frames.count + 1) / 2
      electronicStructureCount += min(500, scene.frames.count)
    }
    
    // Distribute the left-over time among the different scenes.
    var leftOverFrameCount = 138 * 60
    leftOverFrameCount -= 5 * 60 // start title
    leftOverFrameCount -= 1 * 60 // fade in
    leftOverFrameCount -= 1 * 60 // fade out
    leftOverFrameCount -= 5 * 60 // end title (1)
    leftOverFrameCount -= 5 * 60 // end title (2)
    leftOverFrameCount -= animationFrameCount
    
    startTitleFrameID = 0
    fadeInFrameID = startTitleFrameID + 5 * 60
    animateFrameID = fadeInFrameID + 1 * 60
    fadeOutFrameID = animateFrameID + animationFrameCount + leftOverFrameCount
    endTitle1FrameID = fadeOutFrameID + 1 * 60
    endTitle2FrameID = endTitle1FrameID + 5 * 60
    totalFrameCount = endTitle2FrameID + 5 * 60
    guard totalFrameCount == 138 * 60 else {
      fatalError("The scene durations do not add up.")
    }
    
    // Iterate over the tripods.
    for tripodID in scenes.indices {
      let leftOverFrameStart = tripodID * leftOverFrameCount / scenes.count
      let leftOverFrameEnd = (tripodID + 1) * leftOverFrameCount / scenes.count
      let leftOverFrameMiddle = (leftOverFrameStart + leftOverFrameEnd) / 2
      
      // Add the padding between simulations.
      for _ in leftOverFrameStart..<leftOverFrameMiddle {
        tripodFrames.append(SIMD2(tripodID, 0))
      }
      
      // Skip every other frame in the animation.
      let scene = scenes[tripodID]
      let renderedFrameCount = (scene.frames.count + 1) / 2
      for renderedFrameID in 0..<renderedFrameCount {
        let projectedFrameID = 2 * renderedFrameID
        guard scene.frames.count > projectedFrameID else {
          fatalError("Projected frame was out of bounds.")
        }
        tripodFrames.append(SIMD2(tripodID, projectedFrameID))
        
      }
      
      // Add the padding between simulations.
      for _ in leftOverFrameMiddle..<leftOverFrameEnd {
        let lastFrameID = scene.frames.count - 1
        tripodFrames.append(SIMD2(tripodID, lastFrameID))
      }
    }
    
    // Check that the number of tripod frames matches the expected value.
    do {
      let expectedCount = animationFrameCount + leftOverFrameCount
      guard tripodFrames.count == expectedCount else {
        fatalError("Unexpected number of tripod frames.")
      }
    }
    
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    // Add the gold background.
    var output: [Entity] = []
    output += background.surface
    output += background.tooltip.apex
    output += background.tooltip.surface
    output += background.tooltip.anchors
    
    // Query the current frame ID.
    let frameID = time.absolute.frames
    
    // Add the tripod.
    var tripodFrame: SIMD2<Int>
    if frameID < animateFrameID {
      tripodFrame = tripodFrames.first!
    } else if frameID < fadeOutFrameID {
      tripodFrame = tripodFrames[frameID - animateFrameID]
    } else if frameID < totalFrameCount {
      tripodFrame = tripodFrames.last!
    } else {
      fatalError("This should never happen.")
    }
    let scene = scenes[tripodFrame[0]]
    let frame = scene.frames[tripodFrame[1]]
    output += frame
    
    // Emulate the camera rotating counterclockwise.
    do {
      // One revolution every 20 seconds.
      let angle = (Float(frameID) / (20 * 60)) * 2 * .pi
      let rotation = Quaternion<Float>(angle: -angle, axis: [0, 1, 0])
      for atomID in output.indices {
        var atom = output[atomID]
        var position = atom.position
        position = rotation.act(on: position)
        
        atom.position = position
        output[atomID] = atom
      }
    }
    
    // Convert from 'Entity' to 'MRAtom'.
    return output.map {
      MRAtom(origin: $0.position, element: $0.atomicNumber)
    }
  }
}

// MARK: - Captions

extension AnimationProvider {
  // start title:
  // "energy minimization"
  // "of DMS tooltips"
  //
  // end titles:
  // 1) "XX tooltips"
  // 2) "YY electronic"
  //    "structures solved"
  func captions(time: MRTime) -> CaptionsDescriptor {
    let frameID = time.absolute.frames
    
    // Create a descriptor based on the relative ID since the start of the
    // section.
    if frameID < fadeInFrameID {
      let relativeID = frameID - startTitleFrameID
      return startingTitle(relativeID: relativeID)
      
    } else if frameID < animateFrameID {
      let relativeID = frameID - fadeInFrameID
      return fadeIn(relativeID: relativeID)
      
    } else if frameID < fadeOutFrameID {
      let relativeID = frameID - animateFrameID
      return animate(relativeID: relativeID)
      
    } else if frameID < endTitle1FrameID {
      let relativeID = frameID - fadeOutFrameID
      return fadeOut(relativeID: relativeID)
      
    } else if frameID < endTitle2FrameID {
      let relativeID = frameID - endTitle1FrameID
      return endTitle1(relativeID: relativeID)
      
    } else if frameID < totalFrameCount {
      let relativeID = frameID - endTitle2FrameID
      return endTitle2(relativeID: relativeID)
      
    } else {
      fatalError("This should never happen.")
    }
  }
  
  func startingTitle(relativeID: Int) -> CaptionsDescriptor {
    var opacity: Float
    if relativeID < 60 {
      opacity = Float(relativeID) / 60
    } else if relativeID < 240 {
      opacity = 1.00
    } else if relativeID < 300 {
      opacity = Float(299 - relativeID) / 60
    } else {
      fatalError("This should never happen.")
    }
    
    var captionsDesc = CaptionsDescriptor()
    captionsDesc.title = (
      ["energy minimization", "of DMS tooltips"], opacity)
    return captionsDesc
  }
  
  func fadeIn(relativeID: Int) -> CaptionsDescriptor {
    let scene = scenes.first!
    let opacity = Float(relativeID) / 60
    
    var captionsDesc = CaptionsDescriptor()
    captionsDesc.structure = (scene.structureCaption, opacity)
    captionsDesc.simulation = (scene.simulationCaption, opacity)
    return captionsDesc
  }
  
  func animate(relativeID: Int) -> CaptionsDescriptor {
    let tripodFrame = tripodFrames[relativeID]
    let scene = scenes[tripodFrame[0]]
    
    var captionsDesc = CaptionsDescriptor()
    captionsDesc.structure = (scene.structureCaption, 1.00)
    captionsDesc.simulation = (scene.simulationCaption, 1.00)
    return captionsDesc
  }
  
  func fadeOut(relativeID: Int) -> CaptionsDescriptor {
    let scene = scenes.last!
    let opacity = Float(59 - relativeID) / 60
    
    var captionsDesc = CaptionsDescriptor()
    captionsDesc.structure = (scene.structureCaption, opacity)
    captionsDesc.simulation = (scene.simulationCaption, opacity)
    return captionsDesc
  }
  
  func endTitle1(relativeID: Int) -> CaptionsDescriptor {
    var opacity: Float
    if relativeID < 60 {
      opacity = Float(relativeID) / 60
    } else if relativeID < 240 {
      opacity = 1.00
    } else if relativeID < 300 {
      opacity = Float(299 - relativeID) / 60
    } else {
      fatalError("This should never happen.")
    }
    
    var captionsDesc = CaptionsDescriptor()
    captionsDesc.title = (
      ["\(scenes.count) tooltips"], opacity)
    return captionsDesc
  }
  
  func endTitle2(relativeID: Int) -> CaptionsDescriptor {
    var opacity: Float
    if relativeID < 60 {
      opacity = Float(relativeID) / 60
    } else if relativeID < 240 {
      opacity = 1.00
    } else if relativeID < 300 {
      opacity = Float(299 - relativeID) / 60
    } else {
      fatalError("This should never happen.")
    }
    
    // Format a representation for the number of electronic structures.
    var repr = ""
    repr += "\(electronicStructureCount / 1000),"
    repr += "\(electronicStructureCount % 1000)"
    
    var captionsDesc = CaptionsDescriptor()
    captionsDesc.title = (
      ["\(repr) electronic", "structures solved"], opacity)
    return captionsDesc
  }
}
