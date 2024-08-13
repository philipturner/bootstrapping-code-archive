//
//  DCB6Tooltip.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/1/24.
//

import HDL
import Numerics

enum DCB6TooltipState {
  case charged
  case carbenicRearrangement
  case discharged
}

struct DCB6TooltipDescriptor {
  /// Required. The element on the left site.
  var reactiveSiteLeft: Element?
  
  /// Required. The element on the right site.
  ///
  /// See the description for `reactiveSiteLeft`.
  var reactiveSiteRight: Element?
  
  /// Required. The state of the tooltip.
  var state: DCB6TooltipState?
  
  init() { }
}

struct DCB6Tooltip {
  var topology = Topology()
  var reactiveSiteIDs: SIMD2<UInt32>
  var dimerIDs: SIMD2<UInt32>?
  
  init(descriptor: DCB6TooltipDescriptor) {
    guard let reactiveSiteLeft = descriptor.reactiveSiteLeft,
          let reactiveSiteRight = descriptor.reactiveSiteRight,
          let state = descriptor.state else {
      fatalError("Descriptor was incomplete.")
    }
    
    let lattice = Self.createLattice()
    topology = Self.createTopology(lattice: lattice)
    reactiveSiteIDs = Self.extractReactiveSiteIDs(topology: topology)
    
    do {
      let leftSiteID = Int(reactiveSiteIDs[0])
      let rightSiteID = Int(reactiveSiteIDs[1])
      topology.atoms[leftSiteID].atomicNumber = reactiveSiteLeft.rawValue
      topology.atoms[rightSiteID].atomicNumber = reactiveSiteRight.rawValue
    }
    
    passivate()
    addFeedstockTopology(state: state)
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 4 * h + 4 * k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 2 * h + 2 * k + 2 * l }
        Origin { 0.25 * (h + k - l) }
        
        // Remove the front plane.
        Convex {
          Origin { 0.25 * (h + k + l) }
          Plane { h + k + l }
        }
        
        func triangleCut(sign: Float) {
          Convex {
            Origin { 0.25 * sign * (h - k - l) }
            Plane { sign * (h - k / 2 - l / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (k - l - h) }
            Plane { sign * (k - l / 2 - h / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (l - h - k) }
            Plane { sign * (l - h / 2 - k / 2) }
          }
        }
        
        // Remove three sides forming a triangle.
        triangleCut(sign: +1)
        
        // Remove their opposites.
        triangleCut(sign: -1)
        
        // Remove the back plane.
        Convex {
          Origin { -0.25 * (h + k + l) }
          Plane { -(h + k + l) }
        }
        
        Replace { .empty }
        
        Volume {
          // TODO: Use the actual reactive site atom here. Mark carbon with
          // gold.
          Origin { 0.20 * (h + k + l) }
          Plane { h + k + l }
          Replace { .atom(.silicon) }
        }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    var topology = Topology()
    topology.insert(atoms: lattice.atoms)
    
    // Center the adamantane at (0, 0, 0).
    var accumulator: SIMD3<Float> = .zero
    for atom in topology.atoms {
      accumulator += atom.position
    }
    accumulator /= Float(topology.atoms.count)
    
    // TODO: Make the code modular. Each reactive site compiles a unique
    // lattice to represent it. Then, use an entirely different (hexagonal)
    // lattice for Group (V) atoms.
    
    // Rotate the adamantane and make the three bridge carbons flush.
    let rotation1 = Quaternion<Float>(angle: .pi / 4, axis: [0, 1, 0])
    let rotation2 = Quaternion<Float>(angle: 35.26 * .pi / 180, axis: [0, 0, 1])
    var maxX: Float = -.greatestFiniteMagnitude
    for i in topology.atoms.indices {
      var position = topology.atoms[i].position
      position -= accumulator
      position = rotation1.act(on: position)
      position = rotation2.act(on: position)
      topology.atoms[i].position = position
      maxX = max(maxX, position.x)
    }
    for i in topology.atoms.indices {
      topology.atoms[i].position.x -= maxX
      topology.atoms[i].position.x -= Element.carbon.covalentRadius
    }
    
    // Create the second half.
    topology.insert(atoms: topology.atoms.map {
      var copy = $0
      copy.position.x = -copy.position.x
      return copy
    })
    return topology
  }
  
  // Find the locations of silicon markers.
  static func extractReactiveSiteIDs(topology: Topology) -> SIMD2<UInt32> {
    var output: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      
      switch atom.atomicNumber {
      case 1:
        break
      case 6:
        break
      case 14:
        output.append(UInt32(atomID))
      default:
        fatalError("Unrecognized atomic number.")
      }
    }
    guard output.count == 2 else {
      fatalError("Unexpected number of reactive sites.")
    }
    return SIMD2(output[0], output[1])
  }
  
  // Form the bonding topology and passivate with hydrogens.
  mutating func passivate() {
    let matchRadius = 2 * Element.carbon.covalentRadius
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(1.1 * matchRadius))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        if reactiveSiteIDs != bond {
          insertedBonds.append(bond)
        }
      }
    }
    topology.insert(bonds: insertedBonds)
    
    let orbitals = topology.nonbondingOrbitals()
    let chBondLength = Element.carbon.covalentRadius +
    Element.hydrogen.covalentRadius
    
    var insertedAtoms: [Entity] = []
    insertedBonds = []
    for i in topology.atoms.indices {
      if any(reactiveSiteIDs .== UInt32(i)) {
        continue
      }
      let carbon = topology.atoms[i]
      for orbital in orbitals[i] {
        let position = carbon.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Add the feedstocks if the tooltip is charged.
  mutating func addFeedstockTopology(state: DCB6TooltipState) {
    let orbitals = topology.nonbondingOrbitals()
    
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for laneID in 0..<2 {
      let atomID = reactiveSiteIDs[laneID]
      let atom = topology.atoms[Int(atomID)]
      let orbital = orbitals[Int(atomID)][0]
      
      var position = atom.position + orbital * 0.2
      if state == .carbenicRearrangement {
        position.x = 0
      }
      
      let element = Element(rawValue: atom.atomicNumber)!
      var bondLength = element.covalentRadius
      if state == .carbenicRearrangement {
        bondLength += 0.067
      } else {
        bondLength += 0.061
      }
      
      let deltaX = min(bondLength, position.x - atom.position.x)
      let deltaY = (bondLength * bondLength - deltaX * deltaX).squareRoot()
      position.y = atom.position.y + deltaY
      
      let carbon = Entity(position: position, type: .atom(.carbon))
      let carbonID = topology.atoms.count + insertedAtoms.count
      let bond = SIMD2(UInt32(atomID), UInt32(carbonID))
      insertedAtoms.append(carbon)
      insertedBonds.append(bond)
    }
    
    // Give the carbons the same elevation.
    do {
      var positionSum: SIMD3<Float> = .zero
      positionSum += insertedAtoms[0].position
      positionSum += insertedAtoms[1].position
      
      let averageY = (positionSum / 2).y
      insertedAtoms[0].position.y = averageY
      insertedAtoms[1].position.y = averageY
    }
    
    switch state {
    case .charged:
      insertedBonds.append(SIMD2(UInt32(topology.atoms.count),
                                 UInt32(topology.atoms.count + 1)))
    case .carbenicRearrangement:
      insertedBonds.removeLast()
      insertedAtoms.removeLast()
      
      var position = insertedAtoms[0].position
      position.y += 0.133
      
      let carbon = Entity(position: position, type: .atom(.carbon))
      insertedAtoms.append(carbon)
      insertedBonds.append(SIMD2(UInt32(topology.atoms.count),
                                 UInt32(topology.atoms.count + 1)))
      
      let carbenicBond = SIMD2(UInt32(reactiveSiteIDs[1]),
                               UInt32(topology.atoms.count))
      insertedBonds.append(carbenicBond)
    case .discharged:
      insertedAtoms.removeAll()
      insertedBonds.removeAll()
      insertedBonds.append(reactiveSiteIDs)
    }
    
    switch insertedAtoms.count {
    case 0:
      dimerIDs = nil
    case 2:
      let firstCarbonID = topology.atoms.count
      dimerIDs = SIMD2(UInt32(firstCarbonID),
                       UInt32(firstCarbonID + 1))
    default:
      fatalError("This should never happen.")
    }
    
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
}
