//
//  Workspace2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/6/24.
//

#if false
// Study the minimum-energy conformation of adamantane and atrane tripods.
// - What is the energy difference between the leg states?
// - How close is the correct state to the Si lattice positions?

// adamantane(C)
//   0° | -3336.58 eV
//  60° | -3336.65 eV
// 120° | -3336.66 eV
// 180° | -3336.54 eV
//
// adamantane(Ge)
//   0° | -3329.16 eV
//  60° | -3329.39 eV
// 120° | -3329.41 eV
// 180° | -3329.13 eV
//
// atrane(Si)
//   10° | -3445.02 eV (starting angle: 0)
//   45° | -3445.42 eV (starting angle: 30)
//   80° | -3445.68 eV (starting angle: 60)
//   90° | -3445.73 eV (starting angle: 90)
//  100° | -3445.67 eV (starting angle: 120)
//  130° | -3445.55 eV (starting angle: 150)
//  190° | -3445.09 eV (starting angle: 180)
//
// atrane(Sn)
// -170° | -3454.29 eV (starting angle: -180)
// -120° | -3454.61 eV (starting angle: -150)
//  -85° | -3454.79 eV (starting angle: -85)
//   30° | -3454.19 eV (starting angle: 0)
//   80° | -3454.78 eV (starting angle: 80)
//  100° | -3454.72 eV (starting angle: 120)
//  110° | -3454.67 eV (starting angle: 130)
//  120° | -3454.61 eV (starting angle: 150)
//  150° | -3454.42 eV (starting angle: 170)
func createGeometry() -> [[Entity]] {
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
  
  var legTopology = Topology()
  legTopology.insert(atoms: carbons)
  
  // Add the bulk atom bonds.
  do {
    let matches = legTopology.match(legTopology.atoms)
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in legTopology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    legTopology.insert(bonds: insertedBonds)
  }
  
  // Transmute the corners to fluorine.
  do {
    let atomsToAtomsMap = legTopology.map(.atoms, to: .atoms)
    
    for atomID in legTopology.atoms.indices {
      let atomsMap = atomsToAtomsMap[atomID]
      if atomsMap.count == 1 {
        legTopology.atoms[atomID].atomicNumber = 9
      }
    }
  }
  
  // Add the remaining atoms.
  legTopology.atoms += [
    Entity(position: SIMD3(0.16, 0.10, 0.00), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.25, 0.15, 0.00), type: .atom(.nitrogen)),
    Entity(position: SIMD3(0.34, 0.10, 0.00), type: .atom(.hydrogen)),
    
    Entity(position: SIMD3(0.03, 0.56, 0.00), type: .atom(.hydrogen)),
    // Entity(position: SIMD3(0.45, 0.56, 0.00), type: .atom(.hydrogen)),
  ]
  
  // Instantiate the cage tooltip.
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .hydrogen
  cageTooltipDesc.frameworkType = .atrane(.silicon)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  try! cageTooltip.loadCachedValue()
  let angleDegreesZ: Float = 180
  
  // Remove the legs.
  cageTooltip.frameworkLegsBoundary[0][1] = .max
  cageTooltip.frameworkLegsBoundary[1][1] = .max
  cageTooltip.frameworkLegsBoundary[2][1] = .max
  cageTooltip.legs = []
  
  // Compile a topology out of the framework.
  var cageTopology = Topology()
  cageTopology.insert(atoms: cageTooltip.framework)
  cageTopology.insert(atoms: cageTooltip.apex)
  cageTopology.insert(atoms: cageTooltip.feedstock)
  
  // Add the bulk atom bonds.
  do {
    // adamantane(Ge) - 1.02-1.28 works
    //     atrane(Si) - 1.24-1.40 works
    //     atrane(Sn) - 1.11-1.41 works, N->Sn bond not always registered
    let matches = cageTopology.match(
      cageTopology.atoms, algorithm: .covalentBondLength(1.25))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in cageTopology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    cageTopology.insert(bonds: insertedBonds)
  }
  
  // Position and rotate the legs.
  var legs: [[Entity]] = []
  do {
    let nonbondingOrbitals = cageTopology
      .nonbondingOrbitals(hybridization: .sp3)
    
    // Iterate over the cage's atoms.
    for atomID in cageTopology.atoms.indices {
      let atom = cageTopology.atoms[atomID]
      guard atom.atomicNumber == 6, atom.position.y < -0.010 else {
        continue
      }
      
      // Select the dangling bond.
      let orbitalList = nonbondingOrbitals[atomID]
      guard orbitalList.count == 1 else {
        continue
      }
      let orbital = orbitalList.first!
      
      // Create the rotation around the Y axis.
      var rotationY: Quaternion<Float>
      do {
        // Extract the XZ component.
        var bondVectorXZ = orbital
        bondVectorXZ.y = .zero
        bondVectorXZ /= (bondVectorXZ * bondVectorXZ).sum().squareRoot()
        
        let orbitalAngle = Float.atan2(y: -bondVectorXZ.z, x: bondVectorXZ.x)
        let legAngle = -Float.pi
        rotationY = Quaternion<Float>(
          angle: orbitalAngle - legAngle, axis: SIMD3(0.00, 1.00, 0.00))
      }
      
      // Create the rotation around the X axis.
      var rotationX: Quaternion<Float>
      do {
        var direction = SIMD3<Float>(
          -Float(3.0 / 4).squareRoot(), -0.5, 0.00)
        direction = rotationY.act(on: direction)
        rotationX = createQuaternion(from: direction, to: orbital)
      }
      
      // Create the rotation around the Z axis.
      let rotationZ = Quaternion<Float>(
        angle: -angleDegreesZ * .pi / 180, axis: orbital)
      
      // Create the translation.
      var translatedOrigin: SIMD3<Float>
      var originalOrigin: SIMD3<Float>
      do {
        // 4 | 6 SIMD3<Float>(0.3675, 0.49507782, 0.0)
        let bondLength = 2 * Element.carbon.covalentRadius
        translatedOrigin = atom.position + bondLength * orbital
        originalOrigin = legTopology.atoms[4].position
      }
      
      // Add an array of the transformed atoms.
      var output: [Entity] = []
      for atomID in legTopology.atoms.indices {
        var atom = legTopology.atoms[atomID]
        atom.position -= originalOrigin
        atom.position = rotationY.act(on: atom.position)
        atom.position = rotationX.act(on: atom.position)
        atom.position = rotationZ.act(on: atom.position)
        atom.position += translatedOrigin
        output.append(atom)
      }
      legs.append(output)
    }
  }
  
  // Insert the new legs.
  guard legs.count == 3 else {
    fatalError("Unexpected leg count: \(legs.count)")
  }
  for legID in 0..<3 {
    let leg = legs[legID]
    
    // Connect the leg to the framework.
    let connectorID = cageTooltip.legs.count + 4
    var boundaryBond = cageTooltip.frameworkLegsBoundary[legID]
    boundaryBond[1] = UInt32(connectorID)
    cageTooltip.frameworkLegsBoundary[legID] = boundaryBond
    
    cageTooltip.legs += leg
  }
  
  var atoms: [Entity] = []
  atoms += cageTooltip.feedstock
  atoms += cageTooltip.apex
  atoms += cageTooltip.framework
  atoms += cageTooltip.legs
  
  return [atoms, minimize(atoms: atoms)]
}

// Utility function for making a quaternion from two vectors.
func createQuaternion(
  from start: SIMD3<Float>,
  to end: SIMD3<Float>
) -> Quaternion<Float> {
  func cross(
    _ _self: SIMD3<Float>,
    _ other: SIMD3<Float>
  ) -> SIMD3<Float> {
    let yzx = SIMD3<Int>(1,2,0)
    let zxy = SIMD3<Int>(2,0,1)
    return (_self[yzx] * other[zxy]) - (_self[zxy] * other[yzx])
  }
  
  // Source: https://stackoverflow.com/a/1171995
  let a = cross(start, end)
  let xyz = a
  let v1LengthSq = (start * start).sum()
  let v2LengthSq = (end * end).sum()
  let w = Float.sqrt(v1LengthSq * v2LengthSq) + (start * end).sum()
  let quaternion = Quaternion(real: w, imaginary: xyz)
  
  guard let normalized = quaternion.normalized else {
    fatalError("Could not normalize the quaternion.")
  }
  return normalized
}
#endif

#if false
// Estimated leg distances in pseudostannatrane (from central
// nitrogen atom to the nitrogen atom in each amine):
// - 4.18 angstroms for one ring
// - 3.49 or 6.31 angstroms for two rings
//
// How does this compare to the granularity of possible binding sites? For
// simplicity, use unreconstructed Si(111) and extrapolate the results to other
// silicon surfaces.
//
// Directly from the bridgehead silicon:
// 0.383 nm X
// 0.663 nm X
// 0.766 nm
// 1.012 nm
//
// Slightly off from the bridgehead silicon:
// 0.221 nm
// 0.442 nm X
// 0.585 nm X
// 0.798 nm
// 0.884 nm
// 0.963 nm
// 1.107 nm
func createGeometry() -> [Entity] {
  var surfaceModel = SurfaceModel(type: .silicon111)
  
  // Find the centermost atom.
  var minDistance: Float = .greatestFiniteMagnitude
  var minCandidateID: Int?
  for atomID in surfaceModel.surfaceAtomIDs {
    let atom = surfaceModel.topology.atoms[Int(atomID)]
    let position = atom.position
    let distance = (position * position).sum().squareRoot()
    if distance < minDistance {
      minDistance = distance
      minCandidateID = Int(atomID)
    }
  }
  guard let minCandidateID else {
    fatalError("Could not find a surface atom.")
  }
  
  // Set the origin to collect distances from.
  var originAtom = surfaceModel.topology.atoms[minCandidateID]
  originAtom.position += SIMD3(
    0.19157767,
    0.00,
    0.11059904)
  originAtom.atomicNumber = 8
  
  // Generate the distances.
  var distances: [Float] = []
  for atomID in surfaceModel.surfaceAtomIDs {
    let atom = surfaceModel.topology.atoms[Int(atomID)]
    guard atom.position.y > -0.05 else {
      continue
    }
    
    let delta = atom.position - originAtom.position
    let distance = (delta * delta).sum().squareRoot()
    if distance < 0.47 && distance > 0.30 {
      distances.append(distance)
      print(atom)
      surfaceModel.topology.atoms[Int(atomID)].atomicNumber = 16
    }
  }
  distances.sort()
  
  // Display the distances.
  for distance in distances {
    print(String(format: "%.3f", distance))
  }
  
  return surfaceModel.topology.atoms + [originAtom]
}
#endif

#if false
// Working on a pseudogermatrane framework with potentially multiple
// aromatic rings.
func createGeometry() -> [Entity] {
  let legLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 3 * h + 2 * h2k + 1 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 0.25 * l }
        Plane { l }
      }
      Convex {
        Origin { 1.5 * h2k }
        Plane { h2k }
      }
      Convex {
        Origin { 0.5 * (k - h) }
        Plane { k - h }
      }
      Convex {
        Origin { 1.0 * (k + h) }
        Plane { -k - h }
      }
      
      Concave {
        Convex {
          Origin { 1.4 * h }
          Plane { h }
        }
        Convex {
          Origin { 0.5 * h2k }
          Plane { -h2k }
        }
      }
      Convex {
        Origin { 0.3 * h2k }
        Plane { -h2k }
      }
      
      Replace { .empty }
    }
    
    Volume {
      Concave {
        Convex {
          Origin { 1.5 * h }
          Plane { -h }
        }
        Convex {
          Origin { 0.5 * h2k }
          Plane { -h2k }
        }
      }
      Convex {
        Origin { 0.5 * (k + 2 * h) }
        Plane { -k - 2 * h }
      }
      Replace { .atom(.nitrogen) }
    }
    
    Volume {
      Convex {
        Origin { 2 * (k + 2 * h) }
        Plane { k + 2 * h }
      }
      Replace { .atom(.oxygen) }
    }
    
    // Use the halogen as a marker.
    Volume {
      Convex {
        Origin { 0.0 * -k }
        Plane { -k }
      }
      Replace { .atom(.fluorine) }
    }
  }
  
  // Create a topology from the lattice.
  var topology = Topology()
  topology.insert(atoms: legLattice.atoms)
  
  // Flatten the atoms from hexagonal diamond to graphene.
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    atom.position.z = .zero
    topology.atoms[atomID] = atom
  }
  
  // Add the center-atom bonds.
  do {
    let matches = topology.match(
      topology.atoms,
      algorithm: .absoluteRadius(1.5 * 2 * Element.carbon.covalentRadius))
    
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
  
  // Minimize with the oxygen and fluorine anchored.
  topology.atoms = [
    Entity(position: SIMD3( 0.2770, 0.1582,  0.0000), type: .atom(.nitrogen)),
    Entity(position: SIMD3( 0.2793, 0.2951, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1580, 0.3680,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0362, 0.3061, -0.0000), type: .atom(.nitrogen)),
    Entity(position: SIMD3( 0.7567, 0.2912,  0.0000), type: .atom(.fluorine)),
    Entity(position: SIMD3( 0.5278, 0.3002, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.6448, 0.3682,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.6532, 0.5148, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.5229, 0.5764,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.4027, 0.5079, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.4012, 0.3651,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1611, 0.5088, -0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2788, 0.5773,  0.0000), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.7567, 0.5825,  0.0000), type: .atom(.oxygen)),
    Entity(position: SIMD3( 0.5347, 0.1924, -0.0000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5224, 0.6845,  0.0000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0668, 0.5615,  0.0000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2795, 0.6852,  0.0000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1915, 0.1063, -0.0000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3629, 0.1069, -0.0000), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0468, 0.3624, -0.0000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0257, 0.2065, -0.0000), type: .atom(.hydrogen)),
  ]
  
  // TODO: Position the three legs around a tin atom at (0.00, 0.00, 0.00).
  
  return topology.atoms
}
#endif
