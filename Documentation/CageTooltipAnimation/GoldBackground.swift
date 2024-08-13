//
//  GoldBackground.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/21/24.
//

import HDL

// The gold surface and gold-coated AFM probe, which serve as a static
// backdrop for the animation.
struct GoldBackground {
  var surface: [Entity]
  var tooltip: GoldTooltip
  
  init() {
    // Set up the surface.
    let lattice = Self.createLattice()
    surface = Self.createSurface(lattice: lattice)
    
    // Set up the tooltip.
    func shift(atoms: inout [Entity], offset: SIMD3<Float>) {
      for atomID in atoms.indices {
        atoms[atomID].position += offset
      }
    }
    tooltip = GoldTooltip(type: .au32)
    shift(atoms: &tooltip.apex, offset: SIMD3(0.00, 0.90, 0.00))
    shift(atoms: &tooltip.surface, offset: SIMD3(0.00, 0.90, 0.00))
    shift(atoms: &tooltip.anchors, offset: SIMD3(0.00, 0.90, 0.00))
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 20 * h + 20 * k + 20 * l }
      Material { .elemental(.gold) }
      
      Volume {
        Convex {
          Origin { 10 * (h + k + l) }
          Plane { h + k + l }
        }
        Convex {
          Origin { 9 * (h + k + l) }
          Plane { -(h + k + l) }
        }
        Replace { .empty }
      }
    }
  }
  
  static func createSurface(lattice: Lattice<Cubic>) -> [Entity] {
    var output = lattice.atoms
    
    var eigenvector0 = SIMD3<Float>(1, 0, -1)
    var eigenvector1 = SIMD3<Float>(1, 1, 1)
    var eigenvector2 = SIMD3<Float>(1, -2, 1)
    eigenvector0 /= (eigenvector0 * eigenvector0).sum().squareRoot()
    eigenvector1 /= (eigenvector1 * eigenvector1).sum().squareRoot()
    eigenvector2 /= (eigenvector2 * eigenvector2).sum().squareRoot()
    
    // Iterate over the atoms.
    for atomID in output.indices {
      var atom = output[atomID]
      var position = atom.position
      
      let coordinate0 = (position * eigenvector0).sum()
      let coordinate1 = (position * eigenvector1).sum()
      let coordinate2 = (position * eigenvector2).sum()
      position = SIMD3(coordinate0, coordinate1, coordinate2)
      position.y -= 7.90
      
      atom.position = position
      output[atomID] = atom
    }
    
    return output
  }
}
