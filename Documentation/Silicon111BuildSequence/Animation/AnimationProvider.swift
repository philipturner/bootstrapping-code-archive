//
//  AnimationProvider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/1/24.
//

import HDL
import MolecularRenderer

// Breakdown of the time:
// - 2:09 - fade in the end of the last phrase
// - 2:17 - start of music
// - 3:30 - start of ending section
// - 3:52 - last sound plays
// - 3:59 - video ends
//
// 8 seconds for build sequence title
// - 2:09-2:17 music fading in
// - 0:00-0:02 atoms randomly drop in
// - captions:
//   - 0:00-0:05 title
//   - 0:01-0:06 subtitle line 1
//   - 0:02-0:07 subtitle line 2
//   - 0:07-0:08 captions for first reaction fade in
//
// 73 seconds for build sequence scene
// - 2:17-3:30
// - allocate appropriate time for transitions
//
// 2 seconds of being still
// - music stops
// 5 seconds for summary title
// - atoms randomly drop in/out to transition between scenes
//
// 22 seconds for summary scene
// - 3:30-3:52
//
// 10 seconds of being still
// - 0:00:00-0:07:30 camera pans around product
// - 0:07:30-0:10:00 still; fade out effect in Shotcut
class AnimationProvider: MRAtomProvider {
  var buildSequence: BuildSequence
  var surfaceScene: SurfaceScene
  
  var sceneStartingTimes: [Double]
  var sceneEndingTimes: [Double]
  
  var introPassivationAppearingTimes: [Float]
  var introPassivation: [Entity]
  var introProbeSilicons: [Entity]
  var introTripodAppearingTimes: [Float]
  
  var minimizationSurface: [Entity]
  var minimizationFrames: [[Entity]]
  var minimizationFrameReactionIDs: [Int]
  
  var reactionSceneTimeRanges: [Range<Double>]
  var reactionSceneTypes: [ReactionSceneType]
  
  var middlePassivationDisappearingTimes: [Float]
  var middlePassivation: [Entity]
  var middleProbeSilicons: [Entity]
  var middleTripodDisappearingTimes: [Float]
  
  init() {
    buildSequence = BuildSequence()
    surfaceScene = SurfaceScene(buildSequence: buildSequence)
    
    // Initialize the introduction scene's atoms.
    do {
      let reaction = buildSequence.reactions[0]
      var probeAtoms = reaction.startingAnchors + reaction.startingSurface
      let origin = SurfaceScene.origin(reactionID: 0)
      for atomID in probeAtoms.indices {
        probeAtoms[atomID].position += origin
        probeAtoms[atomID].position += reaction.farOffset
      }
      
      introPassivation = surfaceScene.surfacePassivation
      introProbeSilicons = []
      
      for atom in probeAtoms {
        if atom.atomicNumber == 14 {
          introProbeSilicons.append(atom)
        } else {
          introPassivation.append(atom)
        }
      }
    }
    
    // Initialize the middle scene's atoms.
    do {
      let reaction = buildSequence.reactions[47]
      var probeAtoms = reaction.startingAnchors
      probeAtoms += reaction.minimizationFrames.last!
      let origin = SurfaceScene.origin(reactionID: 47)
      for atomID in probeAtoms.indices {
        probeAtoms[atomID].position += origin
        probeAtoms[atomID].position += reaction.farOffset
      }
      
      middlePassivation = surfaceScene.surfacePassivation
      middleProbeSilicons = []
      
      for atom in probeAtoms {
        if atom.atomicNumber == 6 ||
            atom.atomicNumber == 14 ||
            atom.atomicNumber == 32 {
          middleProbeSilicons.append(atom)
        } else {
          middlePassivation.append(atom)
        }
      }
    }
    
    // Choose the time when each atom will appear.
    do {
      introPassivationAppearingTimes = []
      for _ in introPassivation.indices {
        let t = Float.random(in: 0..<5)
        introPassivationAppearingTimes.append(t)
      }
      
      introTripodAppearingTimes = []
      for _ in 0..<48 {
        let t = Float.random(in: 0..<5)
        introTripodAppearingTimes.append(t)
      }
    }
    
    // Choose the time when each atom will disappear.
    do {
      middlePassivationDisappearingTimes = []
      for _ in middlePassivation.indices {
        let t = Float.random(in: 0..<5)
        middlePassivationDisappearingTimes.append(t)
      }
      
      middleTripodDisappearingTimes = []
      for _ in 0..<48 {
        let t = Float.random(in: 0..<5)
        middleTripodDisappearingTimes.append(t)
      }
    }
    
    // Linearize the minimization frames into an array.
    minimizationFrames = []
    minimizationFrameReactionIDs = []
    for (reactionID, reaction) in buildSequence.reactions.enumerated() {
      for minimizationFrame in reaction.minimizationFrames {
        var newFrame: [Entity] = []
        for atomID in minimizationFrame.indices {
          var atom = minimizationFrame[atomID]
          atom.position.y = -atom.position.y
          atom.position.y += -0.8
          newFrame.append(atom)
        }
        minimizationFrames.append(newFrame)
        minimizationFrameReactionIDs.append(reactionID)
      }
    }
    
    // Make a surface, sans the atoms that overlap with the product.
    do {
      var topology = Topology()
      topology.insert(atoms: minimizationFrames[0])
      let matches = topology.match(
        surfaceScene.cleanSiliconSlab, algorithm: .absoluteRadius(0.050))
      
      minimizationSurface = []
      for atomID in surfaceScene.cleanSiliconSlab.indices {
        let atom = surfaceScene.cleanSiliconSlab[atomID]
        let matchList = matches[atomID]
        if matchList.count == .zero {
          minimizationSurface.append(atom)
        }
      }
    }
    
    // Specify the timespan of each scene.
    let sceneDurations: [Double] = [
      8,  // 0 - build sequence title
      73, // 1 - build sequence scene
      2,  // 2 - being still
      5,  // 3 - summary title
      22, // 4 - summary scene
      10,  // 5 - being still
    ]
    do {
      sceneStartingTimes = []
      sceneEndingTimes = []
      
      var totalTime: Double = .zero
      for sceneID in sceneDurations.indices {
        let duration = sceneDurations[sceneID]
        sceneStartingTimes.append(totalTime)
        
        totalTime += duration
        sceneEndingTimes.append(totalTime)
      }
    }
    
    // Divide the time among reaction scenes.
    do {
      // Special transitions can have more time allocated for them.
      var transitionDurations = [Double](repeating: 0.25, count: 48)
      transitionDurations[7] = 0.75
      transitionDurations[15] = 0.75
      transitionDurations[23] = 0.75
      transitionDurations[31] = 0.75
      transitionDurations[39] = 0.75
      transitionDurations[43] = 0.75 // HAbst (causes a rearrangement)
      transitionDurations[44] = 0.75 // GeH:
      transitionDurations[47] = 2.00
      let transitionTotalTime = transitionDurations.reduce(0, +)
      let reactionTotalTime = 75 - transitionTotalTime
      
      var reactionDurations: [Double] = []
      for reaction in buildSequence.reactions {
        let frameCount = reaction.timeStepCount
        guard frameCount == reaction.reactionFrames.count else {
          fatalError("Unexpected behavior.")
        }
        reactionDurations.append(Double(frameCount))
      }
      reactionDurations[10] = 1200 // SiH:
      reactionDurations[44] = 1200 // GeH:
      reactionDurations[47] = 540 // Rearr.
      do {
        let currentSum = reactionDurations.reduce(0, +)
        let normalizationFactor = reactionTotalTime / currentSum
        for reactionID in 0..<48 {
          reactionDurations[reactionID] *= normalizationFactor
        }
      }
      
      // Interleave the reaction and transition scenes.
      reactionSceneTimeRanges = []
      reactionSceneTypes = []
      var timeCursor: Double = .zero
      for reactionID in 0..<48 {
        do {
          let duration = reactionDurations[reactionID]
          let nextTimeCursor = timeCursor + duration
          let timeRange = timeCursor..<nextTimeCursor
          timeCursor = nextTimeCursor
          
          reactionSceneTimeRanges.append(timeRange)
          reactionSceneTypes.append(
            .reaction(reactionID))
        }
       do {
          let duration = transitionDurations[reactionID]
          let nextTimeCursor = timeCursor + duration
          let timeRange = timeCursor..<nextTimeCursor
          timeCursor = nextTimeCursor
          
          reactionSceneTimeRanges.append(timeRange)
          reactionSceneTypes.append(
            .transition(reactionID, reactionID + 1))
        }
      }
    }
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    var output: [Entity]
    
    // Switch on the scene ID.
    let timestamp = getTimestamp(time: time.absolute.seconds)
    switch timestamp.sceneID {
      // Build sequence title
    case 0:
      output = surfaceScene.cleanSiliconSlab
      output += introProbeSilicons
      
      let absoluteTime = timestamp.absoluteTime - 2
      
      for atomID in introPassivation.indices {
        let atom = introPassivation[atomID]
        let appearingTime = introPassivationAppearingTimes[atomID]
        if absoluteTime >= Double(appearingTime) {
          output.append(atom)
        }
      }
      
      for tripodID in 0..<48 {
        let tripod = surfaceScene.chargedTooltipAtoms[tripodID]
        let appearingTime = introTripodAppearingTimes[tripodID]
        if absoluteTime >= Double(appearingTime) {
          output += tripod
        }
      }
      
      // Build sequence scene
    case 1:
      output = surfaceScene.cleanSiliconSlab
      output += surfaceScene.surfacePassivation
      output += renderReactionScene(timestamp: timestamp)
      
      // Being still
    case 2:
      output = surfaceScene.cleanSiliconSlab
      output += surfaceScene.surfacePassivation
      
      var modifiedTimestamp = timestamp
      modifiedTimestamp.sceneID = 1
      modifiedTimestamp.absoluteTime += 73
      modifiedTimestamp.progress = 1
      output += renderReactionScene(timestamp: modifiedTimestamp)
      
      // Summary title
    case 3:
      var absoluteTime: Double
      if timestamp.sceneID == 2 {
        absoluteTime = -1
      } else {
        absoluteTime = timestamp.absoluteTime
      }
      
      // Add the silicon surface, and the first frame of the next scene.
      output = minimizationSurface
      do {
        var surface = buildSequence.reactions[0].startingSurface
        for atomID in surface.indices {
          var atom = surface[atomID]
          atom.position.y = -atom.position.y
          atom.position.y += -0.8
          surface[atomID] = atom
        }
        output += surface
      }
      
      // The passivation should fade away. The probe's silicons will
      // suddenly disappear at the end, but they're out of view.
      output += middleProbeSilicons
      
      for atomID in middlePassivation.indices {
        let atom = middlePassivation[atomID]
        let disappearingTime = middlePassivationDisappearingTimes[atomID]
        if absoluteTime < Double(disappearingTime) {
          output.append(atom)
        }
      }
      
      for tripodID in 0..<48 {
        let tripod = surfaceScene.spentTooltipAtoms[tripodID]
        let disappearingTime = middleTripodDisappearingTimes[tripodID]
        if absoluteTime < Double(disappearingTime) {
          output += tripod
        }
      }
      
      // Summary scene + rotating around
    case 4, 5:
      output = minimizationSurface
      
      if timestamp.sceneID == 4 {
        var frameIDFloat = timestamp.progress
        frameIDFloat *= Double(minimizationFrames.count)
        
        var frameIDInt = Int(frameIDFloat)
        frameIDInt = max(0, min(minimizationFrames.count - 1, frameIDInt))
        output += minimizationFrames[frameIDInt]
      } else {
        output += minimizationFrames.last!
      }
      
    default:
      fatalError("Unexpected scene ID.")
    }
    
    return output.map(MRAtom.init)
  }
}

// MARK: - Timestamp

extension AnimationProvider {
  
  struct Timestamp {
    var sceneID: Int
    var absoluteTime: Double // in seconds since start
    var progress: Double // 0..<1
  }
  
  // Accepts the time in seconds.
  func getTimestamp(time: Double) -> Timestamp {
    var chosenSceneID: Int?
    for sceneID in 0..<6 {
      guard time >= sceneStartingTimes[sceneID],
            time < sceneEndingTimes[sceneID] else {
        continue
      }
      chosenSceneID = sceneID
    }
    if chosenSceneID == nil {
      if time <= 0.5 {
        chosenSceneID = 0
      } else {
        chosenSceneID = 5
      }
    }
    
    guard let chosenSceneID else {
      fatalError("Could not find scene ID.")
    }
    let start = sceneStartingTimes[chosenSceneID]
    let end = sceneEndingTimes[chosenSceneID]
    
    let absoluteTime = time - start
    let progress = (time - start) / (end - start)
    return Timestamp(
      sceneID: chosenSceneID,
      absoluteTime: absoluteTime,
      progress: progress)
  }
}

// MARK: - Reaction Scene

extension AnimationProvider {
  enum ReactionSceneType {
    // Present just one reaction.
    case reaction(Int)
    
    // Interpolate between the scenes by replaying the energy minimization,
    // shifting the camera between two translations and/or rotations.
    case transition(Int, Int)
  }
  
  func renderReactionScene(timestamp: Timestamp) -> [Entity] {
    var chosenSceneID: Int?
    for sceneID in reactionSceneTimeRanges.indices {
      let timeRange = reactionSceneTimeRanges[sceneID]
      guard timestamp.absoluteTime >= timeRange.lowerBound,
            timestamp.absoluteTime < timeRange.upperBound else {
        continue
      }
      chosenSceneID = sceneID
    }
    guard let chosenSceneID else {
      fatalError(
        "Time \(timestamp.absoluteTime) was outside the bounds 0 <= t < 75.")
    }
    
    // Retrieve the type of scene.
    let timeRange = reactionSceneTimeRanges[chosenSceneID]
    let sceneType = reactionSceneTypes[chosenSceneID]
    var progress = (timestamp.absoluteTime - timeRange.lowerBound)
    progress /= (timeRange.upperBound - timeRange.lowerBound)
    
    // Switch over the type of scene.
    var output: [Entity] = []
    switch sceneType {
    case .reaction(let reactionID):
      // Show the charged and spent tripods from the other reactions.
      let reaction = buildSequence.reactions[reactionID]
      for tripodID in 0..<reactionID {
        let tripodAtoms = surfaceScene.spentTooltipAtoms[tripodID]
        output += tripodAtoms
      }
      for tripodID in (reactionID + 1)..<48 {
        let tripodAtoms = surfaceScene.chargedTooltipAtoms[tripodID]
        output += tripodAtoms
      }
      
      // Show a specific frame of the animation.
      let frameCount = reaction.reactionFrames.count
      let frameIDFloat = progress * Double(frameCount)
      var frameID = Int(frameIDFloat)
      frameID = max(0, min(frameCount - 1, frameID))
      
      let reactionFrame = reaction.reactionFrames[frameID]
      let offset = SurfaceScene.origin(reactionID: reactionID)
      for atomID in reactionFrame.indices {
        var atom = reactionFrame[atomID]
        atom.position += offset
        output.append(atom)
      }
      
    case .transition(let startID, var endID):
      // Show the charged and spent tripods from the other reactions.
      for tripodID in 0...startID {
        let tripodAtoms = surfaceScene.spentTooltipAtoms[tripodID]
        output += tripodAtoms
      }
      if endID != 48 {
        for tripodID in endID..<48 {
          let tripodAtoms = surfaceScene.chargedTooltipAtoms[tripodID]
          output += tripodAtoms
        }
      }
      endID = min(endID, 47)
      
      // Retrieve the reaction objects.
      let startReaction = buildSequence.reactions[startID]
      let endReaction = buildSequence.reactions[endID]
      
      // Source the surface atoms from the starting frame.
      let frameCount = startReaction.minimizationFrames.count
      let frameIDDouble = progress * Double(frameCount)
      var frameIDLow = Int(frameIDDouble)
      var frameIDHigh = frameIDLow + 1
      frameIDLow = max(0, min(frameCount - 1, frameIDLow))
      frameIDHigh = max(0, min(frameCount - 1, frameIDHigh))
      
      // Interpolate between the two frames.
      var probe = startReaction.startingAnchors
      do {
        var t = Float(frameIDDouble) - Float(frameIDLow)
        t = max(0, min(1, t))
        
        let frameLow = startReaction.minimizationFrames[frameIDLow]
        let frameHigh = startReaction.minimizationFrames[frameIDHigh]
        guard frameLow.count == frameHigh.count else {
          fatalError("Minimization frames had different sizes.")
        }
        for atomID in frameLow.indices {
          let atomLow = frameLow[atomID]
          let atomHigh = frameHigh[atomID]
          guard atomLow.atomicNumber == atomHigh.atomicNumber else {
            fatalError(
              "Atoms in subsequent frames had different atomic numbers.")
          }
          
          let position = (1 - t) * atomLow.position + t * atomHigh.position
          let element = Element(rawValue: atomLow.atomicNumber)!
          let atom = Entity(position: position, type: .atom(element))
          probe.append(atom)
        }
      }
      
      // Identify the keyframes of the animation, in 3D space.
      //
      // The camera would pay attention to the reaction origin, but not the
      // probe offset.
      var startOffset = SurfaceScene.origin(reactionID: startID)
      var endOffset = SurfaceScene.origin(reactionID: endID)
      startOffset += startReaction.farOffset
      endOffset += endReaction.farOffset
      
      // Interpolate between the keyframes.
      var t = Float(progress)
      t = t * t * (3 - 2 * t)
      let offset = (1 - t) * startOffset + t * endOffset
      for atomID in probe.indices {
        var atom = probe[atomID]
        atom.position += offset
        output.append(atom)
      }
    }
    
    return output
  }
}

