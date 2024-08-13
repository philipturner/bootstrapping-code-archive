//
//  CageBindingSite.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/5/24.
//

import HDL

struct CageBindingSite {
  
}

#if false

// Design custom tripods for the Si(110) surface. Before doing so, there are
// some precursors.
//
// Tasks (Compilation):
// - Make your own legs from the start, instead of relying on CBN's ones.
//   - Restrict to adamantane, directly after compilation, for simplicity.
// - Simulation:
//   - Energy-minimize with xTB.
//   - Run high-temperature molecular dynamics with GFN-FF.
// - Formulate into a workable data structure, which encapsulates the
//   cage-surface system.
//   - Repurpose the code for atranes.
//   - Add caching.
//
// TODO: Reformulate the existing code into a data structure, to make it
// workable to select anchors. It doesn't need to be retained in the
// codebase long-term. It only needs to ease the process of running this
// experiment.
//
func createGeometry() -> [Entity] {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 10 * k + 10 * l }
    Material { .elemental(.silicon) }
    
    // Cut out the shape.
    Volume {
      Convex {
        Origin { 10 * k }
        Plane { k + l }
      }
      Convex {
        Origin { 5 * k }
        Plane { k - l }
      }
      Convex {
        Origin { 5 * k }
        Plane { -k - l }
      }
      Convex {
        Origin { 5 * l }
        Plane { -k + l }
      }
      Replace { .empty }
    }
    
    // Highlight atoms for simulation with xTB and GFN-FF.
    Volume {
      Concave {
        Convex {
          Origin { 1.5 * k }
          Plane { -k + l }
        }
        Convex {
          Origin { 9.5 * k }
          Plane { k + l }
        }
        Convex {
          Origin { 2 * l }
          Plane { k - l }
        }
        
        Convex {
          Origin { 4 * h }
          Plane { h }
        }
        Convex {
          Origin { 6.5 * h }
          Plane { -h }
        }
      }
      
      Replace { .atom(.germanium) }
    }
  }
  
  // Add hydrogen passivation to the compiled model.
  var reconstruction = Reconstruction()
  reconstruction.material = .elemental(.silicon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  var surfaceTopology = reconstruction.topology
  
  // Create the tripod.
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .radical
  cageTooltipDesc.frameworkType = .adamantane(.carbon)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  
  // Rotate and translate the tripod.
  do {
    let angle: Float = 45 * .pi / 180
    let axis = SIMD3<Float>(1, 0, 0)
    cageTooltip.rotate(angle: angle, axis: axis)
  }
  do {
    let latticeConstant = Constant(.square) { .elemental(.silicon) }
    let translation = SIMD3<Float>(5.1, 5.9, 5.9) * latticeConstant
    cageTooltip.translate(offset: translation)
  }
  
  // Swap out the legs, and remove the hydrogens they bond to.
  do {
    let atomsToAtomsMap = surfaceTopology.map(.atoms, to: .atoms)
    
    var removedAtoms: [UInt32] = []
    for legID in 0..<3 {
      // Fetch the upper leg carbon.
      let upperCarbon = cageTooltip.legs[5 * legID + 2]
      
      // Project out an atom position for searching.
      let searchDirection = SIMD3<Float>(0, -1, -1) / Float(2).squareRoot()
      let searchPosition = upperCarbon.position + 0.25 * searchDirection
      
      // Find the closest hydrogen on the surface.
      var closestDistance: Float = .greatestFiniteMagnitude
      var closestAtomID: UInt32?
      for surfaceAtomID in surfaceTopology.atoms.indices {
        let surfaceAtom = surfaceTopology.atoms[surfaceAtomID]
        guard surfaceAtom.atomicNumber == 1 else {
          continue
        }
        
        let delta = surfaceAtom.position - searchPosition
        let distance = (delta * delta).sum().squareRoot()
        if distance < closestDistance {
          closestDistance = distance
          closestAtomID = UInt32(surfaceAtomID)
        }
      }
      guard let hydrogenID = closestAtomID else {
        fatalError("Could not locate a surface atom.")
      }
      removedAtoms.append(UInt32(hydrogenID))
      
      // Find its corresponding silicon.
      let hydrogenAtomsMap = atomsToAtomsMap[Int(hydrogenID)]
      guard hydrogenAtomsMap.count == 1 else {
        fatalError("Unexpected bonding topology at the surface.")
      }
      let siliconID = hydrogenAtomsMap.first!
      let silicon = surfaceTopology.atoms[Int(siliconID)]
      
      // Change the direction to point toward that silicon.
      var newDirection = silicon.position - upperCarbon.position
      newDirection /= (newDirection * newDirection).sum().squareRoot()
      
      // Regenerate the atom positions.
      var carbonPosition1 = upperCarbon.position
      carbonPosition1 += newDirection * 0.140
      let carbon1 = Entity(position: carbonPosition1, type: .atom(.carbon))

      var carbonPosition2 = carbonPosition1
      carbonPosition2 += newDirection * 0.110
      let carbon2 = Entity(position: carbonPosition2, type: .atom(.carbon))
      
      // Save the atom positions.
      cageTooltip.legs[5 * legID + 1] = carbon1
      cageTooltip.legs[5 * legID + 0] = carbon2
      
      // Ensure all of the silicon's neighbors are included in the simulation.
      let siliconAtomsMap = atomsToAtomsMap[Int(siliconID)]
      for siliconNeighborID in siliconAtomsMap {
        guard siliconNeighborID != hydrogenID else {
          continue
        }
        
        var atom = surfaceTopology.atoms[Int(siliconNeighborID)]
        atom.atomicNumber = 32
        surfaceTopology.atoms[Int(siliconNeighborID)] = atom
      }
    }
    surfaceTopology.remove(atoms: removedAtoms)
  }
  
  // Return the output.
  var output: [Entity] = []
  output += cageTooltip.feedstock
  output += cageTooltip.apex
  output += cageTooltip.framework
  output += cageTooltip.legs
  output += surfaceTopology.atoms.filter { $0.atomicNumber != 14 }
  return output
}


#endif
