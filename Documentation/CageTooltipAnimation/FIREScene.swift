//
//  Workspace+FIREScene.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/21/24.
//

import Foundation
import HDL

// A configuration for a scene.
struct FIRESceneDescriptor {
  // Where to load the trajectory from.
  var cacheFolder: String?
  
  // The feedstock of the tooltip.
  var feedstockType: CageFeedstockType?
  
  // The framework of the tooltip.
  var frameworkType: CageFrameworkType?
}

// A scene of the animation.
struct FIREScene {
  var frames: [[Entity]]
  var simulationCaption: String
  var structureCaption: String
  
  init(descriptor: FIRESceneDescriptor) {
    guard let cacheFolder = descriptor.cacheFolder,
          let feedstockType = descriptor.feedstockType,
          let frameworkType = descriptor.frameworkType else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Set up the tooltip.
    var tooltipDesc = CageTooltipDescriptor()
    tooltipDesc.feedstockType = feedstockType
    tooltipDesc.frameworkType = frameworkType
    let tooltip = CageTooltip(descriptor: tooltipDesc)
    
    // Choose a file name for the trajectory.
    let folder = URL(filePath: cacheFolder)
    let key = tooltip.createKey()
    let file = folder.appending(
      component: "\(key).data", directoryHint: .notDirectory)
    
    // Create the frames in one of two ways.
    do {
      let data = try Data(contentsOf: file)
      frames = Serialization.decode(frames: data)
    } catch {
      frames = tooltip.runMinimization()
      
      let data = Serialization.encode(frames: frames)
      try! data.write(to: file, options: .atomic)
    }
    
    // Choose a caption.
    let tooltipName = "\(tooltipDesc.frameworkType!)"
    let feedstockName = "\(tooltipDesc.feedstockType!)"
    structureCaption = "\(tooltipName) + \(feedstockName)"
    
    let singlepointCount = min(500, frames.count)
    simulationCaption = "\(singlepointCount) FIRE iterations"
  }
}
