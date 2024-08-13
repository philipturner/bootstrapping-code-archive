//
//  DC10cTooltip.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/1/24.
//

import HDL
import MM4
import Numerics

struct DC10cTooltip: MM4GenericPart {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    var topology = Self.createTopology(lattice: lattice)
    Self.addPentagons(topology: &topology)
    Self.removeNitrogenMarkers(topology: &topology)
    Self.addCrown(topology: &topology)
    Self.repassivate(topology: &topology)
    rigidBody = Self.createRigidBody(topology: topology)
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 10 * k + 10 * l }
      Material { .elemental(.carbon) }
      
      // Shape the bulk crystal part.
      Volume {
        // Cut out the pyramid of (111) planes.
        Convex {
          Origin { 5.0 * (h + l) + 4 * k }
          Plane { h + k + l }
        }
        Convex {
          Origin { 5 * h + 4 * k + 5 * l }
          Plane { -h + k - l }
        }
        Convex {
          Origin { 5 * h + 4.25 * k + 5 * l }
          Plane { h + k - l }
          Plane { -h + k + l }
        }
        
        // Truncate the bottom to match the image from NanoEngineer. This adds
        // an extra atomic layer, so the atoms won't be removed during surface
        // reconstruction.
        Convex {
          Origin { 0.25 * k }
          Plane { -k }
        }
        
        Replace { .empty }
      }
      
      // Cut out a valley for the tooltip structure, which deviates from the
      // tiling pattern in the bulk crystal.
      Volume {
        Convex {
          Origin { 3 * k }
          Plane { k }
        }
        Concave {
          Convex {
            Origin { 4.75 * (h + l) + 3 * k }
            Plane { h + l }
          }
          Convex {
            Origin { 5.25 * (h + l) + 3 * k }
            Plane { -h - l }
          }
          Convex {
            Origin { 2.75 * k }
            Plane { k }
          }
          Convex {
            Origin { 5 * (h + l) + 3 * k }
            Convex {
              Origin { 0.25 * (h - l) }
              Plane { h - l }
            }
            Convex {
              Origin { 0.25 * (-h + l) }
              Plane { -h + l }
            }
          }
        }
        
        Replace { .empty }
      }
      
      // Mark places where the manually positioned atoms will be attached.
      Volume {
        Concave {
          Convex {
            Origin { 2.5 * k }
            Plane { k }
          }
          Convex {
            Origin { 4.5 * (h + l) }
            Plane { h + l }
          }
          Convex {
            Origin { 5.5 * (h + l) }
            Plane { -h - l }
          }
          Convex {
            Origin { 5 * (h + l) }
            Convex {
              Origin { 0.5 * (h - l) }
              Plane { h - l }
            }
            Convex {
              Origin { 0.5 * (-h + l) }
              Plane { -h + l }
            }
          }
        }
        Replace { .atom(.germanium) }
      }
      Volume {
        Convex {
          Origin { 2.75 * k }
          Plane { k }
        }
        Replace { .atom(.germanium) }
      }
      Volume {
        Concave {
          Convex {
            Origin { 2.75 * k }
            Plane { k }
          }
          Convex {
            Origin { 5 * (h + l) }
            Origin { -0.5 * (h - l) }
            Plane { h - l }
          }
          Convex {
            Origin { 5 * (h + l) }
            Origin { -0.5 * (-h + l) }
            Plane { -h + l }
          }
        }
        Replace { .atom(.nitrogen) }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    // This tooltip only supports diamond lattices, for now.
    var reconstruction = Reconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
    var topology = reconstruction.topology
    
    // Remove hydrogens from the marker atoms.
    do {
      let atomsToBondsMap = topology.map(.atoms, to: .bonds)
      
      // Iterate over the atoms.
      var removedAtoms: [UInt32] = []
      for atomID in topology.atoms.indices {
        let atom = topology.atoms[atomID]
        guard atom.atomicNumber != 1, atom.atomicNumber != 6 else {
          continue
        }
        
        // Iterate over the bonds attached to this atom.
        for bondID in atomsToBondsMap[atomID] {
          let bond = topology.bonds[Int(bondID)]
          for laneID in 0..<2 {
            let bondMemberID = bond[laneID]
            let bondMember = topology.atoms[Int(bondMemberID)]
            guard bondMember.atomicNumber == 1 else {
              continue
            }
            removedAtoms.append(bondMemberID)
          }
        }
      }
      topology.remove(atoms: removedAtoms)
    }
    
    // Remove the bonds between nitrogen markers.
    do {
      var removedBonds: [UInt32] = []
      for bondID in topology.bonds.indices {
        let bond = topology.bonds[bondID]
        var allNitrogen = true
        for laneID in 0..<2 {
          let bondMemberID = bond[laneID]
          let bondMember = topology.atoms[Int(bondMemberID)]
          if bondMember.atomicNumber != 7 {
            allNitrogen = false
          }
        }
        if allNitrogen {
          removedBonds.append(UInt32(bondID))
        }
      }
      guard removedBonds.count == 1 else {
        fatalError("Unexpected number of N-N bonds.")
      }
      topology.remove(bonds: removedBonds)
    }
    
    return topology
  }
  
  static func createPentagon() -> Topology {
    // Initialize the pentagon.
    var atoms: [Entity] = []
    for atomID in 0..<5 {
      let angleDegrees = Float(atomID) * 72
      let angleRadians = angleDegrees * Float.pi / 180
      let rotation = Quaternion<Float>(angle: angleRadians, axis: [0, 0, 1])
      
      var direction = SIMD3<Float>(0, -1, 0)
      direction = rotation.act(on: direction)
      
      // Actual: 0.58778536 - (-0.5877852)
      // Desired: 0.15270 (sp3 distance)
      // Scale factor: 0.129894
      let position = direction * 0.129894
      let atom = Entity(position: position, type: .atom(.carbon))
      atoms.append(atom)
    }
    
    // Rescale the uppermost bond to match the sp2 distance from the paper.
    do {
      let position0 = atoms[0].position
      let position2 = atoms[2].position
      let delta = position2 - position0
      let hypotenuse = (delta * delta).sum().squareRoot()
      
      func tiltAngle(bondLength: Float) -> Float {
        let opposite = bondLength / 2
        let angleRadians = Float.asin(opposite / hypotenuse)
        return angleRadians
      }
      let currentAngle = tiltAngle(bondLength: 0.15270)
      let desiredAngle = tiltAngle(bondLength: 0.1323)
      let rotationAngle = (desiredAngle - currentAngle).magnitude
      
      for atomID in 1..<5 {
        var rotationAxis: SIMD3<Float>
        if atomID < 3 {
          rotationAxis = SIMD3(0, 0, 1)
        } else {
          rotationAxis = SIMD3(0, 0, -1)
        }
        let rotation = Quaternion<Float>(
          angle: rotationAngle, axis: rotationAxis)
        
        let atom0 = atoms[0]
        var atom = atoms[atomID]
        var originDelta = atom.position - atom0.position
        originDelta = rotation.act(on: originDelta)
        
        atom.position = atom0.position + originDelta
        atoms[atomID] = atom
      }
    }
    
    // Create a topology that stores the 5-member ring structure.
    var topology = Topology()
    topology.insert(atoms: atoms)
    topology.insert(bonds: [
      SIMD2<UInt32>(0, 1),
      SIMD2<UInt32>(1, 2),
      SIMD2<UInt32>(2, 3),
      SIMD2<UInt32>(3, 4),
      SIMD2<UInt32>(4, 0),
    ])
    return topology
  }
}

extension DC10cTooltip {
  // Adds one of the pentagons to the topology.
  //
  // The position is in number of diamond lattice unit cells.
  static func addPentagon(
    topology: inout Topology,
    position offset: SIMD3<Float>
  ) {
    let pentagonTopology = Self.createPentagon()
    
    // Shift the pentagon atoms into position.
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in pentagonTopology.atoms.indices {
      var atom = pentagonTopology.atoms[atomID]
      var position = atom.position
      
      let rotation = Quaternion<Float>(angle: .pi / 4, axis: [0, 1, 0])
      position = rotation.act(on: position)
      position += offset * 0.3567
      
      atom.position = position
      insertedAtoms.append(atom)
    }
    
    // Add the pentagon's bonds, adjusted for the new location of member atoms.
    for bondID in pentagonTopology.bonds.indices {
      var bond = pentagonTopology.bonds[bondID]
      let offset = topology.atoms.count
      bond &+= UInt32(offset)
      insertedBonds.append(bond)
    }
    
    // Connect with the nitrogen markers.
    for atomID in topology.atoms.indices {
      let nitrogen = topology.atoms[atomID]
      guard nitrogen.atomicNumber == 7 else {
        continue
      }
      
      let pentagonAtom = insertedAtoms[0]
      let delta = nitrogen.position - pentagonAtom.position
      let distance = (delta * delta).sum().squareRoot()
      guard distance < 2.1 * Element.carbon.covalentRadius else {
        continue
      }
      
      let pentagonAtomID = topology.atoms.count
      let bond = SIMD2(UInt32(atomID), UInt32(pentagonAtomID))
      insertedBonds.append(bond)
    }
    
    // TODO: Next, add a silicon atom for pentagon[1] and pentagon[4].
    func connectGeMarker(positionInPentagon: Int) {
      let carbon = insertedAtoms[positionInPentagon]
      let carbonID = topology.atoms.count + positionInPentagon
      
      // Iterate over the candidates for matching.
      for germaniumID in topology.atoms.indices {
        // Connecting with a germanium marker.
        var germanium = topology.atoms[germaniumID]
        guard germanium.atomicNumber == 32 else {
          continue
        }
        
        let delta = germanium.position - carbon.position
        let distance = (delta * delta).sum().squareRoot()
        guard distance < 0.35 else {
          continue
        }
        
        // Normalize the orbital.
        var orbital = delta
        orbital.y = 0
        orbital /= (orbital * orbital).sum().squareRoot()
        
        // Sink a little in the Y direction and renormalize.
        orbital.y -= 0.150
        orbital /= (orbital * orbital).sum().squareRoot()
        
        // Create the second carbon atom.
        let ccBondLength: Float = 0.162
        let carbonPosition2 = carbon.position + orbital * ccBondLength
        let carbon2 = Entity(position: carbonPosition2, type: .atom(.carbon))
        let carbonID2 = topology.atoms.count + insertedAtoms.count
        
        // Add the second carbon's topology.
        let ccBond = SIMD2(UInt32(carbonID), UInt32(carbonID2))
        let cGeBond = SIMD2(UInt32(carbonID2), UInt32(germaniumID))
        insertedAtoms.append(carbon2)
        insertedBonds.append(ccBond)
        insertedBonds.append(cGeBond)
        
        // Find a direction for the displacement.
        let direction110 = SIMD3<Float>(1, 0, 1) / Float(2).squareRoot()
        let magnitude110 = (orbital * direction110).sum()
        let sign110: Float = (magnitude110 > 0) ? 1 : -1
        let directionParallel = direction110 * sign110
        var directionPerp = orbital - magnitude110 * direction110
        directionPerp.y = .zero
        directionPerp /= (directionPerp * directionPerp).sum().squareRoot()
        
        // Displace the germanium marker to minimize strain.
        germanium.position += 0.030 * directionParallel
        germanium.position -= 0.010 * directionPerp
        germanium.atomicNumber = 6
        topology.atoms[germaniumID] = germanium
      }
    }
    connectGeMarker(positionInPentagon: 1)
    connectGeMarker(positionInPentagon: 4)
    
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  static func addPentagons(topology: inout Topology) {
    Self.addPentagon(
      topology: &topology, position: SIMD3(5.25, 3.6, 5.25))
    Self.addPentagon(
      topology: &topology, position: SIMD3(4.75, 3.6, 4.75))
  }
  
  // The germanium markers are used up at they are touched, because only a
  // single atom connects to these. The nitrogen markers need to be removed in
  // a dedicated pass.
  static func removeNitrogenMarkers(topology: inout Topology) {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 7 {
        atom.atomicNumber = 6
      }
      topology.atoms[atomID] = atom
    }
  }
  
  // Add ten atoms to the topology, which includes the carbon dimer.
  static func addCrown(topology: inout Topology) {
    let latticeConstant = Constant(.square) { .elemental(.carbon) }
    let origin = SIMD3<Float>(5, 4, 5) * latticeConstant
    let outwardDirection = SIMD3<Float>(1, 0, -1) / Float(2).squareRoot()
    
    // Move the germanium markers a bit inward.
    var germaniumLeftID: UInt32?
    var germaniumRightID: UInt32?
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      guard atom.atomicNumber == 32 else {
        continue
      }
      
      // Find a direction for the displacement.
      var delta = atom.position - origin
      delta.y = .zero
      delta /= (delta * delta).sum().squareRoot()
      
      // Displace the atom.
      atom.position -= 0.092 * delta
      topology.atoms[atomID] = atom
      
      if delta.x < 0 {
        germaniumLeftID = UInt32(atomID)
      } else {
        germaniumRightID = UInt32(atomID)
      }
    }
    guard let germaniumLeftID,
          let germaniumRightID else {
      fatalError("Could not locate germanium markers.")
    }
    
    // Creates an atom, offset by the specified coordinates in a 2D coordiante
    // system.
    func createAtom(coordinates: SIMD2<Float>) -> Entity {
      var position = origin
      position += coordinates.x * outwardDirection
      position += coordinates.y * SIMD3<Float>(0, 1, 0)
      return Entity(position: position, type: .atom(.carbon))
    }
    let insertedAtoms: [Entity] = [
      createAtom(coordinates: SIMD2(0.40, -0.30)),
      createAtom(coordinates: SIMD2(0.24, -0.20)),
      createAtom(coordinates: SIMD2(0.30, -0.04)),
      createAtom(coordinates: SIMD2(0.16, 0.05)),
      createAtom(coordinates: SIMD2(0.06, 0.17)),
      
      createAtom(coordinates: SIMD2(-0.06, 0.17)),
      createAtom(coordinates: SIMD2(-0.16, 0.05)),
      createAtom(coordinates: SIMD2(-0.30, -0.04)),
      createAtom(coordinates: SIMD2(-0.24, -0.20)),
      createAtom(coordinates: SIMD2(-0.40, -0.30)),
    ]
    
    let bondOffset = UInt32(topology.atoms.count)
    let insertedBonds: [SIMD2<UInt32>] = [
      // Left half of the crown.
      SIMD2(germaniumRightID, bondOffset + 0),
      SIMD2(bondOffset + 0, bondOffset + 1),
      SIMD2(bondOffset + 1, bondOffset + 2),
      SIMD2(bondOffset + 2, bondOffset + 3),
      SIMD2(bondOffset + 3, bondOffset + 4),
      SIMD2(bondOffset + 1, bondOffset - 13),
      SIMD2(bondOffset + 1, bondOffset - 6),
      SIMD2(bondOffset + 3, bondOffset - 12),
      SIMD2(bondOffset + 3, bondOffset - 5),
      
      // Acetylenic bond.
      SIMD2(bondOffset + 4, bondOffset + 5),
      
      // Right half of the crown.
      SIMD2(bondOffset + 5, bondOffset + 6),
      SIMD2(bondOffset + 6, bondOffset + 7),
      SIMD2(bondOffset + 7, bondOffset + 8),
      SIMD2(bondOffset + 8, bondOffset + 9),
      SIMD2(bondOffset + 9, germaniumLeftID),
      SIMD2(bondOffset + 6, bondOffset - 11),
      SIMD2(bondOffset + 6, bondOffset - 4),
      SIMD2(bondOffset + 8, bondOffset - 10),
      SIMD2(bondOffset + 8, bondOffset - 3),
    ]
    
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
    
    // Remove the germanium markers.
    topology.atoms[Int(germaniumLeftID)].atomicNumber = 6
    topology.atoms[Int(germaniumRightID)].atomicNumber = 6
  }
  
  // Removes the hydrogens and regenerates the surface passivation.
  static func repassivate(topology: inout Topology) {
    var removedAtoms: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == 1 {
        removedAtoms.append(UInt32(atomID))
      }
    }
    topology.remove(atoms: removedAtoms)
    
    // Fill the dangling bonds with hydrogens.
    do {
      let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
      
      var insertedAtoms: [Entity] = []
      var insertedBonds: [SIMD2<UInt32>] = []
      for atomID in topology.atoms.indices {
        let atom = topology.atoms[atomID]
        for orbital in orbitals[atomID] {
          guard case .atom(let element) = atom.type else {
            fatalError()
          }
          let bondLength = element.covalentRadius +
          Element.hydrogen.covalentRadius
          
          let hydrogenPosition = atom.position + orbital * bondLength
          let hydrogen = Entity(
            position: hydrogenPosition, type: .atom(.hydrogen))
          let hydrogenID = topology.atoms.count + insertedAtoms.count
          
          let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
          insertedAtoms.append(hydrogen)
          insertedBonds.append(bond)
        }
      }
      topology.insert(atoms: insertedAtoms)
      topology.insert(bonds: insertedBonds)
    }
    
    // Sort the topology for optimal performance. This step destroys the
    // information used to construct the crown's bonding topology.
    topology.sort()
  }
}

extension DC10cTooltip {
  static func createParameters(topology input: Topology) -> MM4Parameters {
    // Mark the topology to find important bonds and angles.
    var topology = input
    Self.markAtoms(topology: &topology)
    
    // Declare arrays for the marked bonds.
    var acetyleneBonds: [SIMD2<UInt32>] = []
    var ethyleneBonds: [SIMD2<UInt32>] = []
    var dimerApexBonds: [SIMD2<UInt32>] = []
    var bridgeApexBonds: [SIMD2<UInt32>] = []
    
    // Iterate over the bonds.
    for bondID in topology.bonds.indices {
      let bond = topology.bonds[bondID]
      var atomicNumbers: SIMD2<UInt8> = .zero
      for laneID in 0..<2 {
        let atomID = bond[laneID]
        let atom = topology.atoms[Int(atomID)]
        atomicNumbers[laneID] = atom.atomicNumber
      }
      
      if all(atomicNumbers .== 9) {
        acetyleneBonds.append(bond)
      } else if all(atomicNumbers .== 7) {
        ethyleneBonds.append(bond)
      } else if any(atomicNumbers .== 9) && any(atomicNumbers .== 8) {
        dimerApexBonds.append(bond)
      } else if any(atomicNumbers .== 8) && any(atomicNumbers .== 7) {
        bridgeApexBonds.append(bond)
      }
    }
    
    // Check that each important bond was recognized.
    guard acetyleneBonds.count == 1,
          ethyleneBonds.count == 2,
          dimerApexBonds.count == 2,
          bridgeApexBonds.count == 4 else {
      fatalError("Unexpected number of marked bonds.")
    }
    
    // Revert the changes to the atomic numbers.
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 7 ||
          atom.atomicNumber == 8 ||
          atom.atomicNumber == 9 {
        atom.atomicNumber = 6
      }
      topology.atoms[atomID] = atom
    }
    
    // Create the initial set of parameters.
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    // Edit the bond parameters.
    // - These parameters all come from the MM3 parameter file. The bond
    //   lengths in the DC10c paper look close to the MM3 parameters.
    for bond in acetyleneBonds {
      let bondID = parameters.bonds.map[bond]!
      var bondParameters = parameters.bonds.parameters[Int(bondID)]
      bondParameters.potentialWellDepth = 2.203
      bondParameters.stretchingStiffness = 15.250
      bondParameters.equilibriumLength = 1.2100
      parameters.bonds.parameters[Int(bondID)] = bondParameters
    }
    for bond in ethyleneBonds {
      let bondID = parameters.bonds.map[bond]!
      var bondParameters = parameters.bonds.parameters[Int(bondID)]
      bondParameters.potentialWellDepth = 1.602
      bondParameters.stretchingStiffness = 7.500
      bondParameters.equilibriumLength = 1.3320
      parameters.bonds.parameters[Int(bondID)] = bondParameters
    }
    for bond in dimerApexBonds {
      let bondID = parameters.bonds.map[bond]!
      var bondParameters = parameters.bonds.parameters[Int(bondID)]
      bondParameters.potentialWellDepth = 0.995
      bondParameters.stretchingStiffness = 5.500
      bondParameters.equilibriumLength = 1.4700
      parameters.bonds.parameters[Int(bondID)] = bondParameters
    }
    for bond in bridgeApexBonds {
      let bondID = parameters.bonds.map[bond]!
      var bondParameters = parameters.bonds.parameters[Int(bondID)]
      bondParameters.potentialWellDepth = 1.242
      bondParameters.stretchingStiffness = 6.300
      bondParameters.equilibriumLength = 1.4990
      parameters.bonds.parameters[Int(bondID)] = bondParameters
    }
    
    // Merges the two bonds into an angle, and sorts the indices within the
    // angle.
    func createAngle(
      bond1: SIMD2<UInt32>,
      bond2: SIMD2<UInt32>
    ) -> SIMD3<UInt32> {
      var sharedAtomID: UInt32
      if bond1[0] == bond2[0] {
        sharedAtomID = bond1[0]
      } else if bond1[0] == bond2[1] {
        sharedAtomID = bond1[0]
      } else if bond1[1] == bond2[0] {
        sharedAtomID = bond1[1]
      } else if bond1[1] == bond2[1] {
        sharedAtomID = bond1[1]
      } else {
        fatalError("The two bonds do not form an angle.")
      }
      
      var deflatedBond1 = bond1
      var deflatedBond2 = bond2
      deflatedBond1.replace(
        with: SIMD2.zero, where: deflatedBond1 .== sharedAtomID)
      deflatedBond2.replace(
        with: SIMD2.zero, where: deflatedBond2 .== sharedAtomID)
      var leftAtomID = deflatedBond1.wrappedSum()
      var rightAtomID = deflatedBond2.wrappedSum()
      
      // Sort the indices.
      if leftAtomID > rightAtomID {
        swap(&leftAtomID, &rightAtomID)
      }
      return SIMD3(leftAtomID, sharedAtomID, rightAtomID)
    }
    let angles: [SIMD3<UInt32>] = [
      createAngle(bond1: acetyleneBonds[0], bond2: dimerApexBonds[0]),
      createAngle(bond1: acetyleneBonds[0], bond2: dimerApexBonds[1]),
    ]
    
    // Edit the angle parameters.
    // - Changing the equilibrium angle from 109.5 degrees to 120 degrees. It
    //   is heavily warped from the electronic structure used to create the
    //   respective MM3 parameters.
    // - To avoid unexpected structural changes, I am not touching the angle
    //   parameters for the ethylene bonds. I think the structure will be close
    //   enough to the correct one, that GFN2-xTB will accept it during the
    //   ONIOM simulation.
    for angle in angles {
      let angleID = parameters.angles.map[angle]!
      var angleParameters = parameters.angles.parameters[Int(angleID)]
      angleParameters.equilibriumAngle = 120
      parameters.angles.parameters[Int(angleID)] = angleParameters
    }
    
    return parameters
  }
  
  // Mark the important atoms for parameter assignment.
  static func markAtoms(topology: inout Topology) {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      guard atom.atomicNumber == 6 else {
        continue
      }
      
      if atom.position.y > 1.5 {
        atom.atomicNumber = 9
      } else if atom.position.y > 1.45 {
        atom.atomicNumber = 8
      } else if atom.position.y > 1.35 {
        // Locate the origin.
        let latticeConstant = Constant(.square) { .elemental(.carbon) }
        let origin = SIMD3<Float>(5, 4, 5) * latticeConstant
        
        // Find how far this atom is from the origin.
        var delta = atom.position - origin
        delta.y = .zero
        let distance = (delta * delta).sum().squareRoot()
        
        // Only mark the four closest atoms.
        if distance < 0.25 {
          atom.atomicNumber = 7
        }
      }
      topology.atoms[atomID] = atom
    }
  }
  
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    let parameters = Self.createParameters(topology: topology)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}
