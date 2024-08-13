//
//  CrossbarTooltip+Fragments.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/6/24.
//

import HDL

// These functions assume the structure hasn't been energy minimized. In
// addition, they assume the material is elemental silicon and the reactive
// site is DCB6-Ge.
extension CrossbarTooltip {
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
  
  // Atom count: 24
  func detachReactiveSite() -> [UInt32] {
    // Extract the atoms from the rigid body.
    var atoms: [Entity] = []
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let atom = Entity(storage: storage)
      atoms.append(atom)
    }
    
    let dimerIDs = detachDimer()
    
    // Remove the atoms from the supporting lattice.
    var output: [UInt32] = []
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      if atom.atomicNumber == 1 {
        continue
      }
      if atom.atomicNumber == 14 {
        continue
      }
      if dimerIDs.contains(UInt32(atomID)) {
        continue
      }
      output.append(UInt32(atomID))
    }
    
    // Create a topology for matching hydrogens to included atoms.
    var topology = Topology()
    topology.insert(atoms: atoms)
    topology.insert(bonds: rigidBody.parameters.bonds.indices)
    
    do {
      let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
      let frameworkSet = Set(output)
      
      // Iterate over the atoms.
      for atomID in topology.atoms.indices {
        let atom = atoms[atomID]
        guard atom.atomicNumber == 1 else {
          continue
        }
        
        let atomsMap = atomsToAtomsMap[atomID]
        guard atomsMap.count == 1 else {
          fatalError("Unexpected neighbor count.")
        }
        let neighborID = atomsMap.first!
        guard frameworkSet.contains(neighborID) else {
          continue
        }
        output.append(UInt32(atomID))
      }
    }
    
    return output
  }
  
  // Atom count: 104
  func detachNearFramework() -> [UInt32] {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 20 * k + 10 * l }
      Material { .elemental(.silicon) }
      
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
      
      // Remove the atoms at the reactive site.
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
        Replace { .empty }
      }
      
      // Leave a few atomic layers around the reactive site, for accurate
      // vdW forces with the dimer.
      Volume {
        Convex {
          Origin { 8.5 * (h + k + l) }
          Origin { -5.5 * (h + l) }
          Plane { h - k + l }
        }
        Convex {
          Origin { 6 * (h + l) }
          Plane { h + l }
        }
        Convex {
          Origin { 11.5 * k }
          Plane { -h - k + l }
          Plane { h - k - l }
        }
        Replace { .empty }
      }
    }
    
    return detach(from: lattice)
  }
  
  // Atom count: 422
  func detachFarFramework() -> [UInt32] {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 20 * h + 20 * k + 20 * l }
      Material { .elemental(.silicon) }
      
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
      
      // Truncate the structure to only include the crossbar.
      Volume {
        Convex {
          Origin { 8.5 * (h + k + l) }
          Origin { -4 * (h + l) }
          Plane { h - k + l }
        }
        Replace { .empty }
      }
      
      // Remove the atoms in the near framework.
      Volume {
        Concave {
          Concave {
            Origin { 8.51 * (h + k + l) }
            Origin { -5.5 * (h + l) }
            Plane { -(h - k + l) }
          }
          Concave {
            Origin { 6.01 * (h + l) }
            Plane { -(h + l) }
          }
          Concave {
            Origin { 11.49 * k }
            Plane { -(-h - k + l) }
            Plane { -(h - k - l) }
          }
        }
        Replace { .empty }
      }
    }
    
    return detach(from: lattice)
  }
  
  // Detaches the atoms that overlap the lattice, and any bonded hydrogens.
  private func detach(
    from lattice: Lattice<Cubic>
  ) -> [UInt32] {
    // Create a topology for the lattice.
    var latticeTopology = Topology()
    latticeTopology.insert(atoms: lattice.atoms)
    
    // Copy the other half across the twinning fault.
    do {
      var insertedAtoms: [Entity] = []
      for atomID in latticeTopology.atoms.indices {
        var atom = latticeTopology.atoms[atomID]
        var position = atom.position
        
        let vector111 = SIMD3<Float>(
          1 / Float(3).squareRoot(),
          1 / Float(3).squareRoot(),
          1 / Float(3).squareRoot())
        var midPoint = Float(8.25) * Float(3).squareRoot()
        midPoint *= Constant(.square) { .elemental(.silicon) }
        
        // Increase the midpoint distance.
        do {
          let latticeConstant = Constant(.square) { .elemental(.silicon) }
          let bondLength = latticeConstant * Float(3).squareRoot() / 4
          midPoint -= bondLength / 2
        }
        
        let oldComponent111 = (position * vector111).sum()
        let newComponent111 = midPoint - (oldComponent111 - midPoint)
        position += (newComponent111 - oldComponent111) * vector111
        
        atom.position = position
        insertedAtoms.append(atom)
      }
      latticeTopology.insert(atoms: insertedAtoms)
    }
    
    // Extract the atoms from the rigid body.
    var rigidBodyAtoms: [Entity] = []
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let atom = Entity(storage: storage)
      rigidBodyAtoms.append(atom)
    }
    var rigidBodyTopology = Topology()
    rigidBodyTopology.insert(atoms: rigidBodyAtoms)
    rigidBodyTopology.insert(bonds: rigidBody.parameters.bonds.indices)
    
    var output: [UInt32] = []
    do {
      // Find the match(es) for every rigid body atom.
      let matches = latticeTopology.match(
        rigidBodyAtoms, algorithm: .absoluteRadius(0.010))
      let atomsToAtomsMap = rigidBodyTopology.map(.atoms, to: .atoms)
      
      // Iterate over the rigid body atoms.
      for atomID in rigidBodyAtoms.indices {
        let matchCount = matches[atomID].count
        guard matchCount == 1 else {
          continue
        }
        output.append(UInt32(atomID))
        
        // Iterate over the neighbors.
        let atomsMap = atomsToAtomsMap[atomID]
        for neighborID in atomsMap {
          let neighbor = rigidBodyTopology.atoms[Int(neighborID)]
          guard neighbor.atomicNumber == 1 else {
            continue
          }
          output.append(UInt32(neighborID))
        }
      }
    }
    
    // Check that the output is unique.
    do {
      let outputSet = Set(output)
      guard output.count == outputSet.count else {
        fatalError("Output atoms are not unique.")
      }
    }
    
    return output
  }
}
