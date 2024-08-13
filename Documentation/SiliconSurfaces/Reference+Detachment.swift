//
//  Reference+Detachment.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 7/5/24.
//

// Set up some MM4 simulations of nano-parts that detach intentionally.
// - Set up a cylindrical part.
// - Simulate in MM4 with some of the atoms placed way too far apart.
// - Simulate the broken parts interacting with other objects, without
//   crashing the simulator.

func createGeometry() -> [[Entity]] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 30 * h + 28 * k + 30 * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Concave {
        // Volume for the part.
        Convex {
          Origin { 10 * h + 10 * l }
          Origin { 18 * k }
          
          Convex {
            Origin { 4.75 * k }
            Origin { 1.00 * (h + k - l) }
            Plane { (h + k - l) }
          }
          Convex {
            Origin { 4.75 * k }
            Origin { 1.00 * (-h + k + l) }
            Plane { (-h + k + l) }
          }
          Convex {
            Origin { 5.5 * k }
            Origin { 1.00 * (h - k - l) }
            Plane { (h - k - l) }
          }
          Convex {
            Origin { 5.5 * k }
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
        
        // Volume for the enlarged end of the part.
        Convex {
          Origin { 10 * h + 10 * l }
          Origin { 18 * k }
          
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
            Origin { 8 * l }
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
            Origin { 5 * l }
            Plane { -h + l }
          }
          Convex {
            Origin { 5 * h }
            Plane { h - l }
          }
          Convex {
            Origin { 6 * (h + l) }
            Plane { -h - l }
          }
        }
      }
      
      Replace { .empty }
    }
  }
  
  var reconstruction = Reconstruction()
  reconstruction.material = .elemental(.silicon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  var topology = reconstruction.topology
  
  // Rotate the structure, so it points downward.
  do {
    let axis1 = SIMD3<Float>(1, 0, -1) / Float(2).squareRoot()
    let axis2 = SIMD3<Float>(-1, 0, -1) / Float(2).squareRoot()
    let axis3 = SIMD3<Float>(0, 1, 0)
    var surfaceDistance = Constant(.square) { .elemental(.silicon) }
    surfaceDistance *= 12.5 * Float(2).squareRoot()
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(
        (position * axis1).sum(),
        (position * axis2).sum(),
        (position * axis3).sum())
      position.y += surfaceDistance
      atom.position = position
      topology.atoms[atomID] = atom
    }
  }
  
  // Mark the anchors.
  do {
    let latticeConstant = Constant(.square) { .elemental(.silicon) }
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 14 {
        if atom.position.y > 8 * latticeConstant {
          atom.atomicNumber = 32
        }
      }
      topology.atoms[atomID] = atom
    }
  }
  
  // Mark the places where force will be exerted.
  do {
    let latticeConstant = Constant(.square) { .elemental(.silicon) }
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 14 {
        if atom.position.y < -15 * latticeConstant {
          atom.atomicNumber = 6
        }
      }
      topology.atoms[atomID] = atom
    }
  }
  
  // Recover the atom indices of the markers, them transmute back to Si.
  var anchorIDs: [UInt32] = []
  var handleIDs: [UInt32] = []
  for atomID in topology.atoms.indices {
    var atom = topology.atoms[atomID]
    if atom.atomicNumber == 32 {
      anchorIDs.append(UInt32(atomID))
    }
    if atom.atomicNumber == 6 {
      handleIDs.append(UInt32(atomID))
    }
    if atom.atomicNumber != 1 {
      atom.atomicNumber = 14
    }
    topology.atoms[atomID] = atom
  }
  
  // Energy-minimize the topology.
  do {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = parameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = topology.atoms.map(\.position)
    forceField.minimize(tolerance: 0.1)
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      let position = forceField.positions[atomID]
      atom.position = position
      topology.atoms[atomID] = atom
    }
  }
  
  // Set up the simulation where force is applied.
  var forceField: MM4ForceField
  do {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    for atomID in anchorIDs {
      parameters.atoms.masses[Int(atomID)] = 0
    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = parameters
    forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = topology.atoms.map(\.position)
  }
  
  // Utility function for setting the applied force.
  // - Parameter force: Magnitude of the force (in pN).
  //
  // The force is applied to the far end of the product.
  func setAppliedForce(_ appliedForce: Float) {
    let forcePerAtom = appliedForce / Float(handleIDs.count)
    
    // Set the external forces.
    var externalForces = [SIMD3<Float>](
      repeating: .zero, count: topology.atoms.count)
    for atomID in handleIDs {
      let force = SIMD3<Float>(0.00, 0.00, -forcePerAtom)
      externalForces[Int(atomID)] = force
    }
    forceField.externalForces = externalForces
  }
  
  // Allocate an array for the simulation frames.
  var frames: [[Entity]] = []
  
  // Break the simulation into segments.
  let segmentForces: [Float] = [
    300,
    1500,
    4000,
    8000,
    13000,
    16000,
    19000,
  ]
  for segmentForce in segmentForces {
    // Reset the atomic velocities and increase the force.
    forceField.velocities = Array(
      repeating: .zero, count: topology.atoms.count)
    setAppliedForce(segmentForce)
    
    // Run molecular dynamics.
    for frameID in 0..<200 {
      print("frame:", frameID)
      forceField.simulate(time: 0.100)
      
      for atomID in topology.atoms.indices {
        var atom = topology.atoms[atomID]
        let position = forceField.positions[atomID]
        atom.position = position
        topology.atoms[atomID] = atom
      }
      frames.append(topology.atoms)
    }
  }
  
  return frames
}
