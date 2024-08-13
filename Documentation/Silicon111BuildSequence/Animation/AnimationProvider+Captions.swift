//
//  AnimationProvider+Captions.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/2/24.
//

import MolecularRenderer

extension AnimationProvider {
  // Returns the captions for rendering to GIF.
  func captions(time: MRTime) -> CaptionsDescriptor {
    var captionsDesc = CaptionsDescriptor()
    
    // Switch on the scene ID.
    let timestamp = getTimestamp(time: time.absolute.seconds)
    switch timestamp.sceneID {
      // Build sequence title
    case 0:
      let t = Float(timestamp.absoluteTime)
      
      if t >= 0 {
        captionsDesc.title = ("Build Sequence", 0)
        if t < 1 {
          captionsDesc.title!.opacity = t
        } else if t < 4 {
          captionsDesc.title!.opacity = 1
        } else if t < 5 {
          captionsDesc.title!.opacity = 5 - t
        }
      }
      
      if t >= 1 {
        captionsDesc.subtitle1 = ("four adamantasilane cages", 0)
        if t < 2 {
          captionsDesc.subtitle1!.opacity = t - 1
        } else if t < 5 {
          captionsDesc.subtitle1!.opacity = 1
        } else if t < 6 {
          captionsDesc.subtitle1!.opacity = 5 - (t - 1)
        }
      }
      
      if t >= 2 {
        captionsDesc.subtitle2 = ("pyramid with Ge dopant", 0)
        if t < 3 {
          captionsDesc.subtitle2!.opacity = t - 2
        } else if t < 6 {
          captionsDesc.subtitle2!.opacity = 1
        } else if t < 7 {
          captionsDesc.subtitle2!.opacity = 5 - (t - 2)
        }
      }
      
      if t >= 7 {
        if t < 8 {
          captionsDesc.reactionName = ("Reaction 1(a)", t - 7)
          captionsDesc.reactionType = (".abstraction([.hydrogen])", t - 7)
          captionsDesc.tooltip = (".adamantane(.carbon) + .acetylene", t - 7)
        } else {
          captionsDesc.reactionName = ("Reaction 1(a)", 1)
          captionsDesc.reactionType = (".abstraction([.hydrogen])", 1)
          captionsDesc.tooltip = (".adamantane(.carbon) + .acetylene", 1)
        }
      }
      
      // Build sequence scene
    case 1, 2:
      var chosenSceneID: Int?
      if timestamp.sceneID == 1 {
        for sceneID in reactionSceneTimeRanges.indices {
          let timeRange = reactionSceneTimeRanges[sceneID]
          guard timestamp.absoluteTime >= timeRange.lowerBound,
                timestamp.absoluteTime < timeRange.upperBound else {
            continue
          }
          chosenSceneID = sceneID
        }
      } else {
        chosenSceneID = reactionSceneTimeRanges.count - 1
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
      if timestamp.sceneID == 2 {
        progress = timestamp.progress
      }
      
      // Switch over the type of scene.
      var chosenReactionID: Int
      var opacity: Float
      switch sceneType {
      case .reaction(let reactionID):
        chosenReactionID = reactionID
        opacity = 1
      case .transition(let startID, let endID):
        if endID == 48 {
          chosenReactionID = startID
          opacity = 1 - Float(progress)
        } else {
          if progress < 0.50 {
            chosenReactionID = startID
          } else {
            chosenReactionID = endID
          }
          opacity = 1
        }
      }
      
      // Fetch the data to reconstruct the reaction info.
      let reaction = buildSequence.reactions[chosenReactionID]
      let productType = reaction.productType
      let tooltipDesc = BuildSequenceReaction.createChargedTooltipDescriptor(
        number: chosenReactionID + 1,
        productType: productType)
      
      // Define the captions.
      captionsDesc.reactionName = (
        "Reaction \(chosenReactionID + 1)(a)", opacity)
      captionsDesc.reactionType = (
        ".\(productType)", opacity)
      captionsDesc.tooltip = (
        ".\(tooltipDesc.frameworkType!) + .\(tooltipDesc.feedstockType!)",
        opacity)
      
      // Summary title
    case 3:
      let t = Float(timestamp.absoluteTime)
      
      captionsDesc.title = ("Summary", 0)
      if t < 1 {
        captionsDesc.title!.opacity = t
      } else if t < 4 {
        captionsDesc.title!.opacity = 1
      } else if t < 5 {
        captionsDesc.title!.opacity = 5 - t
      }
      
      // Summary scene
    case 4:
      var frameIDFloat = timestamp.progress
      frameIDFloat *= Double(minimizationFrames.count)
      
      // Find the reaction being depicted.
      var frameIDInt = Int(frameIDFloat)
      frameIDInt = max(0, min(minimizationFrames.count - 1, frameIDInt))
      let reactionID = minimizationFrameReactionIDs[frameIDInt]
      
      // Fetch the data to reconstruct the reaction info.
      let reaction = buildSequence.reactions[reactionID]
      let productType = reaction.productType
      
      // Define the captions.
      captionsDesc.reactionName = (
        "Reaction \(reactionID + 1)(a)", 1.00)
      captionsDesc.reactionType = (
        ".\(productType)", 1.00)
      
    default:
      break
    }
    
    return captionsDesc
  }
}
