//
//  Reference+Minimization.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/7/24.
//

#if false

// Overall objective: simulating carbon transfer from DC10c to the crossbar, or
// from crossbar to crossbar. Using ONIOM with xTB, GFN-FF and/or MM4. After
// that, we can advance to more complex things like depositing a dimer onto a
// build plate.
//
// Next, add the second layer.
// - See whether GFN-FF is stable.
//   - Compare its O(n^2) compute cost to xTB for the assigned simulation
//     regions.
//   - See whether changing the OpenMP environment variables alters GFN-FF
//     singlepoint latency.
//   - It would be bad if one configuration speeds up GFN2-xTB, while an
//     entirely different configuration speeds up GFN-FF.
// - Simulate enough reaction trajectories to determine the directionality.
//
// Next, add the third layer.
// - Decide on how to program anchors for the MM4 layer.
//   - The two-layer version just used the barrier between GFN-FF and MM4 as
//     anchors.
// - Simulate entire reaction trajectories, mapping out the operation range.
// - Simulate the success rate at different temperatures.
// - Set up and publish a video of the reaction.

// The workspace for DC10c.
func createGeometry() -> [Entity] {
  var tooltip = DC10cTooltip()
  
  // Find the indices of the detached atoms.
  let reactiveSiteAtoms = tooltip.detachReactiveSite()
  let reactiveSiteAtomSet = Set(reactiveSiteAtoms)
  let latticeAtoms = tooltip.detachMinimalLattice()
  let latticeAtomSet = Set(latticeAtoms)
  
  // Find the bonds at the boundary.
  var boundaryBonds: [UInt32] = []
  for bondID in tooltip.rigidBody.parameters.bonds.indices.indices {
    let parameters = tooltip.rigidBody.parameters
    let bond = parameters.bonds.indices[Int(bondID)]
    
    var reactiveSiteCount: Int = .zero
    var latticeCount: Int = .zero
    for laneID in 0..<2 {
      let atomID = bond[laneID]
      if reactiveSiteAtomSet.contains(atomID) {
        reactiveSiteCount += 1
      }
      if latticeAtomSet.contains(atomID) {
        latticeCount += 1
      }
    }
    if reactiveSiteCount == 1 && latticeCount == 2 {
      boundaryBonds.append(UInt32(bondID))
    }
  }
  
  // Minimize after finding the topology, but before spawning any atoms.
  tooltip.minimize()
  
  // Iterate over the bonds.
  var framework: [Entity] = []
  for bondID in boundaryBonds {
    let parameters = tooltip.rigidBody.parameters
    let bond = parameters.bonds.indices[Int(bondID)]
    
    // Iterate over the atoms within the bond.
    var carbonPosition: SIMD3<Float>?
    var hydrogenPosition: SIMD3<Float>?
    for laneID in 0..<2 {
      let atomID = bond[laneID]
      let position = tooltip.rigidBody.positions[Int(atomID)]
      if reactiveSiteAtomSet.contains(atomID) {
        carbonPosition = position
      } else {
        hydrogenPosition = position
      }
    }
    guard let carbonPosition,
          let hydrogenPosition else {
      fatalError("Unexpected behavior with boundary bonds.")
    }
    
    // Rescale the bond vector to the C-H bond length.
    let chBondLength: Float = 1.1120 / 10
    var orbital = hydrogenPosition - carbonPosition
    orbital /= (orbital * orbital).sum().squareRoot()
    let position = carbonPosition + orbital * chBondLength
    let hydrogen = Entity(position: position, type: .atom(.hydrogen))
    framework.append(hydrogen)
  }
  
  // Add the remaining reactive site atoms.
  for atomID in reactiveSiteAtoms {
    let parameters = tooltip.rigidBody.parameters
    let atomicNumber = parameters.atoms.atomicNumbers[Int(atomID)]
    let position = tooltip.rigidBody.positions[Int(atomID)]
    let storage = SIMD4(position, Float(atomicNumber))
    framework.append(Entity(storage: storage))
  }
  
  // Extract the dimer atoms.
  var dimer: [Entity] = []
  for atomID in tooltip.detachDimer() {
    let parameters = tooltip.rigidBody.parameters
    let atomicNumber = parameters.atoms.atomicNumbers[Int(atomID)]
    let position = tooltip.rigidBody.positions[Int(atomID)]
    let storage = SIMD4(position, Float(atomicNumber))
    dimer.append(Entity(storage: storage))
  }
  
  // Transform the dimer into a carbene.
  var carbene: [Entity]
  do {
    var midPoint = (dimer[0].position + dimer[1].position) / 2
    let carbon1 = Entity(position: midPoint, type: .atom(.carbon))
    midPoint.y += 0.133
    let carbon2 = Entity(position: midPoint, type: .atom(.carbon))
    carbene = [carbon1, carbon2]
  }
  
  // Run some calculations.
  var charged = framework + dimer
  var carbenic = framework + carbene
  charged = minimize(atoms: charged)
  carbenic = minimize(atoms: carbenic)
  framework = minimize(atoms: framework)
  dimer = minimize(atoms: dimer)
  
  // Check the binding energy.
  var calculatorDesc = xTB_CalculatorDescriptor()
  calculatorDesc.atomicNumbers = (framework + dimer).map(\.atomicNumber)
  calculatorDesc.positions = (framework + dimer).map(\.position)
  calculatorDesc.hamiltonian = .tightBinding
  let calculator = xTB_Calculator(descriptor: calculatorDesc)
  for trialID in 0..<30 {
    let separation = 0.1 * Float(trialID) + 0
    var atoms = framework
    atoms += dimer.map {
      var copy = $0
      copy.position.y += separation
      return copy
    }
    
    calculator.molecule.positions = atoms.map(\.position)
    xTB_Environment.show()
    print("distance: \(Format.distance(separation))", terminator: " | ")
    print("energy: \(Format.energy(calculator.energy))", terminator: " | ")
    print()
  }
  
  // Render all of the structures.
  var output: [Entity] = []
  output += charged.map {
    var copy = $0
    copy.position += SIMD3(-0.7, 0.7, 0)
    return copy
  }
  output += carbenic.map {
    var copy = $0
    copy.position += SIMD3(0.7, 0.7, 0)
    return copy
  }
  output += framework.map {
    var copy = $0
    copy.position += SIMD3(-0.7, -0.7, 0)
    return copy
  }
  output += dimer.map {
    var copy = $0
    copy.position += SIMD3(0.7, -0.7, 0)
    return copy
  }
  return output
}

#if false
// Workspace for transforming a tooltip into the group (V) version.
func createGeometry() -> [Entity] {
  // Create the tooltip.
  var tooltipDesc = DCB6TooltipDescriptor()
  tooltipDesc.reactiveSiteLeft = .silicon
  tooltipDesc.reactiveSiteRight = .silicon
  tooltipDesc.state = .charged
  var tooltip = DCB6Tooltip(descriptor: tooltipDesc)
  //tooltip.topology.atoms = minimize(atoms: tooltip.topology.atoms)
  
  for laneID in 0..<2 {
    let atomID = tooltip.reactiveSiteIDs[laneID]
    var atom = tooltip.topology.atoms[Int(atomID)]
    atom.atomicNumber = 31
    tooltip.topology.atoms[Int(atomID)] = atom
  }
  tooltip = halogenize(tooltip: tooltip, atomicNumber: 7)
  //tooltip.topology.atoms = minimize(atoms: tooltip.topology.atoms)
  
  return tooltip.topology.atoms
}
#endif


#if true
// The workspace for automating energy analysis.
func createGeometry() -> [Entity] {
  let tableString = """
| DCB(B)-N   | -1607.58 eV | -1607.88 eV | -1494.09 eV | -1604.24 eV |
| DCB(B)-P   | -1586.01 eV | -1585.71 eV | -1472.18 eV | -1582.27 eV |
| DCB(B)-As  | -1576.24 eV | -1575.93 eV | -1462.90 eV | -1573.00 eV |
"""
  
  let lines = tableString.split(separator: "\n").map(String.init)
  for line in lines {
    var fragments = line.split(separator: "|").map(String.init)
    fragments = Array(fragments[1...])
    
    var integerValues: [Int64] = []
    for var fragment in fragments {
      var characters: [UInt8] = []
      fragment.withUTF8 { utf8 in
        characters.append(utf8[2])
        characters.append(utf8[3])
        characters.append(utf8[4])
        characters.append(utf8[5])
        characters.append(utf8[7])
        characters.append(utf8[8])
      }
      
      var string = ""
      for character in characters {
        let scalar = Unicode.Scalar(character)
        string.append(Character(scalar))
      }
      integerValues.append(Int64(string)!)
    }
    
    var processedEnergies: [Int64] = []
    processedEnergies.append(integerValues[0] - integerValues[2] - 11009)
    processedEnergies.append(integerValues[0] - integerValues[3])
    processedEnergies.append(integerValues[0] - integerValues[1])
    
    for energy in processedEnergies {
      var repr = String(format: "%.2f", Double(energy) / 100) + " eV"
      if !repr.starts(with: "-") {
        repr = "+" + repr
      }
      repr = Format.pad(repr, to: 8)
      print(repr, terminator: " | ")
    }
    print()
  }
  
  exit(0)
}


// The workspace for automating energy analysis.
func createGeometry() -> [Entity] {
  let tableString = """
| Diatrane(B,C)-Sn  | -1579.67 eV | -1614.67 eV | -1689.16 eV | -1552.35 eV |
| Diatrane(B,S)-Sn  | -1586.40 eV | -1621.64 eV | -1696.17 eV | -1559.29 eV |
| Diatrane(C,C)-Sn  | -1737.59 eV | -1773.04 eV | -1847.49 eV | -1711.73 eV |
| Diatrane(P,C)-Sn  | -1725.82 eV | -1761.18 eV | -1835.75 eV | -1699.27 eV |
| Diatrane(P,S)-Sn  | -1732.75 eV | -1768.34 eV | -1842.94 eV | -1706.50 eV |
"""
  
  let lines = tableString.split(separator: "\n").map(String.init)
  for line in lines {
    var fragments = line.split(separator: "|").map(String.init)
    fragments = Array(fragments[1...])
    
    var integerValues: [Int64] = []
    for var fragment in fragments {
      var characters: [UInt8] = []
      fragment.withUTF8 { utf8 in
        characters.append(utf8[2])
        characters.append(utf8[3])
        characters.append(utf8[4])
        characters.append(utf8[5])
        characters.append(utf8[7])
        characters.append(utf8[8])
      }
      
      var string = ""
      for character in characters {
        let scalar = Unicode.Scalar(character)
        string.append(Character(scalar))
      }
      integerValues.append(-Int64(string)!)
    }
    
    var processedEnergies: [Int64] = []
    processedEnergies.append(-(integerValues[0] - (integerValues[3] - 26_74)))
    processedEnergies.append(-(integerValues[1] - (integerValues[3] - 59_00)))
    processedEnergies.append(-(integerValues[2] - (integerValues[3] - 136_22)))
    
    for energy in processedEnergies {
      var repr = String(format: "%.2f", Double(energy) / 100) + " eV"
      if !repr.starts(with: "-") {
        repr = "+" + repr
      }
      repr = Format.pad(repr, to: 8)
      print(repr, terminator: " | ")
    }
    print()
  }
  
  exit(0)
}


#endif

#if false
// The workspace for DCB6.
func createGeometry() -> [Entity] {
  // MARK: - Design
  
  var minimizing: Bool = true
  minimizing = Bool.random() ? minimizing : minimizing
  
  // Create the tooltip.
  var tooltipDesc = DCB6TooltipDescriptor()
  tooltipDesc.reactiveSiteLeft = .germanium
  tooltipDesc.reactiveSiteRight = .germanium
  tooltipDesc.state = .charged
  var tooltip = DCB6Tooltip(descriptor: tooltipDesc)
  
  // Change the tooltip to include a group (V) element.
  func modify(tooltip input: DCB6Tooltip) -> DCB6Tooltip {
    var tooltip = input
    for laneID in 0..<2 {
      let atomID = tooltip.reactiveSiteIDs[laneID]
      var atom = tooltip.topology.atoms[Int(atomID)]
      atom.atomicNumber = 33
      tooltip.topology.atoms[Int(atomID)] = atom
    }
    tooltip = halogenize(tooltip: tooltip, atomicNumber: 5)
    return tooltip
  }
  
  // MARK: - Simulation
  
  // Find the charged structure.
  var charged = tooltip.topology.atoms
  if minimizing {
    charged = minimize(atoms: charged)
  }
  tooltip.topology.atoms = charged
  var chargedTooltip = tooltip
  
  tooltip.topology.remove(atoms: [tooltip.dimerIDs![0], tooltip.dimerIDs![1]])
  tooltip.addFeedstockTopology(state: .carbenicRearrangement)
  
  // Find the carbenic structure.
  var carbenic = tooltip.topology.atoms
  if minimizing {
    carbenic = minimize(atoms: carbenic)
  }
  tooltip.topology.atoms = carbenic
  var carbenicTooltip = tooltip
  
  // Inject the modified structure now.
  print()
  print("Injecting custom structure.")
  chargedTooltip = modify(tooltip: chargedTooltip)
  carbenicTooltip = modify(tooltip: carbenicTooltip)
  charged = chargedTooltip.topology.atoms
  carbenic = carbenicTooltip.topology.atoms
  if minimizing {
    charged = minimize(atoms: charged)
    carbenic = minimize(atoms: carbenic)
  }
  
  // Separate the fragments.
  var dimer: [Entity]
  var framework: [Entity]
  do {
    let sortedAtoms = charged.sorted(by: {
      $0.position.y > $1.position.y
    })
    guard sortedAtoms[0].atomicNumber == 6,
          sortedAtoms[1].atomicNumber == 6 else {
      fatalError("Sorted atoms did not start with carbons.")
    }
    dimer = Array(sortedAtoms[..<2])
    framework = Array(sortedAtoms[2...])
  }
  
  // Run simulations on various fragments.
  if minimizing {
    dimer = minimize(atoms: dimer)
    framework = minimize(atoms: framework)
  }
  
  // Check the binding energy.
  if minimizing {
    var calculatorDesc = xTB_CalculatorDescriptor()
    calculatorDesc.atomicNumbers = (framework + dimer).map(\.atomicNumber)
    calculatorDesc.positions = (framework + dimer).map(\.position)
    calculatorDesc.hamiltonian = .tightBinding
    let calculator = xTB_Calculator(descriptor: calculatorDesc)
    for trialID in 0..<30 {
      let separation = 0.1 * Float(trialID) + 0
      var atoms = framework
      atoms += dimer.map {
        var copy = $0
        copy.position.y += separation
        return copy
      }
      
      calculator.molecule.positions = atoms.map(\.position)
      xTB_Environment.show()
      print("distance: \(Format.distance(separation))", terminator: " | ")
      print("energy: \(Format.energy(calculator.energy))", terminator: " | ")
      print()
    }
  }
  
  // Render all of the structures.
  var output: [Entity] = []
  output += charged.map {
    var copy = $0
    copy.position += SIMD3(-0.7, 0.7, 0)
    return copy
  }
  output += carbenic.map {
    var copy = $0
    copy.position += SIMD3(0.7, 0.7, 0)
    return copy
  }
  output += framework.map {
    var copy = $0
    copy.position += SIMD3(-0.7, -0.7, 0)
    return copy
  }
  output += dimer.map {
    var copy = $0
    copy.position += SIMD3(0.7, -0.7, 0)
    return copy
  }
  return output
}

#endif

// Replaces the necessary atoms with a halogen.
func halogenize(
  tooltip input: DCB6Tooltip,
  atomicNumber: UInt8
) -> DCB6Tooltip {
  var tooltip = input
  
  // Find the carbons to remove and replace with a halogen.
  var replacedCarbons: [UInt32] = []
  var removedHydrogens: [UInt32] = []
  for atomID in tooltip.topology.atoms.indices {
    let atom = tooltip.topology.atoms[atomID]
    
    if atom.atomicNumber == 6 {
      let dimerIDs = tooltip.dimerIDs!
      if any(dimerIDs .== UInt32(atomID)) {
        continue
      }
      
      if atom.position.x.magnitude < 0.100 {
        continue
      }
      if atom.position.y < 0.050 {
        continue
      }
      replacedCarbons.append(UInt32(atomID))
    } else if atom.atomicNumber == 1 {
      if atom.position.x.magnitude < 0.120 {
        continue
      }
      if atom.position.y < 0.050 {
        continue
      }
      removedHydrogens.append(UInt32(atomID))
    }
  }
    
//  // Find the bonds to replace with C-X bonds.
//  var insertedAtoms: [Entity] = []
//  var insertedBonds: [SIMD2<UInt32>] = []
//  for bondID in tooltip.topology.bonds.indices {
//    let bond = tooltip.topology.bonds[Int(bondID)]
//
//    // Search for the two carbons in the bond.
//    var replacedCarbonID: UInt32?
//    var nonReplacedCarbonID: UInt32?
//    for laneID in 0..<2 {
//      let atomID = bond[laneID]
//      let atom = tooltip.topology.atoms[Int(atomID)]
//      guard atom.atomicNumber == 6 else {
//        continue
//      }
//
//      if replacedCarbons.contains(UInt32(atomID)) {
//        replacedCarbonID = atomID
//      } else {
//        nonReplacedCarbonID = atomID
//      }
//    }
//    guard let replacedCarbonID,
//          let nonReplacedCarbonID else {
//      continue
//    }
//
//    // Extract the atoms for these carbons.
//    let replacedCarbon = tooltip.topology.atoms[Int(replacedCarbonID)]
//    let nonReplacedCarbon = tooltip.topology.atoms[Int(nonReplacedCarbonID)]
//
//    // Place the halogen.
//    let bondLength = Element.carbon.covalentRadius + element.covalentRadius
//    var orbital = replacedCarbon.position - nonReplacedCarbon.position
//    orbital /= (orbital * orbital).sum().squareRoot()
//    let halogenPosition = nonReplacedCarbon.position + orbital * bondLength
//    let halogen = Entity(position: halogenPosition, type: .atom(element))
//    let halogenID = tooltip.topology.atoms.count + insertedAtoms.count
//
//    // Insert into the topology.
//    let newBond = SIMD2(UInt32(nonReplacedCarbonID), UInt32(halogenID))
//    insertedAtoms.append(halogen)
//    insertedBonds.append(newBond)
//  }
  // tooltip.topology.insert(atoms: insertedAtoms)
  // tooltip.topology.insert(bonds: insertedBonds)
  // tooltip.topology.remove(atoms: replacedCarbons + removedHydrogens)
  
  for carbonID in replacedCarbons {
    tooltip.topology.atoms[Int(carbonID)].atomicNumber = atomicNumber
  }
  
  return tooltip
}

#if false
// Workspace for building things onto graphene.
func createGeometry() -> [[Entity]] {
  // Set up a scene where the build plate is at Z = 0, and the tooltip's
  // position is measured relative to that offset.
  var buildPlate = BuildPlate()
  buildPlate.rotate(angle: -.pi / 2, axis: [1, 0, 0])
  buildPlate.translate(offset: -buildPlate.centerOfMass)
  
  var tooltip = CurrentTooltip()
  tooltip.rotate(angle: .pi, axis: [0, 0, 1])
  tooltip.translate(offset: -tooltip.centerOfMass)
  do {
    let dimer = tooltip.dimer
    let offsetY = -dimer[0].position.y
    tooltip.translate(offset: [0, offsetY, 0])
  }
  // End of setup.
  
  // Start of scripting.
  buildPlate.topology.atoms = minimize(
    atoms: Reaction.product3, anchorIDs: buildPlate.anchorAtomIDs)
  for atomID in tooltip.dimerAtomIDs {
    tooltip.topology.atoms[Int(atomID)].atomicNumber = 1
  }
  tooltip.translate(offset: [0.1, 0, -0.2])
  tooltip.topology.atoms = minimize(atoms: tooltip.topology.atoms)

  var reactionDesc = ReactionDescriptor()
  reactionDesc.buildPlate = buildPlate
  reactionDesc.tooltip = tooltip
  reactionDesc.frameBudget = 4 * 40
  reactionDesc.xMin = 0.5
  reactionDesc.xMax = 0.9
  var reaction = Reaction(descriptor: reactionDesc)
  
  var frames: [[Entity]] = []
  frames.append(
    reaction.buildPlate.topology.atoms +
    reaction.tooltip.topology.atoms)
  return frames
  
  for _ in 0..<reaction.frameBudget {
    reaction.step()
    
    var frame: [Entity] = []
    let reactionPositions = reaction.positions
    for atomID in reactionPositions.indices {
      let atomicNumber = reaction.calculator.molecule.atomicNumbers[atomID]
      let position = reactionPositions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let atom = Entity(storage: storage)
      frame.append(atom)
    }
    frames.append(frame)
  }
  
  let product =
  reaction.buildPlate.topology.atoms +
  reaction.tooltip.dimer
  let encoded = try! AtomCoder.encode(product, encoding: .hdl)
  print()
  print(encoded)
  print()
  
  return amplify(frames: frames, factor: 3)
}
#endif

#endif
