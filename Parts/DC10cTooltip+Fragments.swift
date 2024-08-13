//
//  DC10cTooltip+Fragments.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/6/24.
//

import HDL

// These functions assume the structure hasn't been energy minimized.
extension DC10cTooltip {
  // Atom count: 2
  func detachDimer() -> [UInt32] {
    var output: [UInt32] = []
    for bondID in rigidBody.parameters.bonds.indices.indices {
      let parameters = rigidBody.parameters
      let bond = parameters.bonds.indices[bondID]
      let bondParameters = parameters.bonds.parameters[bondID]
      guard bondParameters.potentialWellDepth == 2.203  else {
        continue
      }
      
      for laneID in 0..<2 {
        let atomID = bond[laneID]
        output.append(atomID)
      }
    }
    return output
  }
  
  // Atom count: 21
  func detachReactiveSite() -> [UInt32] {
    var atoms: [Entity] = []
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let atom = Entity(storage: storage)
      atoms.append(atom)
    }
    
    // Remove the atoms from the supporting lattice.
    var output: [UInt32] = []
    for atomID in atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      
      switch atomicNumber {
      case 1:
        if position.y < 3.75 * 0.3567 {
          continue
        }
        // 4.00 for DC10c, 4.25 for H4-DC10c
        if position.y > 4 * 0.3567 {
          continue
        }
      case 6:
        let latticeConstant = Constant(.square) { .elemental(.carbon) }
        let origin = SIMD3<Float>(5, 4, 5) * latticeConstant
        if position.y < origin.y - 1.01 * latticeConstant {
          continue
        }
        
        let outwardDirection = SIMD3<Float>(1, 0, -1) / Float(2).squareRoot()
        let forwardDirection = SIMD3<Float>(1, 0, 1) / Float(2).squareRoot()
        let positionX = ((position - origin) * outwardDirection).sum()
        let positionZ = ((position - origin) * forwardDirection).sum()
        if positionX.magnitude > 1 * latticeConstant {
          continue
        }
        if positionZ.magnitude > 0.65 * latticeConstant {
          continue
        }
        
        // Remove the carbons in the dimer.
        if position.y > 4.25 * 0.3567 {
          continue
        }
      default:
        fatalError("This should never happen.")
      }
      output.append(UInt32(atomID))
    }
    return output
  }
  
  func detachMinimalLattice() -> [UInt32] {
    // DC10c: keep the truncated lattice atoms and all atoms that don't line up
    // with the full lattice
    func createLattice(truncated: Bool) -> Lattice<Cubic> {
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
          
          if truncated {
            // Truncate as much of the bottom as possible.
            Convex {
              Origin { 5.0 * (h + l) + 1.25 * k }
              Plane { h - k + l }
            }
            Convex {
              Origin { 5 * h + 1.25 * k + 5 * l }
              Plane { -h - k - l }
            }
            Convex {
              Origin { 5 * h + 1.5 * k + 5 * l }
              Plane { h - k - l }
              Plane { -h - k + l }
            }
          } else {
            Convex {
              Origin { 0.25 * k }
              Plane { -k }
            }
          }
          
          Replace { .empty }
        }
      }
    }
    
    func createTruncatedLatticeMatches() -> [Topology.MatchStorage] {
      // Create a topology.
      var topology = Topology()
      
      // Insert atoms into the topology.
      var insertedAtoms: [Entity] = []
      for atomID in rigidBody.parameters.atoms.indices {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let storage = SIMD4(position, Float(atomicNumber))
        let atom = Entity(storage: storage)
        insertedAtoms.append(atom)
      }
      topology.insert(atoms: insertedAtoms)
      
      // Create a truncated lattice.
      let truncatedLattice = createLattice(truncated: true)
      var truncatedLatticeTopology = Topology()
      truncatedLatticeTopology.insert(atoms: truncatedLattice.atoms)
      
      // Output of 'match' has same dimension as the function argument.
      let truncatedLatticeMatches = truncatedLatticeTopology.match(
        topology.atoms, algorithm: .absoluteRadius(0.100))
      return truncatedLatticeMatches
    }
    let truncatedLatticeMatches = createTruncatedLatticeMatches()
    
    // Find the output atom indices.
    var output: [UInt32] = []
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let matches = truncatedLatticeMatches[atomID]
      if position.y < 3 * 0.3567,
         matches.count == 0 {
        continue
      }
      
      switch atomicNumber {
      case 1:
        if position.y > 4 * 0.3567 {
          continue
        }
      case 6:
        // Remove the carbons in the dimer.
        if position.y > 4.25 * 0.3567 {
          continue
        }
      default:
        fatalError("This should never happen.")
      }
      
      output.append(UInt32(atomID))
    }
    return output
  }
  
  // Returns the entire lattice, except the part that is simulated quantum
  // mechanically.
  func detachFullLattice() -> [Entity] {
    var topology = Topology()
    
    do {
      // Copy the atoms from the rigid body to the topology.
      var insertedAtoms: [Entity] = []
      for atomID in rigidBody.parameters.atoms.indices {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let storage = SIMD4(position, Float(atomicNumber))
        let atom = Entity(storage: storage)
        insertedAtoms.append(atom)
      }
      topology.insert(atoms: insertedAtoms)
      topology.insert(bonds: rigidBody.parameters.bonds.indices)
    }
    
    do {
      // TODO: Fix this code.
      
//      let tooltipAtoms = detachReactiveSite()
//
//      // Incurring O(n^2) compute cost to make the code easier to write.
//      var removedAtoms: [UInt32] = []
//      for atomID in topology.atoms.indices {
//        let atom = topology.atoms[atomID]
//        var foundMatch = false
//        for tooltipAtom in tooltipAtoms {
//          let delta = atom.position - tooltipAtom.position
//          let distance = (delta * delta).sum().squareRoot()
//          if distance < 0.010 {
//            foundMatch = true
//            break
//          }
//        }
//        if foundMatch {
//          removedAtoms.append(UInt32(atomID))
//        }
//      }
//      topology.remove(atoms: removedAtoms)
    }
    
    return topology.atoms
  }
}
