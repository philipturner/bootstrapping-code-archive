//
//  CrossbarTooltip.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/2/24.
//

import HDL
import MM4

struct CrossbarTooltipDescriptor {
  // WARNING: Only C, SiC, and Si lattices are allowed. Others will produce
  // undefined behavior.
  var material: MaterialType?
}

struct CrossbarTooltip: MM4GenericPart {
  var rigidBody: MM4RigidBody
  
  init(descriptor: CrossbarTooltipDescriptor) {
    guard let material = descriptor.material else {
      fatalError("Descriptor was incomplete.")
    }
    
    let lattice = Self.createLattice(material: material)
    let topology = Self.createTopology(lattice: lattice, material: material)
    rigidBody = Self.createRigidBody(topology: topology)
  }
  
  static func createLattice(
    material: MaterialType
  ) -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 20 * h + 20 * k + 20 * l }
      Material { material }
      
      // The two (110) directions, where the structure is symmetric.
      let symmetryDirections: [SIMD3<Float>] = [
        -h + l,
         h - l,
      ]
      
      // Compile the bulk shape.
      Volume {
        // Slice off the interface along the (111) twinning fault.
        Convex {
          Origin { 8.25 * (h + k + l) }
          Plane { -h - k - l }
        }
        
        // Create walls on all four sides.
        Convex {
          Origin { 10.5 * (h + k + l) }
          Plane { h + k + l }
        }
        Convex {
          Origin { 2.75 * (-h + l) }
          Plane { -h + l }
        }
        Convex {
          Origin { 2.75 * (h - l) }
          Plane { h - l }
        }
        
        // Slice off the top and bottom.
        Convex {
          Origin { 3.5 * (-h + 2 * k - l) }
          Plane { -h + 2 * k - l }
        }
        Convex {
          Origin { 2.35 * (h - 2 * k + l) }
          Plane { h - 2 * k + l }
        }
        
        Replace { .empty }
      }
      
      // Compile the tip structure.
      Volume {
        // Create the valley for the crossbar.
        Concave {
          Convex {
            Origin { 8.5 * (h + k + l) }
            Plane { h + k + l }
          }
          Convex {
            // (111) surface chiseled by (110), very hard to spot.
            Origin { 15.5 * k }
            Plane { -h + k + l }
            Plane { h + k - l }
            for direction in symmetryDirections {
              Convex {
                Origin { 0.5 * direction }
                Plane { direction }
              }
            }
          }
          Convex {
            Origin { 0.5 * (h + l) }
            Plane { -h + k - l }
          }
        }
        
        // Create the thinner second beam.
        for direction in symmetryDirections {
          Convex {
            Origin { 10.5 * k }
            Plane { (-h + 2 * k - l) + direction }
          }
          Convex {
            Origin { 6.75 * k }
            Origin { 2.75 * direction }
            Plane { SIMD3<Float>(-h + 2 * k - l) + 3 * direction }
          }
        }
        
        Replace { .empty }
      }
      
      // Ensure the atoms touching the germanium are always carbon. We do this
      // both for structural stability and ease of parameterization.
      Volume {
        Concave {
          Convex {
            Origin { 4 * k }
            Plane { -h + k - l }
          }
          
          for direction in symmetryDirections {
            // Later, we might use this highlighting code to place four O or
            // S dopants on the tooltip.
            Convex {
              Origin { 0.75 * direction }
              Plane { -direction }
            }
          }
        }
        Replace { .atom(.carbon) }
      }
      
      // Mark the reactive site atom with germanium. That way, it won't be
      // confused with silicon in alternative bulk materials.
      Volume {
        Concave {
          Convex {
            Origin { 1.65 * (-h + k - l) }
            Plane { -h + k - l }
          }
          Convex {
            Origin { 1.75 * (-h + k - l) }
            Plane { h - k + l }
          }
          Convex {
            Origin { 0.25 * (-h + l) }
            Plane { h - l }
          }
          Convex {
            Origin { 0.25 * (h - l) }
            Plane { -h + l }
          }
        }
        
        Replace { .atom(.germanium) }
      }
    }
  }
  
  static func createTopology(
    lattice: Lattice<Cubic>,
    material: MaterialType
  ) -> Topology {
    var topology = Topology()
    topology.insert(atoms: lattice.atoms)
    
    var insertedAtoms: [Entity] = []
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      
      let vector111 = SIMD3<Float>(
        1 / Float(3).squareRoot(),
        1 / Float(3).squareRoot(),
        1 / Float(3).squareRoot())
      var midPoint = Float(8.25) * Float(3).squareRoot()
      midPoint *= Constant(.square) { material }
      
      // Choose from either carbon or silicon.
      var bridgingElement: Element
      do {
        switch material {
        case .elemental(.carbon), .checkerboard(_, .carbon):
          bridgingElement = .carbon
        case .elemental(.silicon), .checkerboard(.carbon, .silicon):
          bridgingElement = .silicon
        case .elemental(.germanium), .checkerboard(.carbon, .germanium):
          bridgingElement = .germanium
        default:
          fatalError("Unrecognized material.")
        }
      }
      
      // Increase the midpoint distance.
      do {
        let latticeConstant = Constant(.square) { .elemental(bridgingElement) }
        let bondLength = latticeConstant * Float(3).squareRoot() / 4
        midPoint -= bondLength / 2
      }
      
      let oldComponent111 = (position * vector111).sum()
      let newComponent111 = midPoint - (oldComponent111 - midPoint)
      position += (newComponent111 - oldComponent111) * vector111
      
      atom.position = position
      insertedAtoms.append(atom)
    }
    topology.insert(atoms: insertedAtoms)
    
    return passivate(topology: topology, material: material)
  }
  
  private static func passivate(
    topology input: Topology, 
    material: MaterialType
  ) -> Topology {
    var topology = input
    
    // Find the bulk atom bonds.
    do {
      // covalent bond scale | too few bonds | too many bonds |
      // ------------------- | ------------- | -------------- |
      //          C, DCB6-Ge | 1.01-1.02     | 1.07-1.08      |
      //        GeC, DCB6-Ge | 1.01-1.02     | 1.18-1.19      |
      //         Si, DCB6-Ge | 1.3           | -              |
      
      let latticeConstant = Constant(.square) { material }
      let bondLength = latticeConstant * Float(3).squareRoot() / 4
      let matches = topology.match(
        topology.atoms, algorithm: .absoluteRadius(1.3 * bondLength))
      
      var insertedBonds: [SIMD2<UInt32>] = []
      for i in topology.atoms.indices {
        for j in matches[i] where i < j {
          let bond = SIMD2(UInt32(i), j)
          insertedBonds.append(bond)
        }
      }
      topology.insert(bonds: insertedBonds)
    }
    
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
    
    // Reorder the atoms for efficiency when simulating in MM4. This destroys
    // all potential marker data except the state of being Ge.
    topology.sort()
    return topology
  }
  
  // Create parameters for an MM4 simulation that will (hopefully) precondition
  // a GFN-FF simulation with many non-carbon elements.
  static func createParameters(topology: Topology) -> MM4Parameters {
    func createParameters(transmute: (inout UInt8) -> Void) -> MM4Parameters {
      var atomicNumbers: [UInt8] = []
      for atom in topology.atoms {
        var atomicNumber = atom.atomicNumber
        transmute(&atomicNumber)
        atomicNumbers.append(atomicNumber)
      }
      
      var paramsDesc = MM4ParametersDescriptor()
      paramsDesc.atomicNumbers = atomicNumbers
      paramsDesc.bonds = topology.bonds
      return try! MM4Parameters(descriptor: paramsDesc)
    }
    
    let allSiliconParameters = createParameters { Z in
      if Z == 32 {
        Z = 14
      }
    }
    let allGermaniumParameters = createParameters { Z in
      if Z == 14 {
        Z = 32
      }
    }
    let maskedSiliconParameters = createParameters { Z in
      if Z == 32 {
        Z = 6
      }
    }
    let maskedGermaniumParameters = createParameters { Z in
      if Z == 14 {
        Z = 6
      }
    }
    
    // Start with the parameters for silicon. If the lattice is SiC or Si,
    // then the parameterization of Si will dominate the behavior.
    var output = allSiliconParameters
    
    // Correct the atom parameters.
    var totalCharge: Double = .zero
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let siliconParameters = maskedSiliconParameters
        .atoms.parameters[atomID]
      let germaniumParameters = maskedGermaniumParameters
        .atoms.parameters[atomID]
      
      var atomParameters = allSiliconParameters.atoms.parameters[atomID]
      if atom.atomicNumber == 32 {
        atomParameters = germaniumParameters
      }
      
      // Find the correct partial charge.
      atomParameters.charge = .zero
      atomParameters.charge += siliconParameters.charge
      atomParameters.charge += germaniumParameters.charge
      totalCharge += Double(atomParameters.charge)
      
      // Write the new parameters.
      output.atoms.parameters[atomID] = atomParameters
      
      // Second, correct the atomic number.
      let atomicNumber = topology.atoms[atomID].atomicNumber
      let previousAtomicNumber = output.atoms.atomicNumbers[atomID]
      output.atoms.atomicNumbers[atomID] = atomicNumber
      
      // Third, correct the atomic mass.
      func createMass(atomicNumber: UInt8) -> Float {
        switch atomicNumber {
        case 1: return 1.008
        case 6: return 12.011
        case 7: return 14.007
        case 8: return 15.999
        case 9: return 18.9984031636
        case 14: return 28.085
        case 15: return 30.9737619985
        case 16: return 32.06
        case 32: return 72.6308
        default:
          fatalError("Unrecognized atomic number: \(atomicNumber)")
        }
      }
      let previousMass = createMass(atomicNumber: previousAtomicNumber)
      let actualMass = createMass(atomicNumber: atomicNumber)
      output.atoms.masses[atomID] += actualMass - previousMass
    }
    guard totalCharge.magnitude < 0.01 else {
      fatalError("Charge was not conserved.")
    }
    
    // Correct the bond parameters.
    let bondsToAtomsMap = topology.map(.bonds, to: .atoms)
    for bondID in topology.bonds.indices {
      // Determine which non-carbon atom this bond contains.
      let atomsMap = bondsToAtomsMap[bondID]
      var hasSilicon = false
      var hasGermanium = false
      for atomID in atomsMap {
        let atom = topology.atoms[Int(atomID)]
        let atomicNumber = atom.atomicNumber
        if atomicNumber == 14 {
          hasSilicon = true
        } else if atomicNumber == 32 {
          hasGermanium = true
        }
      }
      if hasSilicon && hasGermanium {
        fatalError("This should never happen.")
      }
      
      // If it is germanium, overwrite the all-Si params with all-Ge params.
      var bondParameters = allSiliconParameters
        .bonds.parameters[bondID]
      var extendedParameters = allSiliconParameters
        .bonds.extendedParameters[bondID]
      if hasGermanium {
        bondParameters = allGermaniumParameters
          .bonds.parameters[bondID]
        extendedParameters = allGermaniumParameters
          .bonds.extendedParameters[bondID]
      }
      
      // Write the new parameters.
      output.bonds.parameters[bondID] = bondParameters
      output.bonds.extendedParameters[bondID] = extendedParameters
    }
    
    // Correct the angle parameters.
    for angleID in output.angles.indices.indices {
      let angle = output.angles.indices[angleID]
      
      // Fetch the atomic numbers of each atom.
      var atomicNumbers: SIMD3<UInt8> = .zero
      for laneID in 0..<3 {
        let atomID = angle[laneID]
        let atom = topology.atoms[Int(atomID)]
        atomicNumbers[laneID] = atom.atomicNumber
      }
      
      // Truth table:
      //
      // [ 1,  6,  1] -> X
      // [ 1,  6,  6] -> X
      // [ 1,  6, 14] -> same
      // [ 1,  6, 32] -> same
      // [ 1, 14,  1] -> same
      // [ 1, 14,  6] -> same
      // [ 1, 14, 14] -> same
      // [ 1, 14, 32] -> ???
      // [ 1, 32,  1] -> same
      // [ 1, 32,  6] -> same
      // [ 1, 32, 14] -> ???
      // [ 1, 32, 32] -> same
      //
      // [ 6,  6,  1] -> X
      // [ 6,  6,  6] -> X
      // [ 6,  6, 14] -> same
      // [ 6,  6, 32] -> same
      // [ 6, 14,  1] -> same
      // [ 6, 14,  6] -> same
      // [ 6, 14, 14] -> same
      // [ 6, 14, 32] -> ???
      // [ 6, 32,  1] -> same
      // [ 6, 32,  6] -> same
      // [ 6, 32, 14] -> ???
      // [ 6, 32, 32] -> same
      //
      // [14,  6,  1] -> same
      // [14,  6,  6] -> same
      // [14,  6, 14] -> same
      // [14,  6, 32] -> ???
      // [14, 14,  1] -> same
      // [14, 14,  6] -> same
      // [14, 14, 14] -> same
      // [14, 14, 32] -> ???
      // [14, 32,  1] -> ???
      // [14, 32,  6] -> ???
      // [14, 32, 14] -> ???
      // [14, 32, 32] -> ???
      //
      // [32,  6,  1] -> same
      // [32,  6,  6] -> same
      // [32,  6, 14] -> ???
      // [32,  6, 32] -> same
      // [32, 14,  1] -> ???
      // [32, 14,  6] -> ???
      // [32, 14, 14] -> ???
      // [32, 14, 32] -> ???
      // [32, 32,  1] -> same
      // [32, 32,  6] -> same
      // [32, 32, 14] -> ???
      // [32, 32, 32] -> same
      //
      // Reduced truth table:
      //
      // [ 1, 14, 32], [32, 14,  1] -> choose Si
      // [ 1, 32, 14], [14, 32,  1] -> choose Ge
      // [ 6, 14, 32], [32, 14,  6] -> choose Si
      // [ 6, 32, 14], [14, 32,  6] -> choose Ge
      // [14,  6, 32], [32,  6, 14] -> no difference between Si and Ge
      // [14, 14, 32], [32, 14, 14] -> choose Si
      // [14, 32, 14] -> choose Ge
      // [14, 32, 32], [32, 32, 14] -> choose Ge
      // [32, 14, 32] -> choose Si
      //
      // Optimized form of the logic:
      //
      // If no Si or Ge exist,        do not modify.
      // If only Si or only Ge exist, overwrite with the element that exists.
      // Otherwise,
      //   If the center is C,          overwrite with the Si parameters.
      //   Otherwise, choose parameters that match the central atom.
      
      let hasSilicon = any(atomicNumbers .== 14)
      let hasGermanium = any(atomicNumbers .== 32)
      if !hasSilicon && !hasGermanium {
        continue
      }
      
      var angleParameters: MM4AngleParameters
      let siAngleParameters = allSiliconParameters.angles.parameters[angleID]
      let geAngleParameters = allGermaniumParameters.angles.parameters[angleID]
      
      if hasSilicon != hasGermanium {
        if hasSilicon {
          angleParameters = siAngleParameters
        } else if hasGermanium {
          angleParameters = geAngleParameters
        } else {
          fatalError("This should never happen.")
        }
      } else {
        if atomicNumbers[1] == 6 {
          angleParameters = siAngleParameters
        } else {
          fatalError("This should never happen with the permitted materials.")
        }
      }
      
      // Write the new parameters.
      output.angles.parameters[angleID] = angleParameters
    }
    
    // Locate the dimer carbons with logic on the bonding topology.
    //
    // This rule means Ge and GeC lattices will produce undefined behavior. It
    // is why the structure only accepts C, SiC, and Si lattices.
    var dimerCarbonIDs: [UInt32] = []
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let atomsMap = atomsToAtomsMap[atomID]
      guard atom.atomicNumber == 6 else {
        continue
      }
      
      let centerType = output.atoms.centerTypes[atomID]
      guard centerType == .secondary else {
        continue
      }
      
      var hasSecondary = false
      var hasGermanium = false
      for neighborAtomID in atomsMap {
        let neighborAtom = topology.atoms[Int(neighborAtomID)]
        let neighborAtomicNumber = neighborAtom.atomicNumber
        if neighborAtomicNumber == 32 {
          hasGermanium = true
        }
        
        // We assume a neighbor can't be both Ge and secondary.
        let neighborCenterType = output.atoms.centerTypes[Int(neighborAtomID)]
        if neighborCenterType == .secondary {
          hasSecondary = true
        }
      }
      
      if hasSecondary && hasGermanium {
        dimerCarbonIDs.append(UInt32(atomID))
      }
    }
    
    if dimerCarbonIDs.count > 0 {
      guard dimerCarbonIDs.count == 2 else {
        fatalError("Could not find dimer carbons.")
      }
      
      // Correct the bond lengths for the carbons in the dimer.
      for atomID in dimerCarbonIDs {
        let atomsMap = atomsToAtomsMap[Int(atomID)]
        for neighborAtomID in atomsMap {
          let bond12 = SIMD2(atomID, neighborAtomID)
          let bond21 = SIMD2(neighborAtomID, atomID)
          let bond = (atomID < neighborAtomID) ? bond12 : bond21
          let bondID = output.bonds.map[bond]
          guard let bondID else {
            fatalError("Could not locate bond.")
          }
          
          let neighborAtom = topology.atoms[Int(neighborAtomID)]
          let neighborAtomicNumber = neighborAtom.atomicNumber
          var bondParameters = output.bonds.parameters[Int(bondID)]
          
          // Shrink the Ge-C and C=C bonds.
          if neighborAtomicNumber == 32 {
            // C CSP2 alkene (2), Ge germanium (31)
            // 3.580,1.935,,,0.745,
            bondParameters.potentialWellDepth = 0.745
            bondParameters.stretchingStiffness = 3.580
            bondParameters.equilibriumLength = 1.9350
          } else if neighborAtomicNumber == 6 {
            // C CSP alkyne (4),C CSP alkyne (4)
            // 15.250,1.210,,,2.203
            bondParameters.potentialWellDepth = 2.203
            bondParameters.stretchingStiffness = 15.250
            bondParameters.equilibriumLength = 1.210
          }
          output.bonds.parameters[Int(bondID)] = bondParameters
        }
      }
    }
    
    return output
  }
  
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    let parameters = Self.createParameters(topology: topology)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}
