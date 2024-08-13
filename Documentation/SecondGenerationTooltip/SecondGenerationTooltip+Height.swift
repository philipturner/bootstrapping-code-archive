//
//  SecondGenerationTooltip.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 7/22/24.
//

// Workspace for measuring the height needed for the 2nd generation tooltip.
//
// Approach Y:
//   +1.05 (C radical, H abstraction)
//   +1.15 (Si radical, H abstraction)
//   +1.35 (C-C2, H abstraction)
//   +1.25 (Sn-SiH3, SiH3 donation)
//   +1.30 (Sn-C2, C2 donation)
//
// Clearance Y:
//   +1.50 (Sn-C2, unwanted H abstraction)
//   +1.55 (extra room for up to 50 pm positioning error)
//
// The tooltip layer must reach down to y=1.05, while the flat layer remains
// at y=1.55 or higher. If y=1.55 makes a large impact on atom count, it can
// be decreased to y=1.50 with some precautions. The overall separation
// between lowest and highest atomic layers is ~0.45-0.50 nm.
//
// Separation between layers in silicon: 0.313 nm
// Separation between layers in silicon carbide: 0.252 nm
// Two layers of silicon carbide are sufficient.
//
// If the tripods occupy ~5 nm^2 each, the minimum separation is ~2.24 nm. The
// tooltip needs to span the distance between two tripods, without colliding
// with both at the same time. The tripod that's not being used should fall
// within the clearance of the upper atomic layer.
//
// Hexagonal lattice constant in silicon: 0.384 nm
// Hexagonal lattice constant in silicon carbide: 0.308 nm
// Room allowed with ≥45° slope from upper layer: ≥1.212 nm
//   (2.24 nm) - 2 * sqrt(1) * (0.514) nm = 1.212 nm
// Number of hexagonal cells: ~4.00
//
// This should be well within clearance for a triple-tooltip (if we need that
// many tips). Such a tooltip would occupy two hexagonal cells on the tip
// layer. Perhaps three, accounting for overhead. It should fit within the
// operating range. Next, specify the tip in atomic detail (OneNote).

#if false

func createGeometry() -> [Entity] {
  func processCage(descriptor: CageTooltipDescriptor) -> [Entity] {
    var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
    try! cageTooltip.loadCachedValue()
    
    // Loop over the feedstock and apex (radical tools have no feedstock atoms).
    var highestFeedstockY: Float = -.greatestFiniteMagnitude
    for atom in cageTooltip.feedstock {
      let y = atom.position.y
      highestFeedstockY = max(highestFeedstockY, y)
    }
    for atom in cageTooltip.apex {
      let y = atom.position.y
      highestFeedstockY = max(highestFeedstockY, y)
    }
    
    // Loop over the leg atoms.
    var lowestSulfurY: Float = .greatestFiniteMagnitude
    for atom in cageTooltip.legs {
      if atom.atomicNumber == 16 {
        let y = atom.position.y
        lowestSulfurY = min(lowestSulfurY, y)
      }
    }
    
    print()
    print("highest feedstock Y:", highestFeedstockY)
    print("lowest sulfur Y:", lowestSulfurY)
    print("tool height:", highestFeedstockY - lowestSulfurY)
    
    var cageTooltipAtoms =
    cageTooltip.feedstock + cageTooltip.apex +
    cageTooltip.framework + cageTooltip.legs
    for atomID in cageTooltipAtoms.indices {
      var atom = cageTooltipAtoms[atomID]
      atom.position.y -= lowestSulfurY
      cageTooltipAtoms[atomID] = atom
    }
    
    return cageTooltipAtoms
  }
  
  var cageTooltipDesc = CageTooltipDescriptor()
  var output: [Entity] = []
  
  cageTooltipDesc.feedstockType = .radical
  cageTooltipDesc.frameworkType = .adamantane(.carbon)
  output += processCage(descriptor: cageTooltipDesc).map {
    var copy = $0
    copy.position += SIMD3(-2.00, 0.00, 0.00)
    return copy
  }
  
  cageTooltipDesc.feedstockType = .radical
  cageTooltipDesc.frameworkType = .adamantane(.silicon)
  output += processCage(descriptor: cageTooltipDesc).map {
    var copy = $0
    copy.position += SIMD3(-1.00, 0.00, 0.00)
    return copy
  }
  
  cageTooltipDesc.feedstockType = .acetylene
  cageTooltipDesc.frameworkType = .adamantane(.carbon)
  output += processCage(descriptor: cageTooltipDesc).map {
    var copy = $0
    copy.position += SIMD3(0.00, 0.00, 0.00)
    return copy
  }
  
  cageTooltipDesc.feedstockType = .silane
  cageTooltipDesc.frameworkType = .atrane(.tin)
  output += processCage(descriptor: cageTooltipDesc).map {
    var copy = $0
    copy.position += SIMD3(1.00, 0.00, 0.00)
    return copy
  }
  
  cageTooltipDesc.feedstockType = .acetylene
  cageTooltipDesc.frameworkType = .atrane(.tin)
  output += processCage(descriptor: cageTooltipDesc).map {
    var copy = $0
    copy.position += SIMD3(2.00, 0.00, 0.00)
    return copy
  }
  
  let siliconTooltip = Silicon111Tooltip(type: .modelO)
  let siliconTooltipAtoms =
  siliconTooltip.surface + siliconTooltip.anchors
  output += siliconTooltipAtoms.map {
    var copy = $0
    copy.position += SIMD3(1.20, 1.24, 0.10)
    return copy
  }
  
  print(Constant(.hexagon) { .checkerboard(.silicon, .chlorine) })
  
  return output
}


#endif
