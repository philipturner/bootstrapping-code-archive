//
//  Workspace.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/2/24.
//

import HDL
import MM4
import Numerics
import xTB

#if false
func createGeometry() -> [Entity] {
  let sourceString = """
  1  1.25  0.00  0.00
  2  1.70  2.31  -0.31
  3  0.00  8.03  -0.66
  4  0.00  2.89  -1.84
  5  0.00  5.56  -1.70
  6  3.84  2.89  -1.49
  7  3.84  5.21  -1.78
  8  1.92  5.79  -3.04
  9  1.92  8.10  -3.52
  10  5.76  5.79  -3.04
  11  5.76  8.10  -3.52
  12  0.00  8.68  -4.72
  13  0.00  10.99  -5.13
  14  1.92  11.58  -6.36
  15  1.92  13.89  -6.77
  
  """
  
  var sourceAtoms: [Entity] = []
  do {
    let lines = sourceString.split(separator: "\n").map(String.init)
    for lineID in lines.indices {
      let line = lines[lineID]
      let words = line.split(separator: " ").map(String.init)
      guard words.count == 4 else {
        fatalError("Unexpected word count.")
      }
      
      // Dissect the line.
      let coordinateX = Float(words[1])!
      let coordinateY = Float(words[2])!
      let coordinateZ = Float(words[3])!
      
      // Convert from angstroms to nanometers.
      var position = SIMD3(coordinateX, coordinateY, coordinateZ)
      position /= 10
      
      // Create an atom.
      let atom = Entity(position: position, type: .atom(.silicon))
      sourceAtoms.append(atom)
    }
  }
  
  // Compile a cube aligned to the three principal axes.
  let lattice = Lattice<Cubic> { h, k, l in
    let hk = (h - k) / 2
    let hk2l = (3 * h + 3 * k - 2 * l) / 22
    let hk3l = (h + k + 3 * l) / 11
    
    Bounds { 20 * h + 20 * k + 20 * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Convex {
        Origin { 5.5 * hk }
        Plane { hk }
      }
      Convex {
        Origin { -5.5 * hk }
        Plane { -hk }
      }
      
      Convex {
        Origin { 15.01 * hk2l }
        Plane { -hk2l }
      }
      Convex {
        // 20.01 - 2927
        // 20.49 - 2927
        // 20.51 - 2987
        // 20.99 - 2987
        // 21.01 - 3053
        Origin { 50.99 * hk2l }
        Plane { hk2l }
      }
      
      Convex {
        // 10.01 - 3053
        // 10.24 - 3053
        // 10.26 - 3020
        // 10.99 - 3020
        // 11.01 - 2984
        // 11.24 - 2984
        // 11.26 - 2945
        // 11.99 - 2945
        // 12.01 - 2902
        Origin { 16.26 * hk3l }
        Plane { -hk3l }
      }
      Convex {
        Origin { 42.99 * hk3l }
        Plane { hk3l }
      }
      
      Replace { .empty }
    }
  }
  
  let latticeConstant = Constant(.square) { .elemental(.silicon) }
  let hk = SIMD3<Float>(1, -1, 0) / 2 * latticeConstant
  let hk2l = SIMD3<Float>(3, 3, -2) / 22 * latticeConstant
  let hk3l = SIMD3<Float>(1, 1, 3) / 11 * latticeConstant
  
  // Next steps:
  // - Get the hang of positioning with vectors in the Si(311) coordinate space.
  // - Form a tileable cuboid of Si(311) surface reconstruction, which doesn't
  //   overlap with adjacent replicas.
  // - Determine whether a Si(311) surface will merge seamlessly with this
  //   surface reconstruction tile. If not, determine the pattern to cut the
  //   surface, so it does work.
  
  return lattice.atoms
}
#endif

// Tasks:
// - Archive the code above, that deals with Si(311).
// - Simulate the chemical reaction where HCCH substitutes NMe2 on atrane.
// - Gain enough confidence that this won't occur for BrCCH.
//   - Simulate molecular dynamics at elevated temperature, with a velocity
//     rescaling yet momentum-conserving thermostat.
func createGeometry() -> [Entity] {
  let cageTooltip = createAzastannatraneTooltip(type: .acetylene)
  return cageTooltip.feedstock + cageTooltip.apex + cageTooltip.framework + cageTooltip.legs
}
