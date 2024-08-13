//
//  Workspace2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/11/24.
//
#if false

// Tasks:
// - Change the parameter values you need to gather.
//   - Height and radius for 4 states with each tripod framework.
//   - Run a simplified physics simulation to figure out these parameters.
//     - Classify the results as falling into each of 4 states. Then, gather
//       the population statistics about that state.
//     - Easier alternative: use the transition probability matrix. None of
//       the other geometric data needs to be parametrized manually.
//    - Before doing this, I should simulate the chemical reaction that binds
//      tripods to the surface. And acquire an accurate reconstruction model.
//      And before that, characterize gas-phase stability at various
//      temperatures (both capped and radical forms).
// - Start designing the "universal tooltip" out of pseudoatrane(Ge).
//   - Use maximum height of a successfully bound tripod. Assume the lowest
//     height has the tooltip bonding to a surface silicon. This model is
//     conservative, accounting for the increase in height from incorrectly
//     bound tripods.
//   - Make an aromatic hydrocarbon lattice that be extended to an indefinite
//     number of rings.
//   - If the lattice must be long enough that stiffness is a concern, revise
//     the shape to be 2D instead of 1D.

// MARK: - Workspace

// Set up a scene with multiple feedstock molecules on the presentation surface.
//
// Use this scene to visually debug the height of the conventional tip.
func createGeometry() -> [Entity] {
  // I need an algorithm to lay out the tooltips spatially, without them
  // overlapping each other.
  // - Out of scope: silane/disilane, which will decorate the surface in
  //   another step. We'll need to reproduce the chemisorption trajectory from
  //   the research paper and animate it.
  // - Another thing to consider: the animation must have the hydrogens
  //   dissociate from the amine group. Find all the atoms that the tripod
  //   binds to, and have the hydrogen land on the nearest structure feature.
  // - This step should wait until we have a full model of Si(311) coded. It
  //   would have higher-level abstractions about where all the atoms with
  //   dangling bonds are (2D arrays that can be indexed).
  //
  // To start, I need to parameterize this algorithm. Measure a cylindrical
  // bounding volume, overlaid on the Si(311) surface.
  //
  // Parameter                | Adamantane | Azastannatrane |
  // ------------------------ | ---------- | -------------- |
  // Binding Success Rate     |        20% |            40% |
  // Tilt Variation (Success) |            |                |
  // Tilt           (Failure) |            |                |
  // Bounding Volume - Radius |            |                |
  // Bounding Volume - Low Z  |   -0.50 nm |       -0.53 nm |
  // Bounding Volume - High Z |   +0.80 nm |       +0.86 nm |
  //
  // Radius should account for the footprint when the failure mode happens.
  // - Measure the radius during success.
  // - In a later step, correct the value for adamantane.
  var output: [Entity] = []
  
  // Make the Si(311) surface.
  // - Eventually, we'll upgrade to a larger model that also reflects the
  //   correct surface reconstruction. The current model is sufficient for
  //   debugging the autogeneration of a handful of tripods.
  let surfaceModel = SurfaceModel(type: .silicon311)
  output += surfaceModel.topology.atoms
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAzastannatraneTooltip(
      type: .dischargedAcetylene(.bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position += SIMD3(0.00, 0.53, 0.00)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAzastannatraneTooltip(
      type: .trihalogenide(.carbon, .hydrogen, .hydrogen, .bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position += SIMD3(0.90, 0.53, 1.40)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAzastannatraneTooltip(
      type: .trihalogenide(.carbon, .hydrogen, .hydrogen, .bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    
    let rotation = Quaternion<Float>(
      angle: 120 * .pi / 180, axis: SIMD3(0.00, 1.00, 0.00))
    
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position = rotation.act(on: atom.position)
      atom.position += SIMD3(-1.60, 0.53, 0.20)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .dischargedAcetylene(.bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position += SIMD3(-0.10, 0.50, -1.20)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .dischargedAcetylene(.bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    
    let rotation1 = Quaternion<Float>(
      angle: 30 * .pi / 180, axis: SIMD3(0.00, 1.00, 0.00))
    let rotation2 = Quaternion<Float>(
      angle: -70 * .pi / 180, axis: SIMD3(0.00, 0.00, 1.00))
    
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position = rotation1.act(on: atom.position)
      atom.position = rotation2.act(on: atom.position)
      atom.position += SIMD3(2.00, 0.40, -0.10)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .trihalogenide(.carbon, .hydrogen, .hydrogen, .bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    
    let rotation = Quaternion<Float>(
      angle: -70 * .pi / 180, axis: SIMD3(1.00, 0.00, 0.00))
    
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position = rotation.act(on: atom.position)
      atom.position += SIMD3(-1.00, 0.30, 1.40)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .trihalogenide(.carbon, .hydrogen, .hydrogen, .bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position += SIMD3(0.00, 0.50, 1.70)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .dischargedAcetylene(.bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    
    let rotation = Quaternion<Float>(
      angle: -10 * .pi / 180, axis: SIMD3(0.00, 0.00, 1.00))
    
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position = rotation.act(on: atom.position)
      atom.position += SIMD3(-0.10, 0.50, 2.70)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .trihalogenide(.carbon, .hydrogen, .hydrogen, .bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    
    let rotation = Quaternion<Float>(
      angle: 130 * .pi / 180, axis: SIMD3(0.00, 1.00, 0.00))
    
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position = rotation.act(on: atom.position)
      atom.position += SIMD3(-1.00, 0.50, -1.00)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAzastannatraneTooltip(
      type: .dischargedAcetylene(.bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    
    let rotation1 = Quaternion<Float>(
      angle: .pi / 3, axis: SIMD3(0.00, 1.00, 0.00))
    let rotation2 = Quaternion<Float>(
      angle: -110 * .pi / 180, axis: SIMD3(0.00, 0.00, 1.00))
    let rotation3 = Quaternion<Float>(
      angle: 50 * .pi / 180, axis: SIMD3(0.00, 1.00, 0.00))
    
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position = rotation1.act(on: atom.position)
      atom.position = rotation2.act(on: atom.position)
      atom.position = rotation3.act(on: atom.position)
      atom.position += SIMD3(1.30, 0.45, -1.30)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .dischargedAcetylene(.bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position += SIMD3(2.00, 0.50, 0.70)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .trihalogenide(.carbon, .hydrogen, .hydrogen, .bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position += SIMD3(-0.70, 0.50, -2.00)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .dischargedAcetylene(.bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position += SIMD3(0.30, 0.50, -2.50)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  do {
    // Overlay one adamantane at the correct height
    // - Derive the Low Z parameter from this.
    let tripod = createAdamantaneTooltip(
      type: .trihalogenide(.carbon, .hydrogen, .hydrogen, .bromine))
    var tripodAtoms =
    tripod.feedstock +
    tripod.apex +
    tripod.framework +
    tripod.legs
    
    let rotation1 = Quaternion<Float>(
      angle: -.pi / 6, axis: SIMD3(0.00, 1.00, 0.00))
    let rotation2 = Quaternion<Float>(
      angle: 50 * .pi / 180, axis: SIMD3(0.00, 0.00, 1.00))
    
    for atomID in tripodAtoms.indices {
      var atom = tripodAtoms[atomID]
      atom.position = rotation1.act(on: atom.position)
      atom.position = rotation2.act(on: atom.position)
      atom.position += SIMD3(-2.90, 0.45, 0.10)
      tripodAtoms[atomID] = atom
    }
    output += tripodAtoms
  }
  
  return output
}


#endif



#if false

func createLargeAromaticLeg() -> [Entity] {
  // Compile the leg lattice.
  let carbonLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 4 * h + 4 * h2k + 1 * l }
    Material { .elemental(.carbon) }
    
    // Truncate the second atomic layer.
    Volume {
      Origin { 0.2 * l }
      Plane { l }
      Replace { .empty }
    }
    
    // Clear out the part that binds to the metal atom.
    Volume {
      // Nitrogen atom, marked with fluorine for removal.
      Origin { 7 * h }
      Plane { k + 2 * h }
      Replace { .atom(.fluorine) }
    }
    Volume {
      Origin { 3.5 * h2k }
      Plane { h2k }
      Replace { .atom(.oxygen) }
    }
    Volume {
      Origin { 4.75 * h2k }
      Plane { k + h }
      Replace { .empty }
    }
    
    // Cut out the shape of the leg.
    Volume {
      Convex {
        Origin { 1 * h2k }
        Plane { k - h }
      }
      Convex {
        Origin { 1 * h }
        Plane { -k + h }
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
  
  // Create a topology.
  var topology = Topology()
  topology.insert(atoms: carbonLattice.atoms)
  for atomID in topology.atoms.indices {
    topology.atoms[atomID].position.z = 0
    topology.atoms[atomID].position.x *= grapheneHexagonScale
    topology.atoms[atomID].position.y *= grapheneHexagonScale
  }
  
  // Add the amine linker.
  topology.insert(atoms: [
    Entity(position: SIMD3(0.13, -0.08, 0.00), type: .atom(.nitrogen))
  ])
  
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
  do {
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
  
  //  for atomID in carbons.indices {
  //    var atom = carbons[atomID]
  //
  //    let rotation = Quaternion<Float>(
  //      angle: -15 * .pi / 180, axis: SIMD3(0.00, 0.00, 1.00))
  ////    atom.position = rotation.act(on: atom.position)
  ////    atom.position.y = -atom.position.y
  ////    atom.position += SIMD3(-1.52, 1.68, 1.00)
  //    output.append(atom)
  //  }
  //  output.append(Entity(
  //    position: SIMD3(-0.20, 0.35, 1.00), type: .atom(.germanium)))
  
  return topology.atoms
}

#endif



#if false

// Two tasks to accomplish next:
// - Fix up SurfaceModel.
//   - Use literature values for the Si(100)-(2x1), Si(311)-(3x1) and
//     Si(111)-(7x7) reconstructions.
//   - Si(100)-(2x1) is a simple starter, helps me get the hang of injecting
//     repeating arrays of a literature value.
//   - Implement and validate these surfaces, in the order of progressive
//     disclosure of complexity.
// - The primary problem was needing to mark regions of the surface to stay
//   anchored during MM4 minimizations. Basically, we were fighting against
//   MM4 and wanted to override its answer.
//   - Remove the topology and hydrogen passivators. Instead, provide enough
//     information to auto-generate the topology.
//   - By removing the hydrogens, we avoid the hydrogen collisions on the
//     sides, which are an eyesore.
// - Troubleshoot the chemisorption of disilane and various linkers.
func createGeometry() -> [Entity] {
  // Try making new code specifically for Si(311), which may be the easiest
  // surface to model.
  let layer1 = """
  1  1.25  0.00  0.00
  2  1.70  -2.31  -0.31
  3  0.00  -8.03  -0.66
  4  0.00  -2.89  -1.84
  5  0.00  -5.56  -1.70
  6  3.84  -2.89  -1.49
  7  3.84  -5.21  -1.78
  8  1.92  -5.79  -3.04
  9  1.92  -8.10  -3.52
  10  5.76  -5.79  -3.04
  11  5.76  -8.10  -3.52
  
  """
  
  let layer2 = """
  B1  0.00  -8.68  -4.72
  B2  0.00  -10.99  -5.13
  B3  1.92  -11.58  -6.36
  B4  1.92  -13.89  -6.77
  
  """
  
  func parseLegend(_ rawString: String) -> [String: SIMD3<Float>] {
    var output: [String: SIMD3<Float>] = [:]
    
    // Iterate over the lines.
    let lines = rawString.split(separator: "\n").map(String.init)
    for lineID in lines.indices {
      let line = lines[lineID]
      let words = line.split(separator: " ").map(String.init)
      guard words.count == 4 else {
        fatalError("Unexpected word count.")
      }
      
      // Dissect the line.
      let key = words[0]
      let coordinateX = Float(words[1])!
      let coordinateY = Float(words[2])!
      let coordinateZ = Float(words[3])!
      
      // Convert from angstroms to nanometers.
      var position = SIMD3(coordinateX, coordinateY, coordinateZ)
      position /= 10
      
      // Store in the dictionary.
      output[key] = position
    }
    
    return output
  }
  let surfacePositions = parseLegend(layer1)
  let bulkPositions = parseLegend(layer2)
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 10 * k + 10 * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Origin { 2.05 * (h + k + 3 * l) }
      Plane { h + k + 3 * l }
      Replace { .empty }
    }
  }
  
  let basis: (
    x: SIMD3<Float>,
    y: SIMD3<Float>,
    z: SIMD3<Float>
  ) = (
    SIMD3(1.00, -1.00, 0.00) / Float(2).squareRoot(),
    -SIMD3(3.00, 3.00, -2.00) / Float(22).squareRoot(),
    SIMD3(1.00, 1.00, 3.00) / Float(11).squareRoot()
  )
  
  // Transform the atoms.
  var topology = Topology()
  topology.insert(atoms: lattice.atoms)
  
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    var position = atom.position
    position = SIMD3(
      (position * basis.x).sum(),
      (position * basis.y).sum(),
      (position * basis.z).sum())
    
    atom.position = position
    topology.atoms[atomID] = atom
  }
  
  // Try to align the atom coordinates from the paper with the lattice.
  var researchPaperAtoms: [Entity] = []
  do {
    let cubicConstant = Constant(.square) { .elemental(.silicon) }
    let constantX = cubicConstant * Float(2).squareRoot()
    let constantY = cubicConstant * Float(22).squareRoot()
    let constantZ = cubicConstant * Float(11).squareRoot()
    
    for key in bulkPositions.keys {
      let bulkPosition = bulkPositions[key]!
      var atom = Entity(position: bulkPosition, type: .atom(.silicon))
      
      // 0.2500, -0.0456, 2.1030 * scaled constants
      atom.position += SIMD3(
        0.2500 * constantX,
        -0.0456 * constantY,
        2.1030 * constantZ)
      researchPaperAtoms.append(atom)
    }
    
    for key in surfacePositions.keys {
      let surfacePosition = surfacePositions[key]!
      var atom = Entity(position: surfacePosition, type: .atom(.silicon))
      atom.position += SIMD3(
        0.2500 * constantX,
        -0.0456 * constantY,
        2.1030 * constantZ)
      researchPaperAtoms.append(atom)
    }
  }
  
  
  
  let matches = topology.match(
    researchPaperAtoms, algorithm: .absoluteRadius(0.050))
  
  var matchingAtoms: [Entity] = []
  for atomID in researchPaperAtoms.indices {
    let atom = researchPaperAtoms[atomID]
    
    let matchList = matches[atomID]
    let matchID = matchList.first!
    let matchedAtom = topology.atoms[Int(matchID)]
    print()
    print(matchList.count)
    print(atom)
    print(matchedAtom)
    
    let cubicConstant = Constant(.square) { .elemental(.silicon) }
    let constantX = cubicConstant * Float(2).squareRoot()
    let constantY = cubicConstant * Float(22).squareRoot()
    let constantZ = cubicConstant * Float(11).squareRoot()
    
    var delta = atom.position - matchedAtom.position
    delta /= SIMD3(constantX, constantY, constantZ)
    print(delta)
    
    matchingAtoms.append(matchedAtom)
  }
  
  var tiledSurface = researchPaperAtoms
  tiledSurface += tiledSurface.map {
    var copy = $0
    
    let cubicConstant = Constant(.square) { .elemental(.silicon) }
    let constantX = cubicConstant * Float(2).squareRoot()
    let midpoint = 0.25 * constantX
    copy.position.x = midpoint + (midpoint - copy.position.x)
    return copy
  }
  tiledSurface += tiledSurface.map {
    var copy = $0
    
    let cubicConstant = Constant(.square) { .elemental(.silicon) }
    let constantX = cubicConstant * Float(2).squareRoot()
    let constantY = cubicConstant * Float(22).squareRoot()
    
    copy.position += SIMD3(
      0.75 * constantX,
      -0.25 * constantY,
      0.00)
    return copy
  }
  tiledSurface += tiledSurface.map {
    var copy = $0
    
    let cubicConstant = Constant(.square) { .elemental(.silicon) }
    let constantX = cubicConstant * Float(2).squareRoot()
    let constantY = cubicConstant * Float(22).squareRoot()
    
    copy.position += SIMD3(
      -0.75 * constantX,
      -0.25 * constantY,
      0.00)
    return copy
  }
  tiledSurface += tiledSurface.map {
    var copy = $0
    
    let cubicConstant = Constant(.square) { .elemental(.silicon) }
    let constantX = cubicConstant * Float(2).squareRoot()
    let constantY = cubicConstant * Float(22).squareRoot()
    
    copy.position += SIMD3(
      -1.50 * constantX,
      -0.50 * constantY,
      0.00)
    return copy
  }
  tiledSurface += tiledSurface.map {
    var copy = $0
    
    let cubicConstant = Constant(.square) { .elemental(.silicon) }
    let constantX = cubicConstant * Float(2).squareRoot()
    let constantY = cubicConstant * Float(22).squareRoot()
    
    copy.position += SIMD3(
      1.50 * constantX,
      -0.50 * constantY,
      0.00)
    return copy
  }
  
  
  
  // TODO: Next, debug the embedding into the bulk lattice. De-duplicate
  // the atoms and generate a valid topology.
   
  return tiledSurface
}


#endif
