import Foundation
import MolecularRenderer
import HDL
import MM4
import Numerics
import QuartzCore
import xTB

#if false
// Workspace for building onto the silicon tooltip.
//
func createGeometry() -> [[Entity]] {
  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  siliconTooltip.surface.remove(at: 19)
  
//  do {
//    let cacheFolder =
//    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
//    let folder = URL(filePath: cacheFolder)
//    let fileName = "Reaction 5n (2024-07-28 13_44_43 +0000).data"
//    let file = folder.appending(
//      component: fileName, directoryHint: .notDirectory)
//    
//    let data = try! Data(contentsOf: file)
//    let frames = Serialization.decode(frames: data)
//    siliconTooltip.surface = frames.last!
//  }
//  siliconTooltip.minimizeSurface()
  
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .silylene
  cageTooltipDesc.frameworkType = .atrane(.silicon)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  try! cageTooltip.loadCachedValue()
  
  var reactionDesc = Silicon111ReactionDescriptor()
  reactionDesc.siliconTooltip = siliconTooltip
  reactionDesc.cageTooltip = cageTooltip
  reactionDesc.frameBudget = 4 * 60
  reactionDesc.nearOffset = SIMD3(-0.20, 0.50, 0.00)
  reactionDesc.farOffset = reactionDesc.nearOffset! + SIMD3(0.00, 0.20, 0.00)
  
  var reaction = Silicon111Reaction(descriptor: reactionDesc)
  
  var output: [[Entity]] = []
  output.append(createFrame(reaction: reaction))
  
  
  // Run molecular dynamics.
  do {
    for _ in 0..<reaction.frameBudget {
      try reaction.step()
      output.append(createFrame(reaction: reaction))
    }
    output.append(try reaction.createProduct(
      type: .donation([.hydrogen])
    ))
    
    // Serialize the product, so the next reaction will be initialized with it.
    //
    // Alternatively, save the trajectory in case you lose it.
//    do {
//      let cacheFolder =
//      "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
//      let folder = URL(filePath: cacheFolder)
//      let key = Serialization.fileSafeString("\(Date())")
//      let file = folder.appending(
//        component: "Reaction 6n (\(key)).data", directoryHint: .notDirectory)
//      let data = Serialization.encode(frames: output)
//      try! data.write(to: file, options: .atomic)
//    }
  } catch {
    print("[ERROR]", error.localizedDescription)
  }
  
  return output
}

func createFrame(reaction: Silicon111Reaction) -> [Entity] {
  var output: [Entity] = []
  let siliconTooltip = reaction.createSiliconTooltip()
  output += siliconTooltip.surface
  output += Silicon111Tooltip.createLinkAtoms(
    inner: siliconTooltip.surface,
    outer: siliconTooltip.anchors,
    boundary: siliconTooltip.boundary)
  
  let cageTooltip = reaction.createCageTooltip()
  output += cageTooltip.feedstock
  output += cageTooltip.apex
  output += cageTooltip.framework
  output += CageTooltip.createLinkAtoms(
    inner: cageTooltip.framework,
    outer: cageTooltip.legs,
    boundary: cageTooltip.frameworkLegsBoundary)
  return output
}
#endif

#if false

func replaceApex(tooltip: inout CageTooltip) {
  var carbonID: Int = .zero
  var removedCenterAtoms: [UInt32] = []
  var insertedHydrogens: [Entity] = []
  for atomID in tooltip.apex.indices {
    var atom = tooltip.apex[atomID]
    if atom.position.y < -0.020,
       atom.atomicNumber == 6 || atom.atomicNumber == 14 {
      
      let carbonCount: Int = 2
      if carbonID >= 1 {
        
      } else {
        removedCenterAtoms.append(UInt32(atomID))
        
        let position1 = SIMD3<Float>(0.05, -0.01, 0.10)
        let position2 = atom.position + SIMD3(-0.05, -0.05, 0.00)
        insertedHydrogens += [
          Entity(position: position1, type: .atom(.hydrogen)),
          Entity(position: position2, type: .atom(.hydrogen)),
        ]
      }
      carbonID += 1
    }
    tooltip.apex[atomID] = atom
  }
  for atomID in removedCenterAtoms.reversed() {
    tooltip.apex.remove(at: Int(atomID))
  }
  
  // Ensure the (now corrupted) apex-framework boundary is never accessed.
  tooltip.apexFrameworkBoundary = [SIMD2(99000, 999000)]
  
  // Shrink the list of apex atoms.
  var hydrogenCursor = 0
  var removedHydrogens: [UInt32] = []
  for atomID in tooltip.apex.indices {
    let atom = tooltip.apex[atomID]
    if atom.atomicNumber == 1 {
      if hydrogenCursor < 2 {
        removedHydrogens.append(UInt32(atomID))
      }
      hydrogenCursor += 1
    }
  }
  for atomID in removedHydrogens.reversed() {
    tooltip.apex.remove(at: Int(atomID))
  }
  
  // Insert the passivating hydrogens after everything else is done.
  tooltip.apex += insertedHydrogens
}

// Workspace for measuring energies.
func createGeometry() -> [Entity] {
  struct Framework {
    var type: CageFrameworkType
    var apexPassivators: [Element] = [
      .hydrogen, .hydrogen,
      .hydrogen, .hydrogen,
      .hydrogen, .hydrogen,
    ]
  }
  
  struct Reaction {
    var chargedTooltip: CageFeedstockType
    var dischargedTooltip: CageFeedstockType
    var unboundFeedstock: CageFeedstockType
  }
  
  let frameworks: [Framework] = [
//    Framework(type: .ethynylAdamantane),
    Framework(type: .adamantane(.carbon)),
//    Framework(type: .adamantane(.silicon)),
//    Framework(type: .adamantane(.germanium)),
//    Framework(type: .atrane(.silicon)),
//    Framework(type: .atrane(.germanium)),
//    Framework(type: .atrane(.tin)),
//    Framework(type: .atrane(.lead)),
    Framework(type: .adamantasilane(.carbon)),
//    Framework(type: .adamantasilane(.silicon)),
//    Framework(type: .adamantasilane(.germanium)),
//    Framework(type: .adamantasilane(.tin)),
//    Framework(type: .adamantasilane(.lead)),
  ]
  let frameworkNames: [String] = [
//    "| ethynyl-adamantane ",
    "| adamantane(C)      ",
//    "| adamantane(Si)     ",
//    "| adamantane(Ge)     ",
//    "| atrane(Si)         ",
//    "| atrane(Ge)         ",
//    "| atrane(Sn)         ",
//    "| atrane(Pb)         ",
    "| adamantasilane(C)  ",
//    "| adamantasilane(Si) ",
//    "| adamantasilane(Ge) ",
//    "| adamantasilane(Sn) ",
//    "| adamantasilane(Pb) ",
  ]
  let feedstocks: [Reaction] = [
    Reaction(
      chargedTooltip: .hydrogen,
      dischargedTooltip: .radical,
      unboundFeedstock: .hydrogen),
    Reaction(
      chargedTooltip: .acetylene,
      dischargedTooltip: .radical,
      unboundFeedstock: .acetylene),
    Reaction(
      chargedTooltip: .methylene,
      dischargedTooltip: .radical,
      unboundFeedstock: .methylene),
    Reaction(
      chargedTooltip: .silylene,
      dischargedTooltip: .radical,
      unboundFeedstock: .silylene),
    Reaction(
      chargedTooltip: .silane,
      dischargedTooltip: .radical,
      unboundFeedstock: .silane),
    Reaction(
      chargedTooltip: .germane,
      dischargedTooltip: .radical,
      unboundFeedstock: .germane),
  ]
  
  // Cache the feedstocks once, for all tooltips.
  var unboundFeedstocks: [[Entity]] = []
  for feedstockID in feedstocks.indices {
    let reaction = feedstocks[feedstockID]
    var unboundAtoms = CageTooltip.createFeedstock(
      type: reaction.unboundFeedstock)
    unboundAtoms = minimize(atoms: unboundAtoms)
    unboundFeedstocks.append(unboundAtoms)
  }
  
  // Iterate over all possible tooltip-feedstock combinations.
  var output: [Entity] = []
  print()
  for frameworkID in frameworks.indices {
    print(frameworkNames[frameworkID], terminator: " |")
    for feedstockID in feedstocks.indices {
      let reaction = feedstocks[feedstockID]
      let framework = frameworks[frameworkID]
      
      var cageTooltipDesc = CageTooltipDescriptor()
      cageTooltipDesc.apexPassivators = framework.apexPassivators
      cageTooltipDesc.feedstockType = reaction.dischargedTooltip
      cageTooltipDesc.frameworkType = framework.type
      var dischargedTooltip = CageTooltip(descriptor: cageTooltipDesc)
      replaceApex(tooltip: &dischargedTooltip)
      try! dischargedTooltip.loadCachedValue()
      
      cageTooltipDesc = CageTooltipDescriptor()
      cageTooltipDesc.apexPassivators = framework.apexPassivators
      cageTooltipDesc.feedstockType = reaction.chargedTooltip
      cageTooltipDesc.frameworkType = framework.type
      var chargedTooltip = CageTooltip(descriptor: cageTooltipDesc)
      replaceApex(tooltip: &chargedTooltip)
      try! chargedTooltip.loadCachedValue()
      
      let dischargedTooltipAtoms =
      dischargedTooltip.legs +
      dischargedTooltip.framework +
      dischargedTooltip.apex +
      dischargedTooltip.feedstock
      
      let chargedTooltipAtoms =
      chargedTooltip.legs +
      chargedTooltip.framework +
      chargedTooltip.apex +
      chargedTooltip.feedstock
      
      let unboundFeedstockAtoms = unboundFeedstocks[feedstockID]
      
      func measureEnergy(atoms: [Entity]) -> Double {
        var calculatorDesc = xTB_CalculatorDescriptor()
        calculatorDesc.atomicNumbers = atoms.map(\.atomicNumber)
        calculatorDesc.hamiltonian = .tightBinding
        calculatorDesc.positions = atoms.map(\.position)
        
        xTB_Environment.show()
        let calculator = xTB_Calculator(descriptor: calculatorDesc)
        return calculator.energy
      }
      
      // Measure and report the binding energy.
      var removalEnergy: Double = .zero
      removalEnergy += measureEnergy(atoms: dischargedTooltipAtoms)
      removalEnergy -= measureEnergy(atoms: chargedTooltipAtoms)
      removalEnergy += measureEnergy(atoms: unboundFeedstockAtoms)
      let energyInEV = removalEnergy / 160.218
      let repr = "+\(String(format: "%.2f", energyInEV)) eV"
      print(" " + repr, terminator: " |")
      
      // Display some atoms for structure debugging.
      let reagents: [[Entity]] = [
        chargedTooltipAtoms,
        dischargedTooltipAtoms,
        unboundFeedstockAtoms,
      ]
      for reagentID in reagents.indices {
        var reagentAtoms = reagents[reagentID]
        for atomID in reagentAtoms.indices {
          let offset = SIMD3<Float>(
            1.50 * Float(feedstockID),
            -1.50 * Float(frameworkID),
            1.50 * Float(reagentID))
          reagentAtoms[atomID].position += offset
        }
        output += reagentAtoms
      }
    }
    print()
  }
  
  return output
}
#endif
