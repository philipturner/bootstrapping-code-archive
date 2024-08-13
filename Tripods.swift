//
//  Tripods.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/10/24.
//

import HDL
import Numerics
import xTB

// This file contains a variety of utilities for compiling and preparing
// tripod structures (specifically, feedstocks).

// MARK: - Precursor Molecules

func createTrimethylsilyl() -> [Entity] {
  var output: [Entity] = [
    Entity(position: SIMD3(0.10, 0.00, 0.35), type: .atom(.silicon)),
  ]
  
  let methyl: [Entity] = [
    Entity(position: SIMD3(0.10, 0.00, 0.53), type: .atom(.carbon)),
    Entity(position: SIMD3(0.02, -0.08, 0.55), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.18, -0.08, 0.55), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.10, 0.10, 0.55), type: .atom(.hydrogen)),
  ]
  for methylID in 0..<3 {
    for atomID in methyl.indices {
      var atom = methyl[atomID]
      let silicon = output[0]
      var delta = atom.position - silicon.position
      
      switch methylID {
      case 0:
        delta = SIMD3(delta.x, delta.y, delta.z)
      case 1:
        delta = SIMD3(delta.y, delta.z, delta.x)
      case 2:
        delta = SIMD3(delta.z, delta.x, delta.y)
      default:
        fatalError("Unexpected methyl ID.")
      }
      
      atom.position = silicon.position + delta
      output.append(atom)
    }
  }
  
  return output
}

func createAtraneLeg() -> [Entity] {
  // Compile the leg lattice.
  let carbonLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 3 * h + 3 * h2k + 1 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 0.25 * l }
        Plane { l }
      }
      Convex {
        Origin { 1 * h2k }
        Plane { k - h }
      }
      Convex {
        Origin { 3 * h }
        Plane { k + 2 * h }
      }
      Convex {
        Origin { 0.5 * h2k }
        Plane { -h2k }
      }
      Convex {
        Origin { 1.5 * h2k }
        Plane { h2k }
      }
      
      Replace { .empty }
    }
    
    #if true
    Volume {
      Convex {
        Origin { 0.50 * (k + 2 * h) }
        Plane { -(k + 2 * h) }
      }
      Replace { .atom(.nitrogen) }
    }
    #else
    // Change what was originally amine, into an sp2 nitrogen.
    Volume {
      Convex {
        Origin { 0.5 * (k + 2 * h) }
        Plane { -(k + 2 * h) }
      }
      Replace { .empty }
    }
    Volume {
      Convex {
        Origin { 0.75 * (k + 2 * h) }
        Plane { -(k + 2 * h) }
      }
      Replace { .atom(.nitrogen) }
    }
    #endif
    
    Volume {
      Convex {
        Origin { 0.5 * k }
        Plane { -k }
      }
      Replace { .empty }
    }
  }
  
  // Rescale from lonsdaleite to graphene.
  var grapheneHexagonScale: Float
  do {
    let grapheneConstant: Float = 2.45 / 10
    let lonsdaleiteConstant = Constant(.hexagon) { .elemental(.carbon) }
    grapheneHexagonScale = 1 / lonsdaleiteConstant
    grapheneHexagonScale *= grapheneConstant
  }
  
  var carbons: [Entity] = carbonLattice.atoms
  for atomID in carbons.indices {
    carbons[atomID].position.z = 0
    carbons[atomID].position.x *= grapheneHexagonScale
    carbons[atomID].position.y *= grapheneHexagonScale
  }
  
  var topology = Topology()
  topology.insert(atoms: carbons)
  
  // Add the bulk atom bonds.
  do {
    let matches = topology.match(topology.atoms)
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
  }
  
  // Add the already known hydrogens.
  do {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp2)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let element = Element(rawValue: atom.atomicNumber)!
      let xhBondLength = element.covalentRadius +
      Element.hydrogen.covalentRadius
      
      // Don't protonate the pyridine.
      guard atom.atomicNumber != 7 else {
        continue
      }
      
      for orbital in orbitals[atomID] {
        let position = atom.position + orbital * xhBondLength
        let hydrogen = Entity(
          position: position, type: .atom(.hydrogen))
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Complete the amine groups.
  if true {
    let atomsMap = topology.map(.atoms, to: .atoms)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      guard atom.atomicNumber == 7 else {
        continue
      }
      
      let neighbors = atomsMap[atomID]
      guard neighbors.count == 1 else {
        fatalError("Unexpected neighbor count.")
      }
      let neighborID = neighbors.first!
      let neighbor = topology.atoms[Int(neighborID)]
      
      var bondVector = neighbor.position - atom.position
      bondVector /= (bondVector * bondVector).sum().squareRoot()
      
      // Rotate the one pre-determined bond in 120° increments.
      for sectorID in 1...2 {
        let angle = Float(sectorID) * (120 * .pi / 180)
        let rotation = Quaternion<Float>(
          angle: angle, axis: SIMD3(0.00, 0.00, 1.00))
        let orbital = rotation.act(on: bondVector)
        
        let nhBondLength =
        Element.nitrogen.covalentRadius +
        Element.hydrogen.covalentRadius
        let position = atom.position + orbital * nhBondLength
        let hydrogen = Entity(
          position: position, type: .atom(.hydrogen))
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Remove the hydrogen that connects to the framework.
  topology.remove(atoms: [8])
  
  return topology.atoms
}

// MARK: - Tripods

// ~100 orbitals
func createAdamantaneTooltip(type: CageFeedstockType) -> CageTooltip {
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = type
  cageTooltipDesc.frameworkType = .adamantane(.carbon)
  cageTooltipDesc.linkerType = .amine
  
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  try! cageTooltip.loadCachedValue()
  return cageTooltip
}

// ~260 orbitals (trimethylsilyl)
// ~200 orbitals (methyl)
func createAzastannatraneTooltip(type: CageFeedstockType) -> CageTooltip {
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .hydrogen
  cageTooltipDesc.frameworkType = .carbatrane(.tin)
  cageTooltipDesc.linkerType = .amine
  
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  replaceFirstNeighbors(tooltip: &cageTooltip)
  replaceLegs(tooltip: &cageTooltip)
  
  // Energy-minimize the modified tooltip.
  try! cageTooltip.loadCachedValue()
  
  // Transplant the correct feedstock position from a simpler tooltip.
  // This is to bypass the issue with the carbon losing sp2 hybridization.
  do {
    var cageTooltipDesc = CageTooltipDescriptor()
    cageTooltipDesc.feedstockType = type
    cageTooltipDesc.frameworkType = .carbatrane(.tin)
    cageTooltipDesc.linkerType = .amine
    
    var feedstockTip = CageTooltip(descriptor: cageTooltipDesc)
    try! feedstockTip.loadCachedValue()
    cageTooltip.feedstock = feedstockTip.feedstock
  }
  
  return cageTooltip
}

fileprivate func replaceFirstNeighbors(
  tooltip cageTooltip: inout CageTooltip
) {
  // Change the first neighbors to nitrogen.
  for atomID in cageTooltip.apex.indices {
    var atom = cageTooltip.apex[atomID]
    if atom.position.y < -0.020,
       atom.atomicNumber == 6 {
      atom.atomicNumber = 7
    }
    cageTooltip.apex[atomID] = atom
  }
  
  // Ensure the (now corrupted) apex-framework boundary is never accessed.
  cageTooltip.apexFrameworkBoundary = [SIMD2(99000, 999000)]
  
  // Shrink the list of apex atoms.
  var hydrogenCursor = 0
  var removedHydrogens: [UInt32] = []
  for atomID in cageTooltip.apex.indices {
    let atom = cageTooltip.apex[atomID]
    if atom.atomicNumber == 1 {
      removedHydrogens.append(UInt32(atomID))
      hydrogenCursor += 1
    }
  }
  for atomID in removedHydrogens.reversed() {
    cageTooltip.apex.remove(at: Int(atomID))
  }
  
  // Add methyl groups.
  let methyl: [Entity] = [
    Entity(position: SIMD3(0.10, -0.03, 0.32), type: .atom(.carbon)),
    Entity(position: SIMD3(0.21, -0.03, 0.32), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.10, 0.08, 0.32), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.10, -0.03, 0.43), type: .atom(.hydrogen)),
  ]
  for groupID in 0..<3 {
    for atomID in methyl.indices {
      var atom = methyl[atomID]
      let tin = cageTooltip.apex[0]
      var delta = atom.position - tin.position
      
      let angle = Float(groupID) * (2 * Float.pi / 3)
      let rotation = Quaternion<Float>(
        angle: angle, axis: SIMD3(0.00, 1.00, 0.00))
      delta = rotation.act(on: delta)
      
      atom.position = tin.position + delta
      cageTooltip.framework.append(atom)
    }
  }
}

fileprivate func replaceLegs(
  tooltip cageTooltip: inout CageTooltip
) {
  // Ensure the (now corrupted) framework-legs boundary is never accessed.
  cageTooltip.legs = []
  cageTooltip.frameworkLegsBoundary = [SIMD2(99000, 999000)]
  
  // Transform the leg.
  var leg = createAtraneLeg()
  do {
    // Rotate, so it roughly points in the correct direction.
    for atomID in leg.indices {
      var atom = leg[atomID]
      var position = atom.position
      
      position = SIMD3(
        position.z, position.y, -position.x)
      
      atom.position = position
      leg[atomID] = atom
    }
    
    // Center the origin at the linking carbon.
    do {
      let linkingCarbon = leg[3]
      for atomID in leg.indices {
        var atom = leg[atomID]
        atom.position -= linkingCarbon.position
        leg[atomID] = atom
      }
    }
    
    // Rotate around the N-C vector.
    // - aniline: N=2, C=3
    // - pyridine: N=1, C=2
    do {
      let linkingCarbon = leg[3]
      let nitrogen = leg[2]
      var axis = nitrogen.position - linkingCarbon.position
      axis /= (axis * axis).sum().squareRoot()
      
      let rotation1 = Quaternion<Float>(
        angle: 30 * .pi / 180, axis: axis)
      let rotation2 = Quaternion<Float>(
        angle: -30 * .pi / 180, axis: SIMD3(0.00, 1.00, 0.00))
      
      for atomID in leg.indices {
        var atom = leg[atomID]
        atom.position = rotation1.act(on: atom.position)
        atom.position = rotation2.act(on: atom.position)
        leg[atomID] = atom
      }
    }
    
    // Translate by an offset.
    for atomID in leg.indices {
      var atom = leg[atomID]
      atom.position += SIMD3(-0.10, -0.25, 0.38)
      leg[atomID] = atom
    }
  }
  
  // Add the three aniline groups.
  for groupID in 0..<3 {
    for atomID in leg.indices {
      var atom = leg[atomID]
      let tin = cageTooltip.apex[0]
      var delta = atom.position - tin.position
      
      let angle = Float(groupID) * (2 * Float.pi / 3)
      let rotation = Quaternion<Float>(
        angle: angle, axis: SIMD3(0.00, 1.00, 0.00))
      delta = rotation.act(on: delta)
      
      atom.position = tin.position + delta
      cageTooltip.legs.append(atom)
    }
  }
}
