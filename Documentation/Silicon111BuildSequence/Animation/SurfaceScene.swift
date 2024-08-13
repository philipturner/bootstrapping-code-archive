//
//  SurfaceScene.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/1/24.
//

import HDL

// Renders the surface and the tripods that aren't involved in a currently
// playing reaction.
//
// This object knows nothing about the animation's time, or the linearization
// of the reactions into a contiguous string of frames.
struct SurfaceScene {
  var cleanSiliconSlab: [Entity] = []
  var surfacePassivation: [Entity] = []
  var chargedTooltips: [CageTooltip] = []
  var spentTooltips: [CageTooltip] = []
  
  var chargedTooltipAtoms: [[Entity]] = []
  var spentTooltipAtoms: [[Entity]] = []
  
  init(buildSequence: BuildSequence) {
    let surface = Surface()
    
    // Permanently move the surface down by 0.8 nm.
    for var atom in surface.topology.atoms {
      atom.position += SIMD3(0.00, -0.80, 0.00)
      if atom.atomicNumber == 14 {
        cleanSiliconSlab.append(atom)
      } else {
        surfacePassivation.append(atom)
      }
    }
    
    // Collect all of the tripods in the build sequence.
    for reactionID in 0..<48 {
      let reaction = buildSequence.reactions[reactionID]
      chargedTooltips.append(reaction.chargedTooltip)
      spentTooltips.append(reaction.spentTooltip)
    }
    
    // Prepare the charged tooltips.
    for reactionID in 0..<48 {
      let tooltip = chargedTooltips[reactionID]
      let origin = SurfaceScene.origin(reactionID: reactionID)
      
      var tooltipAtoms: [Entity] = []
      tooltipAtoms += tooltip.feedstock
      tooltipAtoms += tooltip.apex
      tooltipAtoms += tooltip.framework
      tooltipAtoms += CageTooltip.createLinkAtoms(
        inner: tooltip.framework,
        outer: tooltip.legs,
        boundary: tooltip.frameworkLegsBoundary)
      
      for atomID in tooltipAtoms.indices {
        var atom = tooltipAtoms[atomID]
        atom.position += origin
        tooltipAtoms[atomID] = atom
      }
      chargedTooltipAtoms.append(tooltipAtoms)
    }
    
    // Prepare the spent tooltips.
    for reactionID in 0..<48 {
      let tooltip = spentTooltips[reactionID]
      let origin = SurfaceScene.origin(reactionID: reactionID)
      
      var tooltipAtoms: [Entity] = []
      tooltipAtoms += tooltip.feedstock
      tooltipAtoms += tooltip.apex
      tooltipAtoms += tooltip.framework
      tooltipAtoms += CageTooltip.createLinkAtoms(
        inner: tooltip.framework,
        outer: tooltip.legs,
        boundary: tooltip.frameworkLegsBoundary)
      
      for atomID in tooltipAtoms.indices {
        var atom = tooltipAtoms[atomID]
        atom.position += origin
        tooltipAtoms[atomID] = atom
      }
      spentTooltipAtoms.append(tooltipAtoms)
    }
  }
  
  // The offset of the origin, in the reaction's coordinate space.
  // - Parameter reactionID: A number between 0 and 47.
  static func origin(reactionID: Int) -> SIMD3<Float> {
    var offsetX = Float(reactionID % 8) - 3.5
    var offsetZ = 2.5 - Float(reactionID / 8)
    
    let latticeConstant = Constant(.hexagon) { .elemental(.silicon) }
    offsetX *= 10 * latticeConstant
    offsetZ *= 6 * (4.10 / 2.52) * latticeConstant
    return SIMD3(offsetX, 0.00, offsetZ)
  }
}
