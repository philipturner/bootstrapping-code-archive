//
//  DiatraneTooltip.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/18/24.
//

import HDL
import Numerics

// TODO: Turn this into a distinct part. Make sure the rearrangement failure
// mode is fixed. Serialize some MD simulations of the crossbar reactive site
// picking up the moieties. (xTB level of theory, for ease of coding).
func createDiatrane(atom1: Element, atom2: Element) -> Topology {
  var topology = Topology()
  
  // Define the tilt angle.
  let angle2 = 5 * Float.pi / 180
  let rotation2 = Quaternion<Float>(angle: angle2, axis: [0, 0, 1])
  
  // Add the nitrogen and tin atoms.
  do {
    topology.insert(atoms: [
      Entity(position: SIMD3(-0.0000, -0.0060, -0.0000), type: .atom(.nitrogen)),
      Entity(position: SIMD3(-0.0000,  0.2528, -0.0000), type: .atom(.tin))
    ])
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position = rotation2.act(on: atom.position)
      topology.atoms[atomID] = atom
    }
  }
  
  // Add the ligands.
  do {
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for ligandID in 0..<3 {
      var ligand: [Entity] = [
        Entity(position: SIMD3(-0.1385, -0.0453, -0.0187), type: .atom(.carbon)),
        Entity(position: SIMD3(-0.2326,  0.0535,  0.0497), type: .atom(.carbon)),
        Entity(position: SIMD3(-0.2138,  0.1943, -0.0032), type: .atom(.carbon)),
      ]
      
      var angle1 = Float(ligandID) * 120 * .pi / 180
      if ligandID == 1 {
        angle1 = Float(2) * 120 * .pi / 180
      }
      let rotation1 = Quaternion<Float>(angle: angle1, axis: [0, 1, 0])
      
      for atomID in ligand.indices {
        var atom = ligand[atomID]
        atom.position = rotation1.act(on: atom.position)
        
        if atomID == 2 {
          if ligandID == 1 || ligandID == 2 {
            atom.atomicNumber = atom1.rawValue
          } else {
            atom.atomicNumber = atom2.rawValue
          }
        }
        if ligandID == 1 {
          atom.position.z = -atom.position.z
        }
        if ligandID >= 1 && atomID == 1 {
          atom.position.x -= 0.02
        }
        ligand[atomID] = atom
      }
      
      let startID = topology.atoms.count + insertedAtoms.count
      let bonds: [SIMD2<UInt32>] = [
        SIMD2(UInt32(0), UInt32(startID)),
        SIMD2(UInt32(startID), UInt32(startID + 1)),
        SIMD2(UInt32(startID + 1), UInt32(startID + 2)),
        SIMD2(UInt32(startID + 2), UInt32(1)),
      ]
      insertedAtoms += ligand
      insertedBonds += bonds
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Copy the structure across the YZ plane.
  do {
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in 0..<11 {
      var atom = topology.atoms[atomID]
            if atomID < 5 {
              atom.position += SIMD3(-0.14, 0.00, 0.00)
            } else if atomID < 8 {
              if atom.atomicNumber > 10 {
                atom.position += SIMD3(-0.20, 0.00, 0.05)
              } else {
                atom.position += SIMD3(-0.17, 0.00, 0.02)
              }
            } else if atomID < 11 {
              if atom.atomicNumber > 10 {
                atom.position += SIMD3(-0.20, 0.00, -0.05)
              } else {
                atom.position += SIMD3(-0.17, 0.00, -0.02)
              }
            } else {
              fatalError("Unexpected atom ID.")
            }
      

      topology.atoms[atomID] = atom
      
      atom.position.x = -atom.position.x
      atom.position.z = -atom.position.z
      insertedAtoms.append(atom)
    }
    for bond in topology.bonds {
      let newBond = bond &+ 11
      insertedBonds.append(newBond)
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Connect the two sides of the framework.
  // left:  [0, 1]
  //        [2, 3, 4] [5, 6, 7] [8, 9, 10]
  // right: [11, 12]
  //        [13, 14, 15] [16, 17, 18], [19, 20, 21]
  do {
    let insertedBonds: [SIMD2<UInt32>] = [
      SIMD2(5, 16), SIMD2(7, 18),
      SIMD2(8, 19), SIMD2(10, 21),
    ]
    topology.insert(bonds: insertedBonds)
  }
  
  // Add the hydrogens.
  //
  // There should be 19 hydrogens, bringing the total atom count to 30. Unless
  // the nitrogen has a hydrogen added.
  do {
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      
      // Include tin (50) to compile a hydrogen feedstock.
      let permittedAtomicNumbers: Set<UInt8> = [6, 14]
      guard permittedAtomicNumbers.contains(atom.atomicNumber) else {
        continue
      }
      
      for orbital in orbitals[atomID] {
        let element = Element(rawValue: atom.atomicNumber)!
        let bondLength = element.covalentRadius +
        Element.hydrogen.covalentRadius
        
        let hydrogenPosition = atom.position + bondLength * orbital
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
  
  do {
#if true
    // Add the hydrogen dimer.
    let insertedAtoms: [Entity] = [
      Entity(position: SIMD3( 0.160, 0.430, 0.000), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.160, 0.430, 0.000), type: .atom(.hydrogen)),
    ]
    topology.insert(atoms: insertedAtoms)
#elseif false
    // Add the carbon dimer.
    let insertedAtoms: [Entity] = [
      Entity(position: SIMD3( 0.060, 0.450, 0.000), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.060, 0.450, 0.000), type: .atom(.carbon)),
    ]
    topology.insert(atoms: insertedAtoms)
#elseif false
    // Add the carbon dimer (carbenic).
    let insertedAtoms: [Entity] = [
      Entity(position: SIMD3(0.000, 0.433, 0.000), type: .atom(.carbon)),
      Entity(position: SIMD3(0.000, 0.555, 0.000), type: .atom(.carbon)),
    ]
    topology.insert(atoms: insertedAtoms)
#elseif false
    // Add the boron dimer.
    let insertedAtoms: [Entity] = [
      Entity(position: SIMD3( 0.065, 0.470, 0.000), type: .atom(.boron)),
      Entity(position: SIMD3(-0.065, 0.470, 0.000), type: .atom(.boron)),
    ]
    topology.insert(atoms: insertedAtoms)
#elseif false
    // Add the phosphorus dimer.
    let insertedAtoms: [Entity] = [
      Entity(position: SIMD3( 0.080, 0.500, 0.000), type: .atom(.phosphorus)),
      Entity(position: SIMD3(-0.080, 0.500, 0.000), type: .atom(.phosphorus)),
    ]
    topology.insert(atoms: insertedAtoms)
#endif
  }
  
  return topology
}
