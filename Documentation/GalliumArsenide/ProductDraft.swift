//
//  ProductDraft.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/4/24.
//

// Goal: Compile a structure, compile a build sequence, and find critical
// reactions within the sequence to test with various simulation methods.
// - Run through the build sequence once beforehand, using only intuition.
//   This requires less time than setting up a simulation.
// - Run an animation (just for yourself to see; not a production animation)
//   of all the atoms being placed in the correct order. And of the surface
//   passivation state during each step.
//
// Since the product is known beforehand, we can compile hierarchical data
// structures for easier ONIOM simulation. We'll still need an object akin
// to Silicon111Reaction for handling probe trajectories, but all the other
// setup becomes more workable.

func createGeometry() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 27 * h + 10 * k + 27 * l }
    Material { .elemental(.silicon) }
    
    Volume {
      // Create the rhombic cross-section.
      Convex {
        Origin { 9.75 * k }
        Plane { -h + k + l }
        Plane { h + k - l }
      }
      Convex {
        Origin { 0.00 * k }
        Plane { -h - k + l }
        Plane { h - k - l }
      }
      
      // Terminate the two ends. One of these ends will be connected to the
      // bulk lattice.
      Convex {
        Origin { 5 * l }
        Plane { -h - l }
      }
      Convex {
        Origin { 27 * h + 22 * l }
        Plane { h + l }
      }
      
      Replace { .empty }
    }
    
    // Mark the capping layers, which will be removed after surface
    // reconstruction. This is to permit primary atoms, which are deleted
    // during the reconstruction. It also marks where the left end will
    // connect to the bulk surface.
    Volume {
      Convex {
        Origin { 6 * l }
        Plane { -h - l }
      }
      Convex {
        Origin { 27 * h + 21 * l }
        Plane { h + l }
      }
      
      Replace { .atom(.germanium) }
    }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.material = .elemental(.silicon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  var topology = reconstruction.topology
  
  // Add new Si-H bonds at the surface.
  do {
    let bondsToAtomsMap = topology.map(.bonds, to: .atoms)
    
    // Iterate over the bonds.
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for bondID in topology.bonds.indices {
      let bondsMap = bondsToAtomsMap[bondID]
      var atomID1 = bondsMap[0]
      var atomID2 = bondsMap[1]
      var atom1 = topology.atoms[Int(atomID1)]
      var atom2 = topology.atoms[Int(atomID2)]
      
      // Check for a Si-Ge bond.
      var hasSilicon = false
      var hasGermanium = false
      for atom in [atom1, atom2] {
        if atom.atomicNumber == 14 {
          hasSilicon = true
        }
        if atom.atomicNumber == 32 {
          hasGermanium = true
        }
      }
      guard hasSilicon && hasGermanium else {
        continue
      }
      
      // Ensure the atoms are in the correct order.
      if atom1.atomicNumber == 32 {
        swap(&atomID1, &atomID2)
        swap(&atom1, &atom2)
      }
      
      // Ensure this is the rightward face.
      var orbital = atom2.position - atom1.position
      orbital /= (orbital * orbital).sum().squareRoot()
      guard orbital.x > 0, orbital.z > 0 else {
        continue
      }
      
      // Place the hydrogen.
      let hSiBondLength = Element.hydrogen.covalentRadius +
      Element.silicon.covalentRadius
      let hydrogenPosition = atom1.position + hSiBondLength * orbital
      let hydrogen = Entity(
        position: hydrogenPosition, type: .atom(.hydrogen))
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      
      // Link it to the silicon.
      let bond = SIMD2(UInt32(atomID1), UInt32(hydrogenID))
      insertedAtoms.append(hydrogen)
      insertedBonds.append(bond)
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Remove the Ge capping layers.
  do {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    // Iterate over the atoms.
    var removedAtoms: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == 32 {
        removedAtoms.append(UInt32(atomID))
      }
      guard atom.atomicNumber == 1 else {
        continue
      }
      
      // Check for a Ge-H bond.
      let atomsMap = atomsToAtomsMap[atomID]
      var hasGermanium = false
      for otherID in atomsMap {
        let otherAtom = topology.atoms[Int(otherID)]
        if otherAtom.atomicNumber == 32 {
          hasGermanium = true
        }
      }
      if hasGermanium {
        removedAtoms.append(UInt32(atomID))
      }
    }
    topology.remove(atoms: removedAtoms)
  }
  
  // TODO: Before rotating the part, compile the complementary surface.
  // Retain the hydrogens at the build site.
  
  return topology.atoms
}
