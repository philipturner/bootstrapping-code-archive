//
//  BuildSequenceReaction.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/30/24.
//

import Foundation
import HDL

struct BuildSequenceReactionDescriptor {
  var fileName: String?
  var number: Int?
  var typeLabel: String?
}

struct BuildSequenceReaction {
  // Don't render the thiol legs. They're absent from the animation, and
  // inconsistent with the Si(111) surface.
  var chargedTooltip: CageTooltip
  var spentTooltip: CageTooltip
  var productType: Silicon111ReactionProduct
  
  var reactionFrames: [[Entity]]
  var minimizationFrames: [[Entity]]
  var startingSurface: [Entity]
  var startingAnchors: [Entity]
  
  var nearOffset: SIMD3<Float>
  var farOffset: SIMD3<Float>
  var timeStepCount: Int
  
  init(descriptor: BuildSequenceReactionDescriptor) {
    guard let fileName = descriptor.fileName,
          let number = descriptor.number,
          let typeLabel = descriptor.typeLabel else {
      fatalError("Descriptor was incomplete.")
    }
    productType = Self.createProductType(typeLabel: typeLabel)
    
    var surface: [Entity]
    do {
      let cacheFolder =
      "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
      let folder = URL(filePath: cacheFolder)
      let file = folder.appending(
        component: fileName, directoryHint: .notDirectory)
      
      let data = try! Data(contentsOf: file)
      let frames = Serialization.decode(frames: data)
      reactionFrames = Array(frames[0..<frames.count - 1])
      surface = frames.last!
      
      // Delete the last frame. It's not part of the animation.
      reactionFrames.removeLast()
    }
    
    var siliconTooltip = Silicon111Tooltip(type: .modelS)
    siliconTooltip.surface = surface
    do {
      let cacheFolder =
      "/Users/philipturner/Documents/OpenMM/cache/Silicon111Tooltip"
      let folder = URL(filePath: cacheFolder)
      let key = siliconTooltip.createKey()
      let file = folder.appending(
        component: "\(key).data", directoryHint: .notDirectory)
      
      let data = try! Data(contentsOf: file)
      minimizationFrames = Serialization.decode(frames: data)
    }
    
    // Determine the charged and spent tooltips.
    chargedTooltip = BuildSequenceReaction
      .createChargedTooltip(number: number, productType: productType)
    spentTooltip = BuildSequenceReaction
      .createSpentTooltip(number: number, productType: productType)
    
    // Extract the Silicon111Tooltip components from the first frame.
    do {
      var chargedTooltipAtoms: [Entity] = []
      chargedTooltipAtoms += chargedTooltip.feedstock
      chargedTooltipAtoms += chargedTooltip.apex
      chargedTooltipAtoms += chargedTooltip.framework
      chargedTooltipAtoms += CageTooltip.createLinkAtoms(
        inner: chargedTooltip.framework,
        outer: chargedTooltip.legs,
        boundary: chargedTooltip.frameworkLegsBoundary)
      let tripodAtomCount = chargedTooltipAtoms.count
      
      let startingFrame = reactionFrames[0]
      let probeAtomCount = startingFrame.count - tripodAtomCount
      let surfaceAtomCount = startingFrame.count - tripodAtomCount - 463
      startingSurface = Array(startingFrame[0..<surfaceAtomCount])
      startingAnchors = Array(startingFrame[surfaceAtomCount..<probeAtomCount])
    }
    
    // Reconstruct the parameters that defined the probe's motion during
    // the reaction.
    do {
      let startingFrame = reactionFrames[0]
      let middleFrame = reactionFrames[reactionFrames.count / 2]
      
      let probeAtomCount = startingSurface.count + startingAnchors.count
      farOffset = Self.findOffset(
        reactionFrame: startingFrame, probeAtomCount: probeAtomCount)
      nearOffset = Self.findOffset(
        reactionFrame: middleFrame, probeAtomCount: probeAtomCount)
      timeStepCount = reactionFrames.count
    }
    
    // Undo the offset applied to the probe.
    for atomID in startingAnchors.indices {
      startingAnchors[atomID].position -= farOffset
    }
    for atomID in startingSurface.indices {
      startingSurface[atomID].position -= farOffset
    }
  }
  
  // Reconstruct the action used to serialize the product.
  static func createProductType(
    typeLabel: String
  ) -> Silicon111ReactionProduct {
    switch typeLabel {
    case "CH2":
      return .donation([.carbon, .hydrogen, .hydrogen])
    case "GeH:":
      return .donation([.germanium, .hydrogen])
    case "HAbst":
      return .abstraction([.hydrogen])
    case "HDon":
      return .donation([.hydrogen])
    case "Rearr.":
      return .rearrangement
    case "SiH3":
      return .donation([.silicon, .hydrogen, .hydrogen, .hydrogen])
    case "SiH3Abst":
      return .abstraction([.silicon, .hydrogen, .hydrogen, .hydrogen])
    case "SiH:":
      return .donation([.silicon, .hydrogen])
    default:
      fatalError("Unrecognized type label: \(typeLabel)")
    }
  }
  
  // The tooltip before the reaction starts.
  static func createChargedTooltipDescriptor(
    number: Int,
    productType: Silicon111ReactionProduct
  ) -> CageTooltipDescriptor {
    var tooltipDesc = CageTooltipDescriptor()
    switch productType {
      // CH2
    case .donation([.carbon, .hydrogen, .hydrogen]):
      tooltipDesc.feedstockType = .methylene
      tooltipDesc.frameworkType = .atrane(.tin)
      
      // GeH:
    case .donation([.germanium, .hydrogen]):
      tooltipDesc.feedstockType = .germene
      tooltipDesc.frameworkType = .atrane(.tin)
      
      // HAbst
    case .abstraction([.hydrogen]):
      switch number {
      case 1, 3, 5, 7:
        tooltipDesc.feedstockType = .acetylene
      case 9, 10, 14, 16:
        tooltipDesc.feedstockType = .acetylene
      case 17, 20, 22:
        tooltipDesc.feedstockType = .radical
      case 23, 25:
        tooltipDesc.feedstockType = .acetylene
      case 26, 27:
        tooltipDesc.feedstockType = .radical
      case 29:
        tooltipDesc.feedstockType = .acetylene
      case 32, 34, 35:
        tooltipDesc.feedstockType = .radical
      case 36:
        tooltipDesc.feedstockType = .acetylene
      case 39, 41:
        tooltipDesc.feedstockType = .radical
      case 43, 44, 47:
        tooltipDesc.feedstockType = .acetylene
      default:
        fatalError("Unrecognized reaction number: \(number)")
      }
      tooltipDesc.frameworkType = .adamantane(.carbon)
      
      // HDon
    case .donation([.hydrogen]):
      tooltipDesc.feedstockType = .hydrogen
      tooltipDesc.frameworkType = .atrane(.tin)
      
      // Rearr.
    case .rearrangement:
      tooltipDesc.feedstockType = .methane
      tooltipDesc.frameworkType = .adamantane(.carbon)
      
      // SiH3
    case .donation([.silicon, .hydrogen, .hydrogen, .hydrogen]):
      tooltipDesc.feedstockType = .silane
      tooltipDesc.frameworkType = .atrane(.tin)
      
      // SiH3Abst
    case .abstraction([.silicon, .hydrogen, .hydrogen, .hydrogen]):
      tooltipDesc.feedstockType = .radical
      tooltipDesc.frameworkType = .adamantane(.carbon)
      
      // SiH:
    case .donation([.silicon, .hydrogen]):
      tooltipDesc.feedstockType = .silene
      tooltipDesc.frameworkType = .atrane(.tin)
      
    default:
      fatalError("Unrecognized product type.")
    }
    
    return tooltipDesc
  }
  static func createChargedTooltip(
    number: Int,
    productType: Silicon111ReactionProduct
  ) -> CageTooltip {
    let tooltipDesc = Self.createChargedTooltipDescriptor(
      number: number, productType: productType)
    
    var output = CageTooltip(descriptor: tooltipDesc)
    try! output.loadCachedValue()
    return output
  }
  
  // The tooltip after the reaction finishes.
  static func createSpentTooltip(
    number: Int,
    productType: Silicon111ReactionProduct
  ) -> CageTooltip {
    var tooltipDesc = CageTooltipDescriptor()
    switch productType {
      // CH2
    case .donation([.carbon, .hydrogen, .hydrogen]):
      tooltipDesc.feedstockType = .radical
      tooltipDesc.frameworkType = .atrane(.tin)
      
      // GeH:
    case .donation([.germanium, .hydrogen]):
      tooltipDesc.feedstockType = .radical
      tooltipDesc.frameworkType = .atrane(.tin)
      
      // HAbst
    case .abstraction([.hydrogen]):
      switch number {
      case 1, 3, 5, 7:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .ethynylAdamantane
      case 9, 10, 14, 16:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .ethynylAdamantane
      case 17, 20, 22:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .adamantane(.carbon)
      case 23, 25:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .ethynylAdamantane
      case 26, 27:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .adamantane(.carbon)
      case 29:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .ethynylAdamantane
      case 32, 34, 35:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .adamantane(.carbon)
      case 36:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .ethynylAdamantane
      case 39, 41:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .adamantane(.carbon)
      case 43, 44, 47:
        tooltipDesc.feedstockType = .hydrogen
        tooltipDesc.frameworkType = .ethynylAdamantane
      default:
        fatalError("Unrecognized reaction number: \(number)")
      }
      
      // HDon
    case .donation([.hydrogen]):
      tooltipDesc.feedstockType = .radical
      tooltipDesc.frameworkType = .atrane(.tin)
      
      // Rearr.
    case .rearrangement:
      tooltipDesc.feedstockType = .methane
      tooltipDesc.frameworkType = .adamantane(.carbon)
      
      // SiH3
    case .donation([.silicon, .hydrogen, .hydrogen, .hydrogen]):
      tooltipDesc.feedstockType = .radical
      tooltipDesc.frameworkType = .atrane(.tin)
      
      // SiH3Abst
    case .abstraction([.silicon, .hydrogen, .hydrogen, .hydrogen]):
      tooltipDesc.feedstockType = .silane
      tooltipDesc.frameworkType = .adamantane(.carbon)
      
      // SiH:
    case .donation([.silicon, .hydrogen]):
      tooltipDesc.feedstockType = .radical
      tooltipDesc.frameworkType = .atrane(.tin)
      
    default:
      fatalError("Unrecognized product type.")
    }
    
    var output = CageTooltip(descriptor: tooltipDesc)
    try! output.loadCachedValue()
    return output
  }
  
  // Reconstruct the offset the probe was programmed to be at.
  static func findOffset(
    reactionFrame: [Entity], probeAtomCount: Int
  ) -> SIMD3<Float> {
    let frameAtom = reactionFrame[probeAtomCount - 1]
    let referenceAtom = Entity(
      position: SIMD3(-1.2226561, -0.034179658, 0.7041016),
      type: .atom(.hydrogen))
    guard frameAtom.atomicNumber == referenceAtom.atomicNumber else {
      fatalError("Atoms did not match: \(frameAtom) \(referenceAtom)")
    }
    
    // Round to the nearest multiple of 0.001
    var offset = frameAtom.position - referenceAtom.position
    offset *= 1000
    offset.round(.toNearestOrEven)
    offset /= 1000
    return offset
  }
}
