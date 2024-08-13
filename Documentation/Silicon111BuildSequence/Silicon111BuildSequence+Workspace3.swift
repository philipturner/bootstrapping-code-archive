import Foundation
import MolecularRenderer
import HDL
import MM4
import Numerics
import QuartzCore
import xTB

#if false
// Workspace for building onto the silicon tooltip.
func createGeometry() -> [[Entity]] {
  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  siliconTooltip.surface.remove(at: 19)
  siliconTooltip.surface += [
    Entity(position: SIMD3(0.00, -0.18, 0.00), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.10, -0.25, 0.00), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.10, -0.25, 0.00), type: .atom(.hydrogen)),
  ]
  
//  do {
//    let cacheFolder =
//    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
//    let folder = URL(filePath: cacheFolder)
//    let fileName = "Reaction 7l (2024-07-21 23_28_45 +0000).data"
//    let file = folder.appending(
//      component: fileName, directoryHint: .notDirectory)
//
//    let data = try! Data(contentsOf: file)
//    let frames = Serialization.decode(frames: data)
//    siliconTooltip.surface = frames.last!
//  }
  siliconTooltip.minimizeSurface()
  
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .silylene
  cageTooltipDesc.frameworkType = .atrane(.germanium)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  try! cageTooltip.loadCachedValue()
  cageTooltip.rotate(angle: -125 * .pi / 180, axis: SIMD3(0.00, 1.00, 0.00))
  
  var reactionDesc = Silicon111ReactionDescriptor()
  reactionDesc.siliconTooltip = siliconTooltip
  reactionDesc.cageTooltip = cageTooltip
  reactionDesc.frameBudget = 9 * 60
  reactionDesc.nearOffset = SIMD3(0.00, 0.75, 0.20)
  reactionDesc.farOffset = reactionDesc.nearOffset! + SIMD3(0.00, 0.30, 0.00)
  
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
      type: .donation([.silicon, .hydrogen, .hydrogen])
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
//        component: "Reaction 7l (\(key)).data", directoryHint: .notDirectory)
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

func replaceApex(tooltip: inout CageTooltip) {
  for atomID in tooltip.apex.indices {
    var atom = tooltip.apex[atomID]
    if atom.position.y < -0.020,
       atom.atomicNumber == 6 || atom.atomicNumber == 14 {
      atom.atomicNumber = 6
    }
    tooltip.apex[atomID] = atom
  }
  
  // Ensure the (now corrupted) apex-framework boundary is never accessed.
  tooltip.apexFrameworkBoundary = [SIMD2(99000, 999000)]
  
  // Shrink the list of apex atoms.
//  var hydrogenCursor = 0
//  var removedHydrogens: [UInt32] = []
//  for atomID in tooltip.apex.indices {
//    let atom = tooltip.apex[atomID]
//    if atom.atomicNumber == 1 {
//      removedHydrogens.append(UInt32(atomID))
//      hydrogenCursor += 1
//    }
//  }
//  for atomID in removedHydrogens.reversed() {
//    tooltip.apex.remove(at: Int(atomID))
//  }
}

#if false
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
    Framework(type: .ethynylAdamantane),
    Framework(type: .adamantane(.carbon)),
    Framework(type: .adamantane(.silicon)),
    Framework(type: .adamantane(.germanium)),
    Framework(type: .atrane(.silicon)),
    Framework(type: .atrane(.germanium)),
    Framework(type: .atrane(.tin)),
    Framework(type: .atrane(.lead)),
    Framework(type: .adamantasilane(.carbon)),
    Framework(type: .adamantasilane(.silicon)),
    Framework(type: .adamantasilane(.germanium)),
    Framework(type: .adamantasilane(.tin)),
    Framework(type: .adamantasilane(.lead)),
  ]
  let frameworkNames: [String] = [
    "| ethynyl-adamantane ",
    "| adamantane(C)      ",
    "| adamantane(Si)     ",
    "| adamantane(Ge)     ",
    "| atrane(Si)         ",
    "| atrane(Ge)         ",
    "| atrane(Sn)         ",
    "| atrane(Pb)         ",
    "| adamantasilane(C)  ",
    "| adamantasilane(Si) ",
    "| adamantasilane(Ge) ",
    "| adamantasilane(Sn) ",
    "| adamantasilane(Pb) ",
  ]
  let feedstocks: [Reaction] = [
    Reaction(
      chargedTooltip: .germene,
      dischargedTooltip: .radical,
      unboundFeedstock: .germene),
    Reaction(
      chargedTooltip: .germylene,
      dischargedTooltip: .radical,
      unboundFeedstock: .germylene),
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
      try! dischargedTooltip.loadCachedValue()
      
      cageTooltipDesc = CageTooltipDescriptor()
      cageTooltipDesc.apexPassivators = framework.apexPassivators
      cageTooltipDesc.feedstockType = reaction.chargedTooltip
      cageTooltipDesc.frameworkType = framework.type
      var chargedTooltip = CageTooltip(descriptor: cageTooltipDesc)
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

#if false
// Workspace for building onto the silicon tooltip.
//
// To be archived in Silicon111BuildSequence+Workspace3.
//
// HAbst | z=0.70, Ge-C2  | Reaction 1n (2024-07-28 12_59_19 +0000).data
// HDon  | z=0.45, C3Si   | Reaction 2n (2024-07-28 13_04_54 +0000).data
//       | z=0.45, C2SiSi |
// HAbst | z=0.70, Ge-C2  | Reaction 3n (2024-07-28 13_17_50 +0000).data
// SiH3  | z=0.50, Si3Ge  | Reaction 4n (2024-07-28 13_28_23 +0000).data
//       | z=0.50, CSi2Ge |
//       | z=0.50, CSi2Si |
// HAbst | z=0.65, Ge-C2  | Reaction 5n (2024-07-28 13_44_43 +0000).data
// HAbst | z=0.60, C3Si   | Reaction 6n (2024-07-28 13_55_06 +0000).data
//       | z=0.55, C2SiSi | Reaction 6n (2024-07-28 14_09_40 +0000).data
//
func createGeometry() -> [[Entity]] {
  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  siliconTooltip.surface.remove(at: 19)
  
  #if false
  for atomID in siliconTooltip.surface.indices {
    // Right:  14 1 SIMD3<Float>(0.390625, -0.15234375, 0.005859375)
    // Front:  16 1 SIMD3<Float>(0.19921875, -0.15136719, 0.3359375)
    // Center: 19 1 SIMD3<Float>(-0.001953125, -0.14550781, 0.0)
    let atom = siliconTooltip.surface[atomID]
    guard atomID == 13 || atomID == 14 || atomID == 16 ||
            atomID == 17 || atomID == 18 || atomID == 19 else {
      continue
    }

    // Transmute a hydrogen passivator to carbon.
    siliconTooltip.surface[atomID].atomicNumber = 6
    siliconTooltip.surface[atomID].position.y = -0.19

    // Add three new hydrogens.
    let positionDeltas: [SIMD3<Float>] = [
      SIMD3(0.00, -0.10, -0.10),
      SIMD3(-0.10, -0.10, 0.05),
      SIMD3(0.10, -0.10, 0.05),
    ]
    for positionDelta in positionDeltas {
      let position = atom.position + positionDelta
      let hydrogen = Entity(position: position, type: .atom(.hydrogen))
      siliconTooltip.surface.append(hydrogen)
    }
  }
  
  // Removed hydrogens:
  // 13: 20-22
  // 14: 23-25
  // 16: 26-28
  // 17: 29-31
  // 18: 32-34
  // 19: 35-37
  //
  // - First silicon: 24, 26, 37
  // - Second silicon: 21, 34, 35
  siliconTooltip.surface.remove(at: 37)
  siliconTooltip.surface.remove(at: 35)
  siliconTooltip.surface.remove(at: 34)
  siliconTooltip.surface.remove(at: 26)
  siliconTooltip.surface.remove(at: 24)
  siliconTooltip.surface.remove(at: 21)
  
  siliconTooltip.surface += [
    Entity(position: SIMD3(0.00, -0.30, -0.23), type: .atom(.silicon)),
    Entity(position: SIMD3(0.00, -0.44, -0.23), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.20, -0.30, 0.14), type: .atom(.silicon)),
    Entity(position: SIMD3(0.20, -0.44, 0.14), type: .atom(.hydrogen)),
  ]
  #endif
    
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
  reactionDesc.nearOffset = SIMD3(0.00, 1.00, 0.00)
  reactionDesc.farOffset = reactionDesc.nearOffset! + SIMD3(0.00, 0.20, 0.00)
  
  var reaction = Silicon111Reaction(descriptor: reactionDesc)
  
  var output: [[Entity]] = []
  output.append(createFrame(reaction: reaction))
  return output
  
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

func replaceApex(tooltip: inout CageTooltip) {
  var carbonID: Int = .zero
  for atomID in tooltip.apex.indices {
    var atom = tooltip.apex[atomID]
    if atom.position.y < -0.020,
       atom.atomicNumber == 6 || atom.atomicNumber == 14 {
      
      let carbonCount: Int = 2
      if carbonID >= 1 {
        atom.atomicNumber = 6
      } else {
        atom.atomicNumber = 14
      }
      carbonID += 1
    }
    tooltip.apex[atomID] = atom
  }
  
  // Ensure the (now corrupted) apex-framework boundary is never accessed.
  tooltip.apexFrameworkBoundary = [SIMD2(99000, 999000)]
  
  // Shrink the list of apex atoms.
//  var hydrogenCursor = 0
//  var removedHydrogens: [UInt32] = []
//  for atomID in tooltip.apex.indices {
//    let atom = tooltip.apex[atomID]
//    if atom.atomicNumber == 1 {
//      removedHydrogens.append(UInt32(atomID))
//      hydrogenCursor += 1
//    }
//  }
//  for atomID in removedHydrogens.reversed() {
//    tooltip.apex.remove(at: Int(atomID))
//  }
}
#endif

#if false
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
//    Framework(type: .adamantane(.carbon)),
//    Framework(type: .adamantane(.silicon)),
//    Framework(type: .adamantane(.germanium)),
    Framework(type: .atrane(.silicon)),
//    Framework(type: .atrane(.germanium)),
//    Framework(type: .atrane(.tin)),
//    Framework(type: .atrane(.lead)),
//    Framework(type: .adamantasilane(.carbon)),
    Framework(type: .adamantasilane(.silicon)),
//    Framework(type: .adamantasilane(.germanium)),
//    Framework(type: .adamantasilane(.tin)),
//    Framework(type: .adamantasilane(.lead)),
  ]
  let frameworkNames: [String] = [
//    "| ethynyl-adamantane ",
//    "| adamantane(C)      ",
//    "| adamantane(Si)     ",
//    "| adamantane(Ge)     ",
    "| atrane(Si)         ",
//    "| atrane(Ge)         ",
//    "| atrane(Sn)         ",
//    "| atrane(Pb)         ",
//    "| adamantasilane(C)  ",
    "| adamantasilane(Si) ",
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
