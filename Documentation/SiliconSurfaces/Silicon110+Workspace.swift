import Foundation
import MolecularRenderer
import HDL
import MM4
import Numerics
import QuartzCore
import xTB

func createGeometry() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 30 * h + 10 * k + 30 * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Concave {
        // Volume for the part.
        Convex {
          Origin { 10 * h + 10 * l }
          
          Convex {
            Origin { 5.25 * k }
            Origin { 1.00 * (h + k - l) }
            Plane { (h + k - l) }
          }
          Convex {
            Origin { 5.25 * k }
            Origin { 1.00 * (-h + k + l) }
            Plane { (-h + k + l) }
          }
          Convex {
            Origin { 5 * k }
            Origin { 1.00 * (h - k - l) }
            Plane { (h - k - l) }
          }
          Convex {
            Origin { 5 * k }
            Origin { 1.00 * (-h - k + l) }
            Plane { (-h - k + l) }
          }
          
          Convex {
            Origin { 5 * l }
            Plane { -h - l }
          }
          Convex {
            Origin { 12 * h + 17 * l }
            Plane { h + l }
          }
        }
        
        // Volume for the surface it's attached to.
        Convex {
          Convex {
            Origin { 12.5 * (h + l) }
            Plane { h + l }
          }
          Convex {
            Origin { 6 * l }
            Plane { -h + l }
          }
          Convex {
            Origin { 6 * h }
            Plane { h - l }
          }
          Convex {
            Origin { 9 * (h + l) }
            Plane { -h - l }
          }
        }
      }
      
      Replace { .empty }
    }
    
    // Highlight the atoms that will be passivated with a custom algorithm.
    // - Remove all bonds where both atoms are within this set, and the bond
    //   exceeds the natural bond distance.
    // - Remove all bonds between a hydrogen, and an atom in this set.
    // - Generate new hydrogens on all atoms with nonbonding orbitals.
    Volume {
      Concave {
        Convex {
          Origin { 11 * (h + l) }
          Plane { h + l }
        }
        Convex {
          Origin { -5 * l }
          Plane { -h + l }
        }
        Convex {
          Origin { -5 * h }
          Plane { h - l }
        }
        Convex {
          Origin { 9.5 * k }
          Plane { -k }
        }
        Convex {
          Origin { 1 * k }
          Plane { k }
        }
      }
      Replace { .atom(.germanium) }
    }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.material = .elemental(.silicon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  var topology = reconstruction.topology
  
  // Moves the atoms into position.
  func position(atoms: [Entity]) -> [Entity] {
    var output = atoms
    
    // Rotate the structure, so it points downward.
    let axis1 = SIMD3<Float>(1, 0, -1) / Float(2).squareRoot()
    let axis2 = SIMD3<Float>(-1, 0, -1) / Float(2).squareRoot()
    let axis3 = SIMD3<Float>(0, 1, 0)
    var surfaceDistance = Constant(.square) { .elemental(.silicon) }
    surfaceDistance *= 12.5 * Float(2).squareRoot()
    
    for atomID in output.indices {
      var atom = output[atomID]
      var position = atom.position
      position = SIMD3(
        (position * axis1).sum(),
        (position * axis2).sum(),
        (position * axis3).sum())
      position.y += surfaceDistance
      atom.position = position
      output[atomID] = atom
    }
    
    return output
  }
  topology.atoms = position(atoms: topology.atoms)
  
  // Remove all bonds that deviate from the repeating lattice position.
  do {
    let latticeConstant = Constant(.square) { .elemental(.silicon) }
    let idealBondLength = latticeConstant * Float(3).squareRoot() / 4
    
    var removedAtoms: [UInt32] = []
    var removedBonds: [UInt32] = []
    for bondID in topology.bonds.indices {
      let bond = topology.bonds[bondID]
      var hydrogenCount: Int = .zero
      var germaniumCount: Int = .zero
      var hydrogenID: UInt32?
      
      for laneID in 0..<2 {
        let atomID = bond[laneID]
        let atom = topology.atoms[Int(atomID)]
        if atom.atomicNumber == 1 {
          hydrogenCount += 1
          hydrogenID = UInt32(atomID)
        } else if atom.atomicNumber == 32 {
          germaniumCount += 1
        }
      }
      
      if germaniumCount == 2 {
        let atom1 = topology.atoms[Int(bond[0])]
        let atom2 = topology.atoms[Int(bond[1])]
        let delta = atom2.position - atom1.position
        let distance = (delta * delta).sum().squareRoot()
        
        // Only remove bonds whose length indicates they are 5-ring.
        let ratio = distance / idealBondLength
        if ratio > 1.3 {
          removedBonds.append(UInt32(bondID))
        }
      } else if hydrogenCount == 1, germaniumCount == 1 {
        removedAtoms.append(hydrogenID!)
      }
    }
    topology.remove(bonds: removedBonds)
    topology.remove(atoms: removedAtoms)
  }
  
  // Passivate the selected atoms.
  do {
    let nonbondingOrbitals = topology.nonbondingOrbitals()
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let silicon = topology.atoms[atomID]
      let hSiBondLength = Element.silicon.covalentRadius +
      Element.hydrogen.covalentRadius
      
      for orbital in nonbondingOrbitals[atomID] {
        let hydrogenPosition = silicon.position + hSiBondLength * orbital
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
  
  // Transmute the germaniums back into silicons.
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    if atom.atomicNumber == 32 {
      atom.atomicNumber = 14
    }
    topology.atoms[atomID] = atom
  }
  
  // Test the structure in MM4.
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  forceField.minimize(tolerance: 0.1)
  
  // Copy the minimized positions back to the topology.
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    atom.position = forceField.positions[atomID]
    topology.atoms[atomID] = atom
  }
  
  return topology.atoms
}
