//
//  GaAs110Tooltip.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 7/4/24.
//

import Foundation
import MolecularRenderer
import HDL
import MM4
import Numerics
import QuartzCore
import xTB

// Requirements for GaAs variant:
// - Must have the same number of gallium and arsenic atoms.
// - Hydrogen-terminate the outer layer, freeze all H-terminated atoms.
// - Frozen atoms should mirror the positions of relaxed atoms in xTB.
//
// Data for compiling the bulk model:
// https://doi.org/10.1134/S102745101210014X
// https://doi.org/10.1103/PhysRevB.80.064417
//
// Want this to be extendable:
// - Specify the tooltip model in number of unit cells.
// - Allow bulk lattice deformations to be simulated with GFN-FF.
// - Allow different lattices (Si, Ge) in case GaAs turns out to be nonviable.

func createGeometry() -> [[Entity]] {
  // Compile a lattice.
  let outerLattice = Lattice<Cubic> { h, k, l in
    Bounds { 3 * h + 3 * k + 3 * l }
    Material { .checkerboard(.gallium, .arsenic) }
    
    Volume {
      // Left, right.
      Convex {
        Origin { 0.25 * h }
        Plane { -h }
      }
      Convex {
        Origin { 2.5 * h }
        Plane { h }
      }
      
      // Front, back (diagonal).
      Convex {
        Origin { 2 * (k + l) }
        Plane { k + l }
      }
      Convex {
        Origin { 1.5 * (k + l) }
        Plane { -(k + l) }
      }
      
      // Top, bottom (diagonal).
      Convex {
        Origin { 1.75 * k }
        Plane { k - l }
      }
      Convex {
        Origin { 1.25 * l }
        Plane { -k + l }
      }
      
      Replace { .empty }
    }
  }
  let innerLattice = Lattice<Cubic> { h, k, l in
    Bounds { 3 * h + 3 * k + 3 * l }
    Material { .checkerboard(.gallium, .arsenic) }
    
    Volume {
      // Left, right.
      Convex {
        Origin { 0.75 * h }
        Plane { -h }
      }
      Convex {
        Origin { 2.0 * h }
        Plane { h }
      }
      
      // Front, back (diagonal).
      Convex {
        Origin { 2 * (k + l) }
        Plane { k + l }
      }
      Convex {
        Origin { 1.75 * (k + l) }
        Plane { -(k + l) }
      }
      
      // Top, bottom (diagonal).
      Convex {
        Origin { 1.25 * k }
        Plane { k - l }
      }
      Convex {
        Origin { 0.75 * l }
        Plane { -k + l }
      }
      
      Replace { .empty }
    }
  }
  
  // Remove the two primary atoms.
  var reconstruction = Reconstruction()
  reconstruction.material = .checkerboard(.gallium, .arsenic)
  reconstruction.topology.insert(atoms: outerLattice.atoms)
  reconstruction.compile()
  
  // Remove the hydrogen passivation.
  var topology = reconstruction.topology
  do {
    var removedAtoms: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      guard atom.atomicNumber == 1 else {
        continue
      }
      removedAtoms.append(UInt32(atomID))
    }
    topology.remove(atoms: removedAtoms)
  }
  
  // Choose the anchors.
  var anchorIDs: [UInt32] = []
  for atomID1 in topology.atoms.indices {
    let atom1 = topology.atoms[atomID1]
    
    var foundMatch = false
    for atomID2 in innerLattice.atoms.indices {
      let atom2 = innerLattice.atoms[atomID2]
      guard atom1.atomicNumber == atom2.atomicNumber else {
        continue
      }
      
      let delta = atom1.position - atom2.position
      let distance = (delta * delta).sum().squareRoot()
      if distance < 0.010 {
        foundMatch = true
      }
    }
    if !foundMatch {
      anchorIDs.append(UInt32(atomID1))
    }
  }
  
  return runMinimization(atoms: topology.atoms, anchorIDs: anchorIDs)
}

// Like 'minimize(atoms:)', but returns all of the animation frames.
func runMinimization(
  atoms: [Entity],
  anchorIDs: [UInt32]
) -> [[Entity]] {
  // Set up the calculator.
  var calculatorDesc = xTB_CalculatorDescriptor()
  calculatorDesc.atomicNumbers = atoms.map(\.atomicNumber)
  calculatorDesc.positions = atoms.map(\.position)
  calculatorDesc.hamiltonian = .tightBinding
  let calculator = xTB_Calculator(descriptor: calculatorDesc)
  
  // Set up the minimizer.
  var minimizationDesc = FIREMinimizationDescriptor()
  minimizationDesc.anchors = Set(anchorIDs)
  minimizationDesc.masses = atoms.map {
    if $0.atomicNumber == 1 {
      return Float(4.0 * MM4YgPerAmu)
    } else {
      return Float(12.011 * MM4YgPerAmu)
    }
  }
  minimizationDesc.positions = calculator.molecule.positions
  var minimization = FIREMinimization(descriptor: minimizationDesc)
  
  // Allocate an array of frames.
  var frames: [[Entity]] = [atoms]
  
  print()
  for trialID in 0..<50 {
    // Update the calculator.
    calculator.molecule.positions = minimization.positions
    
    // Execute a singlepoint.
    let forces = calculator.molecule.forces
    var maximumForce: Float = .zero
    for atomID in calculator.molecule.atomicNumbers.indices {
      if minimization.anchors.contains(UInt32(atomID)) {
        continue
      }
      let force = forces[atomID]
      let forceMagnitude = (force * force).sum().squareRoot()
      maximumForce = max(maximumForce, forceMagnitude)
    }
    
    // Report the system state.
    print("time: \(Format.time(minimization.time))", terminator: " | ")
    print("energy: \(Format.energy(calculator.energy))", terminator: " | ")
    print("max force: \(Format.force(maximumForce))", terminator: " | ")
    
    // Perform time integration with FIRE.
    let converged = minimization.step(forces: forces)
    if !converged {
      print("Δt: \(Format.time(minimization.Δt))", terminator: " | ")
    }
    print()
    
    // Record the frame for visualization.
    var frame = atoms
    for atomID in frame.indices {
      frame[atomID].position = minimization.positions[atomID]
    }
    frames.append(frame)
    
    // Continue to the next iteration.
    if converged {
      break
    } else if trialID == 499 {
      print("failed to converge!")
    }
  }
  
  return frames
}

func createGeometry() -> [Entity] {
  return [
    Entity(position: SIMD3(0.4240, 1.2719, 0.4240), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.9893, 1.2719, 0.4240), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.1413, 0.9893, 0.9893), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.4240, 0.7066, 0.9893), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.4240, 0.9893, 0.7066), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.5653, 0.8479, 0.8479), type: .atom(.gallium)),
    Entity(position: SIMD3(0.7039, 1.0038, 1.0048), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.9893, 0.7066, 0.9893), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.9893, 0.9893, 0.7066), type: .atom(.arsenic)),
    Entity(position: SIMD3(1.1306, 0.8479, 0.8479), type: .atom(.gallium)),
    Entity(position: SIMD3(1.2719, 0.9893, 0.9893), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.1413, 1.2719, 0.7066), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.2826, 1.1306, 0.8479), type: .atom(.gallium)),
    Entity(position: SIMD3(0.3801, 1.3021, 1.0404), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.2826, 1.4132, 0.5653), type: .atom(.gallium)),
    Entity(position: SIMD3(0.4240, 1.5546, 0.7066), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.5653, 1.1306, 0.5653), type: .atom(.gallium)),
    Entity(position: SIMD3(0.7092, 1.2667, 0.7281), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.4965, 1.3592, 0.8329), type: .atom(.gallium)),
    Entity(position: SIMD3(0.8818, 1.1482, 0.8898), type: .atom(.gallium)),
    Entity(position: SIMD3(0.9827, 1.3148, 1.0525), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.8479, 1.4132, 0.5653), type: .atom(.gallium)),
    Entity(position: SIMD3(0.9893, 1.5546, 0.7066), type: .atom(.arsenic)),
    Entity(position: SIMD3(1.1306, 1.1306, 0.5653), type: .atom(.gallium)),
    Entity(position: SIMD3(1.2719, 1.2719, 0.7066), type: .atom(.arsenic)),
    Entity(position: SIMD3(1.0723, 1.3647, 0.8223), type: .atom(.gallium)),
    Entity(position: SIMD3(1.4132, 1.1306, 0.8479), type: .atom(.gallium)),
    Entity(position: SIMD3(0.2826, 0.8479, 1.1306), type: .atom(.gallium)),
    Entity(position: SIMD3(0.3623, 0.9911, 1.3265), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.5653, 0.5653, 1.1306), type: .atom(.gallium)),
    Entity(position: SIMD3(0.7066, 0.7066, 1.2719), type: .atom(.arsenic)),
    Entity(position: SIMD3(0.5653, 0.8479, 1.4132), type: .atom(.gallium)),
    Entity(position: SIMD3(0.8670, 0.8673, 1.1502), type: .atom(.gallium)),
    Entity(position: SIMD3(0.9501, 1.0240, 1.3377), type: .atom(.arsenic)),
    Entity(position: SIMD3(1.1306, 0.5653, 1.1306), type: .atom(.gallium)),
    Entity(position: SIMD3(1.2719, 0.7066, 1.2719), type: .atom(.arsenic)),
    Entity(position: SIMD3(1.1306, 0.8479, 1.4132), type: .atom(.gallium)),
    Entity(position: SIMD3(1.4132, 0.8479, 1.1306), type: .atom(.gallium)),
    Entity(position: SIMD3(0.4906, 1.0992, 1.1273), type: .atom(.gallium)),
    Entity(position: SIMD3(1.0816, 1.1039, 1.1405), type: .atom(.gallium)),
  ]
}
