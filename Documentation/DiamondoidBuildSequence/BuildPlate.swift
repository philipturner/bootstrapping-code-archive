//
//  BuildPlate.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/7/24.
//

import HDL
import Numerics

enum BuildPlateType: Int {
  case c13 = 13
  case c18 = 18
  case c22 = 22
  case c24 = 24
  case c28 = 28
  case c33 = 33
}

// A graphene build plate.
struct BuildPlate {
  var anchors: [Entity]
  var graphene: [Entity]
  var product: [Entity]
  
  init(type: BuildPlateType) {
    let lattice = Self.createLattice(type: type)
    let topology = Self.createTopology(lattice: lattice)
    anchors = topology.atoms.filter { $0.atomicNumber == 9 }
    graphene = topology.atoms.filter { $0.atomicNumber != 9 }
    product = []
    
    for atomID in anchors.indices {
      var atom = anchors[atomID]
      atom.atomicNumber = 1
      anchors[atomID] = atom
    }
    
    self.translate(offset: -self.centerOfMass)
    self.rotate(angle: -.pi / 2, axis: [1, 0, 0])
  }
  
  static func createLattice(type: BuildPlateType) -> Lattice<Hexagonal> {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 8 * h + 6 * h2k + 1 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 0.3 * l }
        Plane { l }
        
        Replace { .empty }
      }
      
      Volume {
        Origin { 4 * h + 3 * h2k }
        
        switch type {
        case .c13:
          Origin { Float(1.0 / 3) * h2k }
          let directions: [SIMD3<Float>] = [
            k + 2 * h,
            h + 2 * k,
            k - h,
            -k - 2 * h,
            -h - 2 * k,
            -k + h,
          ]
          for direction in directions {
            Convex {
              Origin { (2.0 / 3 + 0.01) * direction }
             Plane { direction }
            }
          }
          
        case .c18:
          do {
            let directions: [SIMD3<Float>] = [
              k + h,
              -h,
              -k,
            ]
            for direction in directions {
              Convex {
                Origin { (5.0 / 3 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          do {
            let directions: [SIMD3<Float>] = [
              h,
              k,
              -k - h,
            ]
            for direction in directions {
              Convex {
                Origin { (3.0 / 3 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          
        case .c22:
          Origin { Float(1.0 / 3) * h2k }
          do {
            let directions: [SIMD3<Float>] = [
              k + 2 * h,
              k - h,
              -h - 2 * k,
            ]
            for direction in directions {
              Convex {
                Origin { (2.0 / 3 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          do {
            let directions: [SIMD3<Float>] = [
              h + 2 * k,
              -k - 2 * h,
              -k + h,
            ]
            for direction in directions {
              Convex {
                Origin { (1.0 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          
        case .c24:
          let directions: [SIMD3<Float>] = [
            h,
            k + h,
            k,
            -h,
            -k - h,
            -k,
          ]
          for direction in directions {
            Convex {
              Origin { (5.0 / 3 + 0.01) * direction }
              Plane { direction }
            }
          }
          
        case .c28:
          Origin { Float(1.0 / 2) * h2k }
          do {
            let directions: [SIMD3<Float>] = [
              h + 2 * k,
              -h - 2 * k,
            ]
            for direction in directions {
              Convex {
                Origin { (5.0 / 6 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          do {
            let directions: [SIMD3<Float>] = [
              h,
              -h
            ]
            for direction in directions {
              Convex {
                Origin { (5.0 / 3 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          
        case .c33:
          Origin { Float(1.0 / 2) * h }
          Origin { Float(1.0 / 2) * h2k }
          do {
            let directions: [SIMD3<Float>] = [
              k + 2 * h,
              k - h,
              -h - 2 * k,
            ]
            for direction in directions {
              Convex {
                Origin { (3.0 / 3 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          do {
            let directions: [SIMD3<Float>] = [
              h + 2 * k,
              -k - 2 * h,
              -k + h,
            ]
            for direction in directions {
              Convex {
                Origin { (4.0 / 3 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
        }
        
        Replace { .atom(.fluorine) }
      }
      
      Volume {
        Origin { 4 * h + 3 * h2k }
        
        switch type {
        case .c13:
          Origin { Float(1.0 / 3) * h2k }
          let directions: [SIMD3<Float>] = [
            h + 2 * k,
            -k - 2 * h,
            -k + h,
          ]
          for direction in directions {
            Convex {
              Origin { (2.0 / 3 + 0.01) * direction }
              Plane { direction }
            }
          }
          
        case .c18:
          Concave {
            Origin { 1 * h }
            Plane { -k + h }
            Plane { k + 2 * h }
          }
          Concave {
            Origin { 1 * k }
            Plane { h + 2 * k }
            Plane { k - h }
          }
          Concave {
            Origin { 1 * (-k - h) }
            Plane { -k - 2 * h }
            Plane { -h - 2 * k }
          }
          do {
            let directions: [SIMD3<Float>] = [
              k + 2 * h,
              k - h,
              -h - 2 * k,
            ]
            for direction in directions {
              Convex {
                Origin { (1.0 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          
        case .c22:
          Origin { Float(1.0 / 3) * h2k }
          do {
            let directions: [SIMD3<Float>] = [
              k + 2 * h,
              k - h,
              -h - 2 * k,
            ]
            for direction in directions {
              Convex {
                Origin { (2.0 / 3 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          
        case .c24:
          Concave {
            Origin { 1 * h }
            Origin { (2.0 / 3 + 0.01) * (-k) }
            Plane { -k + h }
            Plane { k + 2 * h }
          }
          Concave {
            Origin { 1 * k }
            Origin { (2.0 / 3 + 0.01) * (k + h) }
            Plane { h + 2 * k }
            Plane { k - h }
          }
          Concave {
            Origin { 1 * (-k - h) }
            Origin { (2.0 / 3 + 0.01) * (-h) }
            Plane { -k - 2 * h }
            Plane { -h - 2 * k }
          }
          do {
            let directions: [SIMD3<Float>] = [
              k + 2 * h,
              k - h,
              -h - 2 * k,
            ]
            for direction in directions {
              Convex {
                Origin { (1.0 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          
        case .c28:
          Origin { Float(1.0 / 2) * h2k }
          Concave {
            Origin { 1.5 * h }
            Plane { -k + h }
            Plane { k + 2 * h }
          }
          Concave {
            Origin { -1.5 * h }
            Plane { k - h }
            Plane { -k - 2 * h }
          }
          Convex {
            let direction = -h - 2 * k
            Origin { (3.0 / 3 + 0.01) * direction }
            Plane { direction }
          }
          Concave {
            Convex {
              let direction = h + 2 * k
              Origin { (3.0 / 3 + 0.01) * direction }
              Plane { direction }
            }
            Convex {
              Convex {
                Origin { 2 * (k + h) }
                Plane { (k + h) }
              }
              Convex {
                Origin { 2 * k }
                Plane { k }
              }
            }
          }
          Convex {
            Origin { (6.0 / 3 + 0.01) * (k + h) }
            Plane { k + h }
          }
          Convex {
            Origin { (6.0 / 3 + 0.01) * k }
            Plane { k }
          }
          do {
            let directions: [SIMD3<Float>] = [
              h,
              -h
            ]
            for direction in directions {
              Convex {
                Origin { (6.0 / 3 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
          
        case .c33:
          Origin { Float(1.0 / 2) * h }
          Origin { Float(1.0 / 2) * h2k }
          do {
            let directions: [SIMD3<Float>] = [
              k + 2 * h,
              k - h,
              -h - 2 * k,
            ]
            for direction in directions {
              Convex {
                Origin { (3.0 / 3 + 0.01) * direction }
                Plane { direction }
              }
            }
          }
        }
        
        Replace { .empty }
      }
    }
    
    var carbonCount: Int = .zero
    for atomID in lattice.atoms.indices {
      let atom = lattice.atoms[atomID]
      if atom.atomicNumber == 6 {
        carbonCount += 1
      }
    }
    guard carbonCount == type.rawValue else {
      fatalError("Did not produce the correct lattice.")
    }
    return lattice
  }
  
  static func createTopology(
    lattice: Lattice<Hexagonal>
  ) -> Topology {
    var topology = Topology()
    topology.insert(atoms: lattice.atoms)
    
    // Flatten the diamond sheet into graphene.
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var grapheneHexagonScale: Float
      do {
        let grapheneConstant: Float = 2.45 / 10
        let lonsdaleiteConstant = Constant(.hexagon) { .elemental(.carbon) }
        grapheneHexagonScale = 1 / lonsdaleiteConstant
        grapheneHexagonScale *= grapheneConstant
      }
      atom.position.x *= grapheneHexagonScale
      atom.position.y *= grapheneHexagonScale
      atom.position.z = 0
      topology.atoms[atomID] = atom
    }
    
    // Find the bulk atom bonds.
    do {
      let matches = topology.match(topology.atoms)
      
      var insertedBonds: [SIMD2<UInt32>] = []
      for i in topology.atoms.indices {
        for j in matches[i] where i < j {
          let bond = SIMD2(UInt32(i), j)
          insertedBonds.append(bond)
        }
      }
      topology.insert(bonds: insertedBonds)
    }
    
    // Create the hydrogen passivators.
    do {
      let orbitals = topology.nonbondingOrbitals(hybridization: .sp2)
      
      var insertedAtoms: [Entity] = []
      var insertedBonds: [SIMD2<UInt32>] = []
      for atomID in topology.atoms.indices {
        let carbon = topology.atoms[atomID]
        for orbital in orbitals[Int(atomID)] {
          // Source: MM3 Tinker parameters
          let chBondLength: Float = 1.1010 / 10
          let hydrogenPosition = carbon.position + orbital * chBondLength
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
    
    // Correct the bonds to fluorine markers.
    for bondID in topology.bonds.indices {
      let bond = topology.bonds[bondID]
      
      var carbonID: UInt32?
      var fluorineID: UInt32?
      for laneID in 0..<2 {
        let atomID = bond[laneID]
        let atom = topology.atoms[Int(atomID)]
        if atom.atomicNumber == 6 {
          carbonID = UInt32(atomID)
        } else if atom.atomicNumber == 9 {
          fluorineID = UInt32(atomID)
        }
      }
      guard let carbonID,
            let fluorineID else {
        continue
      }
      
      let carbon = topology.atoms[Int(carbonID)]
      var fluorine = topology.atoms[Int(fluorineID)]
      var orbital = fluorine.position - carbon.position
      orbital /= (orbital * orbital).sum().squareRoot()
      
      // Source: MM3 Tinker parameters
      let chBondLength: Float = 1.1010 / 10
      fluorine.position = carbon.position + orbital * chBondLength
      topology.atoms[Int(fluorineID)] = fluorine
    }
    
    return topology
  }
}

extension BuildPlate {
  var centerOfMass: SIMD3<Float> {
    var accumulator: SIMD3<Double> = .zero
    var mass: Double = .zero
    
    let atoms = anchors + graphene + product
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      accumulator += SIMD3(atom.position)
      mass += Double(1)
    }
    return SIMD3<Float>(accumulator / mass)
  }
  
  mutating func translate(offset: SIMD3<Float>) {
    func translate(fragment: inout [Entity]) {
      for atomID in fragment.indices {
        var atom = fragment[atomID]
        atom.position += offset
        fragment[atomID] = atom
      }
    }
    translate(fragment: &anchors)
    translate(fragment: &graphene)
    translate(fragment: &product)
  }
  
  mutating func rotate(angle: Float, axis: SIMD3<Float>) {
    let rotation = Quaternion<Float>(angle: angle, axis: axis)
    let centerOfMass = self.centerOfMass
    
    func rotate(fragment: inout [Entity]) {
      for atomID in fragment.indices {
        var atom = fragment[atomID]
        var delta = atom.position - centerOfMass
        delta = rotation.act(on: delta)
        atom.position = centerOfMass + delta
        fragment[atomID] = atom
      }
    }
    rotate(fragment: &anchors)
    rotate(fragment: &graphene)
    rotate(fragment: &product)
  }
}

extension BuildPlate {
  // Import a set of minimized atoms.
  mutating func `import`(atoms: [Entity], atomCounts: [Int]? = nil) {
    var cursor: Int = .zero
    if let atomCounts {
      self.anchors = []
      self.graphene = []
      for atomID in 0..<atomCounts[0] {
        let atom = atoms[cursor]
        cursor += 1
        self.anchors.append(atom)
      }
      for atomID in 0..<atomCounts[1] {
        let atom = atoms[cursor]
        cursor += 1
        self.graphene.append(atom)
      }
    } else {
      for atomID in self.anchors.indices {
        var atom = self.anchors[atomID]
        atom = atoms[cursor]
        cursor += 1
        self.anchors[atomID] = atom
      }
      for atomID in self.graphene.indices {
        var atom = self.graphene[atomID]
        atom = atoms[cursor]
        cursor += 1
        self.graphene[atomID] = atom
      }
    }
    self.product = Array(atoms[cursor...])
  }
}
