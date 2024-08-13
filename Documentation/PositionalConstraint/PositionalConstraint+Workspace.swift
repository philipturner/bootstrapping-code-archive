//
//  PositionalConstraint+Workspace.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/25/24.
//

import Foundation
import MolecularRenderer
import HDL
import MM4
import Numerics
import QuartzCore
import xTB

// Workspace for prototyping the PES charting program.
// - Estimated completion date: Friday, July 26, 2024
// - Actual completion date: Thursday, July 25, 2024
//
// Requirements:
// - Cache simulation trajectories in a folder called "PositionalConstraints".
//   - Use the combination ID as the key.
// - Enforce an orientation constraint.
//    - Cancel the torque on the C-Si bond.
//    - Cancel the angular momentum on the C-Si bond.
//    - Atoms have equal mass in FIRE, simplifying the two bullets above.
//    - Enforce the C-Si bond orientation after FIRE integration.
// - Must support ONIOM.
//   - GFN-FF with outer region being ~300 atoms.
//   - GFN-FF region is held fixed, but included in force calculation.
//
// Step 1:
// - Generate the correct starting structure for:
//   - two, three, and four methyls
//   - SiH3/CH3 and SiH3/CH2
// - Note the atom IDs of the bonded carbon and silicon
//
// Step 2:
// - SiH3 and CH3
// - xTB
// - Non-constrained energy minimization
// - Observing the torque and angular momentum as the minimization progresses
// - Noting the energy of the final singlepoint
//
// Step 3:
// - GFN-FF van der Waals forces (ONIOM)
//
// Step 4:
// - Run some smoke tests. Get a few exact energies.
// - Add caching, then collect all of the energies. Perhaps create a data
//   structure that isolates all of the functionality: minimization, retrieving
//   from the cache, reporting singlepoint energies of the current atomic
//   structure.
func createGeometry() -> [Entity] {
  // Allocate output variables.
  var output: [Entity] = []
  var string: String = ""
  
  // Specify the problem configurations.
  let angles: [Float] = [
    0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 120, 150, 180,
  ]
  
  // Iterate over the problem configurations.
  for angleID in angles.indices {
    let bondOrientationDegrees = angles[angleID]
    
    // Set up xTB data point.
    var minimizationDesc = MinimizationDescriptor()
    minimizationDesc.bondOrientationDegrees = bondOrientationDegrees
    minimizationDesc.methylenePresent = true
    minimizationDesc.methylCount = 4
    
    // Gather xTB data point.
    xTB_Environment.show()
    var minimization = Minimization(descriptor: minimizationDesc)
    minimization.minimizeSurface()
    output += minimization.tooltip.surface.map {
      var copy = $0
      copy.position += SIMD3(-0.75, -1.50 * Float(angleID), 0.00)
      return copy
    }
    let energy1 = minimization.singlepointEnergy()
    xTB_Environment.show()
    
    // Set up ONIOM data point.
    minimizationDesc.preconditionedStructure = minimization.tooltip.surface
    minimizationDesc.useONIOM = true
    
    // Gather xTB data point.
    xTB_Environment.show()
    minimization = Minimization(descriptor: minimizationDesc)
    minimization.minimizeSurface()
    output += minimization.tooltip.surface.map {
      var copy = $0
      copy.position += SIMD3(0.75, -1.50 * Float(angleID), 0.00)
      return copy
    }
    let energy2 = minimization.singlepointEnergy()
    xTB_Environment.show()
    
    // Present all of the data points in a table.
    func formatEnergy(_ energy: Double) -> String {
      let energyInEV = energy / 160.218
      return String(format: "%.3f", energyInEV)
    }
    string += "\(Int(bondOrientationDegrees)), "
    string += formatEnergy(energy1) + ", "
    string += formatEnergy(energy2) + "\n"
  }
  
  print()
  print(string)
  
  return output
}

