//
//  CageTooltip.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/19/24.
//

import Foundation
import HDL
import Numerics
import xTB

enum CageFeedstockType {
  // Miscellaneous feedstocks.
  case radical
  case acetylene
  case dischargedAcetylene(Element)
  case thiol
  
  // Halogen class of feedstocks.
  case hydrogen
  case fluorine
  case chlorine
  case bromine
  
  // Bare atom class of feedstocks.
  case carbon
  case silicon
  case germanium
  
  // Carbene class of feedstocks.
  case borene
  case carbene
  case nitrene
  case silene
  case gallene
  case germene
  case arsene
  case monohalogenide(Element, Element)
  
  // Methylene class of feedstocks.
  case borylene
  case methylene
  case nitrylene
  case silylene
  case phosphylene
  case gallylene
  case germylene
  case arsylene
  case dihalogenide(Element, Element, Element)
  
  // Methane class of feedstocks.
  case borane
  case methane
  case amine
  case silane
  case phosphane
  case gallane
  case germane
  case arsane
  case trihalogenide(Element, Element, Element, Element)
}

enum CageFrameworkType {
  case adamantane(Element)
  case adamantasilane(Element)
  case carbatrane(Element)
}

enum CageLinkerType {
  case amine
  case thiol
  
  var element: Element {
    switch self {
    case .amine: return .nitrogen
    case .thiol: return .sulfur
    }
  }
}

struct CageTooltipDescriptor {
  var feedstockType: CageFeedstockType?
  var frameworkType: CageFrameworkType?
  var linkerType: CageLinkerType = .thiol
}

// Cage tooltip data structure:
// - single source file that can generate a large number of tips
// - able to switch binding surface and workpiece, without writing new code
// - caching reduces the latency to set up MD simulations
struct CageTooltip {
  // For the client to define.
  var feedstock: [Entity]
  
  // Generated in the initializer.
  var apex: [Entity]
  var framework: [Entity]
  var legs: [Entity]
  var linkerType: CageLinkerType
  
  // Connections between the fragments.
  var apexFrameworkBoundary: [SIMD2<UInt32>]
  var frameworkLegsBoundary: [SIMD2<UInt32>]
  
  init(descriptor: CageTooltipDescriptor) {
    guard let feedstockType = descriptor.feedstockType,
          let frameworkType = descriptor.frameworkType else {
      fatalError("Descriptor was incomplete.")
    }
    self.linkerType = descriptor.linkerType
    
    // Determine the material type.
    var materialType: MaterialType
    if case .adamantasilane = frameworkType {
      materialType = .elemental(.silicon)
    } else {
      materialType = .elemental(.carbon)
    }
    
    // Compile all of the parts.
    let lattice = Self.createLattice(
      materialType: materialType,
      linkerType: linkerType)
    let atoms = Self.position(
      lattice: lattice, frameworkType: frameworkType)
    let topology = Self.createTopology(
      atoms: atoms, frameworkType: frameworkType)
    (apex, framework, legs) = Self.fragment(
      topology: topology, linkerType: linkerType)
    feedstock = CageTooltip.createFeedstock(type: feedstockType)
    
    // Transmute the apical atom.
    switch frameworkType {
    case .adamantane(let element):
      apex[0].atomicNumber = element.rawValue
    case .adamantasilane(let element):
      apex[0].atomicNumber = element.rawValue
    case .carbatrane(let element):
      apex[0].atomicNumber = element.rawValue
    }
    
    // Store connectivity information.
    apexFrameworkBoundary = Self.createApexFrameworkBoundary(
      frameworkType: frameworkType)
    frameworkLegsBoundary = Self.createFrameworkLegsBoundary(
      frameworkType: frameworkType)
  }
  
  // Carbon Centers:
  // - compile lattice
  static func createLattice(
    materialType: MaterialType,
    linkerType: CageLinkerType
  ) -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 3 * h + 3 * k + 3 * l }
      Material { materialType }
      
      // Expose the bridgehead carbon.
      Volume {
        Convex {
          Origin { 2.25 * k }
          Plane { k }
        }
        Convex {
          Origin { 2 * h + 2 * l }
          Origin { 3 * k }
          Plane { h + k + l }
        }
        Replace { .empty }
      }
      
      // Place the germanium marker.
      Volume {
        Concave {
          Convex {
            Origin { 2.25 * h }
            Plane { h }
          }
          Convex {
            Origin { 2.25 * l }
            Plane { l }
          }
          Convex {
            Origin { 1.5 * k }
            Plane { k }
          }
        }
        Replace { .atom(.germanium) }
      }
      
      // Chop off some more atoms.
      Volume {
        Convex {
          Origin { 2.75 * h }
          Plane { h }
        }
        Convex {
          Origin { 2.75 * l }
          Plane { l }
        }
        Replace { .empty }
      }
      
      // Chop off some diagonals, sort of forming a tetrahedron (the germanium
      // is at a vertex).
      Volume {
        Convex {
          Origin { -2.25 * h }
          Plane { -h + k + l }
        }
        Convex {
          Origin { -3.25 * k }
          Plane { h - k + l }
        }
        Convex {
          Origin { -2.25 * l }
          Plane { h + k - l }
        }
        Replace { .empty }
      }
      
      // Create a cavity on the other side.
      Volume {
        Concave {
          Convex {
            Origin { 2 * k }
            Plane { -k }
          }
          Convex {
            Origin { -2.5 * k }
            Plane { -h + k - l }
          }
          
          // Mask out the cage from the cut.
          Convex {
            Origin { 5.5 * k }
            Plane { -h - k - l }
          }
        }
        Replace { .empty }
      }
      
      // Create a second cavity.
      Volume {
        Concave {
          Convex {
            Origin { 2 * k }
            Plane { -k }
          }
          Convex {
            Origin { -2 * l }
            Plane { -h - k + l }
          }
          Convex {
            Origin { -2 * h }
            Plane { h - k - l }
          }
          
          // Mask out the cage from the cut.
          Convex {
            Origin { 5.5 * k }
            Plane { -h - k - l }
          }
        }
        Replace { .empty }
      }
      
      // Truncate the legs.
      Volume {
        Origin { 1.6 * (h + k + l) }
        Plane { -(h + k + l) }
        Replace { .empty }
        
        // Place the sulfur markers.
        Origin { 0.1 * (h + k + l) }
        Plane { -(h + k + l) }
        Replace { .atom(linkerType.element) }
      }
    }
  }
  
  // Positioning:
  // - rotate so the apex points vertically
  // - sort into legs based on angle around [0, 1, 0]
  // - transform into atrane if needed
  // - restore global topology
  static func position(
    lattice: Lattice<Cubic>,
    frameworkType: CageFrameworkType
  ) -> [Entity] {
    var atoms = lattice.atoms
    
    // Center the atoms at the origin.
    var gePosition: SIMD3<Float>?
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      guard atom.atomicNumber == 32 else {
        continue
      }
      gePosition = atom.position
    }
    guard let gePosition else {
      fatalError("Could not find germanium atom position.")
    }
    for atomID in atoms.indices {
      var atom = atoms[atomID]
      atom.position -= gePosition
      atoms[atomID] = atom
    }
    
    // Rotate the atoms, so the tip points straight up.
    var eigenvector0 = SIMD3<Float>(1, 0, -1)
    var eigenvector1 = SIMD3<Float>(1, 1, 1)
    var eigenvector2 = SIMD3<Float>(-1, 2, -1)
    eigenvector0 /= (eigenvector0 * eigenvector0).sum().squareRoot()
    eigenvector1 /= (eigenvector1 * eigenvector1).sum().squareRoot()
    eigenvector2 /= (eigenvector2 * eigenvector2).sum().squareRoot()
    
    // Iterate over the atoms.
    for atomID in atoms.indices {
      var atom = atoms[atomID]
      var position = atom.position
      
      let coordinate0 = (position * eigenvector0).sum()
      let coordinate1 = (position * eigenvector1).sum()
      let coordinate2 = (position * eigenvector2).sum()
      position = SIMD3(coordinate0, coordinate1, coordinate2)
      
      atom.position = position
      atoms[atomID] = atom
    }
    
    // Sort into legs based on angle around [0, 1, 0].
    var apex: [Entity] = []
    var legs: [[Entity]] = [[], [], []]
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      if atom.atomicNumber == 32 {
        apex.append(atom)
        continue
      }
      
      var direction = atom.position
      direction.y = .zero
      guard any(direction .> 0.001) || any(direction .< -0.001) else {
        fatalError("Could not establish direction about axis.")
      }
      
      var angle = Float.atan2(y: -direction.z, x: direction.x)
      angle *= 180 / .pi
      // shift the starting point of each sector here
      angle -= 5
      if angle < 0 {
        angle += 360
      }
      
      if angle < 120 {
        legs[1].append(atom)
      } else if angle < 240 {
        legs[2].append(atom)
      } else if angle < 360 {
        legs[0].append(atom)
      } else {
        fatalError("Unrecognized angle: \(angle)")
      }
    }
    
    // Sort the legs by vertical coordinate, lowest to highest.
    for legID in legs.indices {
      var leg = legs[legID]
      leg.sort(by: { $0.position.y < $1.position.y })
      legs[legID] = leg
    }
    
    // Transform into an atrane.
    if case .carbatrane = frameworkType {
      apex[0].atomicNumber = 50
      apex.append(
        Entity(position: SIMD3(0.00, -0.26, 0.00), type: .atom(.nitrogen)))
      
      for legID in legs.indices {
        var leg = legs[legID]
        let directionAngle = Float(legID) * (2 * .pi / 3)
        let directionRotation = Quaternion<Float>(
          angle: directionAngle, axis: [0, 1, 0])
        let direction = directionRotation.act(on: [0, 0, 1])
        
        for atomID in leg.indices {
          var atom = leg[atomID]
          atom.position += 0.08 * direction
          leg[atomID] = atom
        }
        
        // Rotate about the uppermost atom.
        let tiltAngle = Float(-20) * .pi / 180
        let tiltRotation = Quaternion<Float>(
          angle: tiltAngle, axis: direction)
        let tiltOrigin = leg[leg.count - 1].position
        
        // Iterate over the atoms.
        for atomID in leg.indices {
          var atom = leg[atomID]
          if atomID == leg.count - 1 {
            continue
          }
          
          var delta = atom.position - tiltOrigin
          delta = tiltRotation.act(on: delta)
          atom.position = tiltOrigin + delta
          leg[atomID] = atom
        }
        
        // Save the modified leg.
        legs[legID] = leg
      }
    }
    
    return apex + legs.flatMap { $0 }
  }
  
  // Passivation:
  // - merge into global topology
  // - framework and apex: sp3 (mask out apex[0])
  //                    atrane: mask out apex[1]
  // - legs: sp3 (thiol)
  //         sp2 (trifluorobenzene)
  //         mask out S/O
  // - S/O: hydrogen pointing downward
  // - fragment back into subsystems
  //   - create the arrays that link atoms in different subsystems
  // - add feedstock
  //   - no linking to tip because detachable
  //   - respect choice of capping agent: nil, Cl, Br
  //   - calculate apex-feedstock bond length using element from descriptor
  // - transmute apex into specified element
  static func createTopology(
    atoms: [Entity],
    frameworkType: CageFrameworkType
  ) -> Topology {
    // Create a global topology. This will be fragmented into topologies for
    // each subsystem.
    var topology = Topology()
    topology.insert(atoms: atoms)
    do {
      var bondScale: Float
      if case .carbatrane = frameworkType {
        bondScale = 1.3
      } else {
        bondScale = 1.2
      }
      let matches = topology.match(
        topology.atoms, algorithm: .covalentBondLength(bondScale))
      
      var insertedBonds: [SIMD2<UInt32>] = []
      for i in topology.atoms.indices {
        for j in matches[i] where i < j {
          let bond = SIMD2(UInt32(i), UInt32(j))
          insertedBonds.append(bond)
        }
      }
      topology.insert(bonds: insertedBonds)
    }
    
    // Skipping the trifluorobenzene legs and proceeding directly to
    // passivation.
    do {
      let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
      
      var insertedAtoms: [Entity] = []
      var insertedBonds: [SIMD2<UInt32>] = []
      for atomID in topology.atoms.indices {
        let atom = topology.atoms[atomID]
        if atom.atomicNumber == 32 || atom.atomicNumber == 50 {
          continue
        }
        
        var orbitalSet: [SIMD3<Float>]
        if atom.atomicNumber == 16 {
          var direction = atom.position
          direction.y = 0
          direction /= (direction * direction).sum().squareRoot()
          
          let rotation = Quaternion<Float>(angle: -.pi / 2, axis: [0, 1, 0])
          direction = rotation.act(on: direction)
          orbitalSet = [direction]
        } else if atom.atomicNumber == 7 && atom.position.y < -0.35 {
          var direction = atom.position
          direction.y = 0
          direction /= (direction * direction).sum().squareRoot()
          direction.y = -0.5
          direction /= (direction * direction).sum().squareRoot()
          
          let rotation1 = Quaternion<Float>(angle: -.pi / 2, axis: [0, 1, 0])
          let rotation2 = Quaternion<Float>(angle: .pi / 2, axis: [0, 1, 0])
          let direction1 = rotation1.act(on: direction)
          let direction2 = rotation2.act(on: direction)
          orbitalSet = [direction1, direction2]
        } else {
          orbitalSet = Array(orbitals[atomID])
        }
        
        let element = Element(rawValue: atom.atomicNumber)!
        for orbital in orbitalSet {
          let bondLength = element.covalentRadius +
          Element.hydrogen.covalentRadius
          let hydrogenPosition = atom.position + orbital * bondLength
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
    return topology
  }
  
  // Fragmentation:
  // - sort into lists with a specific ordering
  //   - feedstock (empty), apex, framework, legs
  //   - ensure S/O at end of their list, so corresponding hydrogen generates
  //     at end of array
  // - swap legs for trifluorobenzene-OH if needed
  // - rotate legs into optimal position
  //   - S/O to actual binding sites on a surface
  //   - compare side by side with a surface
  //
  // Regenerate the C-C bonds after this, with an asymmetric 'match'. There
  // should be a function that takes two different topologies and detects the
  // bulk-atom bonds between them.
  // - This function will be implemented when it is time to simulate a
  //   minimal representation of the tooltip.
  // - The bonds could also be specified manually.
  static func fragment(
    topology: Topology,
    linkerType: CageLinkerType
  ) -> (
    apex: [Entity], framework: [Entity], legs: [Entity]
  ) {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    var apexIndices: [UInt32] = []
    var frameworkIndices: [UInt32] = []
    var legsIndices: [UInt32] = []
    
    // Iterate over the atoms.
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == 1 {
        // Add the hydrogens when processing their center atoms.
        continue
      }
      if atom.atomicNumber == 32 || atom.atomicNumber == 50 {
        // Make sure the reactive atom is the first one in the apex.
        apexIndices = [UInt32(atomID)] + apexIndices
        continue
      }
      
      // Fetch the neighbors.
      let atomsMap = atomsToAtomsMap[atomID]
      var isApex = false
      var isLegs = 
      (atom.atomicNumber == linkerType.element.rawValue) &&
      (atom.position.x.magnitude > 0.010 ||
       atom.position.z.magnitude > 0.010)
      var hydrogenNeighbors: [UInt32] = []
      
      // Iterate over the neighbors.
      for otherAtomID in atomsMap {
        let otherAtom = topology.atoms[Int(otherAtomID)]
        if otherAtom.atomicNumber == 32 || otherAtom.atomicNumber == 50 {
          isApex = true
        }
        if (otherAtom.atomicNumber == linkerType.element.rawValue) &&
            (otherAtom.position.x.magnitude > 0.010 ||
             otherAtom.position.z.magnitude > 0.010) {
          isLegs = true
        }
        if otherAtom.atomicNumber == 1 {
          hydrogenNeighbors.append(otherAtomID)
        }
      }
      if isApex && isLegs {
        print(atom)
        fatalError("This should never happen.")
      }
      
      // Add this atom, and its connected hydrogens, to a list.
      if isApex {
        apexIndices.append(UInt32(atomID))
        apexIndices.append(contentsOf: hydrogenNeighbors)
      } else if isLegs {
        legsIndices.append(UInt32(atomID))
        legsIndices.append(contentsOf: hydrogenNeighbors)
      } else {
        frameworkIndices.append(UInt32(atomID))
        frameworkIndices.append(contentsOf: hydrogenNeighbors)
      }
    }
    
    // Separate out the subsystems.
    var apex: [Entity] = []
    var framework: [Entity] = []
    var legs: [Entity] = []
    for atomID in apexIndices {
      let atom = topology.atoms[Int(atomID)]
      apex.append(atom)
    }
    for atomID in frameworkIndices {
      let atom = topology.atoms[Int(atomID)]
      framework.append(atom)
    }
    for atomID in legsIndices {
      let atom = topology.atoms[Int(atomID)]
      legs.append(atom)
    }
    return (apex, framework, legs)
  }
  
  static func createFeedstock(type: CageFeedstockType) -> [Entity] {
    switch type {
      // Miscellaneous feedstocks.
    case .radical:
      return []
    case .acetylene:
      return [
        Entity(position: SIMD3(0.00, 0.180, 0.02), type: .atom(.carbon)),
        Entity(position: SIMD3(0.00, 0.330, -0.01), type: .atom(.carbon)),
      ]
    case .dischargedAcetylene(let element):
      return [
        Entity(position: SIMD3(0.00, 0.180, 0.02), type: .atom(.carbon)),
        Entity(position: SIMD3(0.00, 0.330, -0.01), type: .atom(.carbon)),
        Entity(position: SIMD3(0.00, 0.480, -0.01), type: .atom(element)),
      ]
    case .thiol:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.sulfur)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
      
      // Halogen class of feedstocks.
    case .hydrogen:
      return [
        Entity(position: SIMD3(0.00, 0.15, 0.02), type: .atom(.hydrogen))
      ]
    case .fluorine:
      return [
        Entity(position: SIMD3(-0.01, 0.20, 0.02), type: .atom(.fluorine)),
      ]
    case .chlorine:
      return [
        Entity(position: SIMD3(-0.01, 0.20, 0.02), type: .atom(.chlorine)),
      ]
    case .bromine:
      return [
        Entity(position: SIMD3(-0.01, 0.20, 0.02), type: .atom(.bromine)),
      ]
      
      // Bare atom class of feedstocks.
    case .carbon:
      return [
        Entity(position: SIMD3(-0.01, 0.20, 0.02), type: .atom(.carbon)),
      ]
    case .silicon:
      return [
        Entity(position: SIMD3(-0.01, 0.20, 0.02), type: .atom(.silicon)),
      ]
    case .germanium:
      return [
        Entity(position: SIMD3(-0.01, 0.20, 0.02), type: .atom(.germanium)),
      ]
      
      // Carbene class of feedstocks.
    case .borene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.boron)),
      ]
    case .carbene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.carbon)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .nitrene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.nitrogen)),
      ]
    case .silene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.silicon)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .gallene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.gallium)),
      ]
    case .germene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.germanium)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .arsene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.arsenic)),
      ]
    case .monohalogenide(let element1, let element2):
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(element1)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(element2)),
      ]
      
      // Methylene class of feedstocks.
    case .borylene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.boron)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .methylene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.carbon)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .nitrylene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.nitrogen)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .silylene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.silicon)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .phosphylene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.phosphorus)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .gallylene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.gallium)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .germylene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.germanium)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .arsylene:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.arsenic)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .dihalogenide(let element1, let element2, let element3):
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(element1)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(element2)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(element3)),
      ]
      
      // Methane class of feedstocks.
    case .borane:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.boron)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .methane:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.carbon)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(0.00, 0.30, 0.13), type: .atom(.hydrogen)),
      ]
    case .amine:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.nitrogen)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .silane:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.silicon)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(0.00, 0.30, 0.13), type: .atom(.hydrogen)),
      ]
    case .phosphane:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.phosphorus)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .gallane:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.gallium)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .germane:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.germanium)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(0.00, 0.30, 0.13), type: .atom(.hydrogen)),
      ]
    case .arsane:
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(.arsenic)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(.hydrogen)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(.hydrogen)),
      ]
    case .trihalogenide(let element1, let element2, let element3, let element4):
      return [
        Entity(position: SIMD3(0.00, 0.20, 0.02), type: .atom(element1)),
        Entity(position: SIMD3(0.10, 0.30, 0.00), type: .atom(element2)),
        Entity(position: SIMD3(-0.10, 0.30, 0.00), type: .atom(element3)),
        Entity(position: SIMD3(0.00, 0.30, 0.13), type: .atom(element4)),
      ]
    }
  }
  
  mutating func setApexPassivators(
    _ passivators: [Element],
    frameworkType: CageFrameworkType
  ) {
    guard passivators.count == 6 else {
      fatalError("Got \(passivators.count) passivators, but expected 6.")
    }
    
    // Pick the starting index in the apex's array of atoms.
    var offset: Int
    switch frameworkType {
    case .adamantane:
      offset = 2
    case .adamantasilane:
      offset = 2
    case .carbatrane:
      offset = 3
    }
    
    apex[offset + 0].atomicNumber = passivators[0].rawValue
    apex[offset + 1].atomicNumber = passivators[1].rawValue
    apex[offset + 3].atomicNumber = passivators[2].rawValue
    apex[offset + 4].atomicNumber = passivators[3].rawValue
    apex[offset + 6].atomicNumber = passivators[4].rawValue
    apex[offset + 7].atomicNumber = passivators[5].rawValue
  }
}

// MARK: - Minimization

extension CageTooltip {
  // Energy Minimization:
  // - anchoring
  //   - check stability of each family without anchoring S/O
  //   - otherwise, anchored at binding site
  //   - should the H also be anchored?
  // - full xTB level of theory
  //   - largest feedstock: -SiHBr2 (28 orbitals)
  //   - largest cage: atrane (64 orbitals)
  //   - largest leg: trifluorobenzene-OH (3 x 43 orbitals)
  //   - total orbitals: ≤221
  // - record minimization frames, save to disk
  //   - key: atom data, bond data, anchor IDs
  //   - new hashing protocol for bonds and anchor IDs
  // - separate function loads trajectory, overwrites atoms
  //   - checks that atomic numbers are identical
  // - idea: implement the caching part inside the minimize() function
  // - idea: hold the center atom fixed as an anchor
  // - idea: intercept FIRE, so the forces on the leg sulfurs are averaged to
  //   the same value. That should force them to have the same elevation. Also,
  //   make the positions in the FIRE minimizer mutable to the public API.
  func runMinimization() -> [[Entity]] {
    // Set up the calculator.
    let initialAtoms = feedstock + apex + framework + legs
    
    var calculatorDesc = xTB_CalculatorDescriptor()
    calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
    calculatorDesc.positions = initialAtoms.map(\.position)
    let calculator = xTB_Calculator(descriptor: calculatorDesc)
    
    // Set up an energy minimization.
    var minimizationDesc = FIREMinimizationDescriptor()
    minimizationDesc.anchors = [UInt32(feedstock.count)] // apex atom
    minimizationDesc.masses = initialAtoms.map {
      if $0.atomicNumber == 1 {
        return Float(4.0 * 1.660539)
      } else {
        return Float(12.011 * 1.660539)
      }
    }
    minimizationDesc.positions = initialAtoms.map(\.position)
    var minimization = FIREMinimization(descriptor: minimizationDesc)
    
    // Find the sulfur indices.
    var legsSulfurIDs: [UInt32] = []
    do {
      let atomStart = feedstock.count + apex.count
      for atomID in atomStart..<initialAtoms.count {
        let atom = initialAtoms[atomID]
        if atom.atomicNumber == linkerType.element.rawValue {
          legsSulfurIDs.append(UInt32(atomID))
        }
      }
    }
    guard legsSulfurIDs.count == 3 else {
      fatalError("Failed to locate all the sulfurs on the legs.")
    }
    
    // Iterate through the timesteps.
    var frames: [[Entity]] = [initialAtoms]
    for _ in 0..<500 {
      calculator.molecule.positions = minimization.positions
      
      // Enforce the constraints on leg sulfurs.
      var forces = calculator.molecule.forces
      do {
        var forceAccumulator: Float = .zero
        for atomID in legsSulfurIDs {
          let force = forces[Int(atomID)]
          forceAccumulator += force.y
        }
        forceAccumulator /= 3
        for atomID in legsSulfurIDs {
          var force = forces[Int(atomID)]
          force.y = forceAccumulator
          forces[Int(atomID)] = force
        }
      }
      
      var maximumForce: Float = .zero
      for atomID in calculator.molecule.atomicNumbers.indices {
        if minimization.anchors.contains(UInt32(atomID)) {
          continue
        }
        let force = forces[atomID]
        let forceMagnitude = (force * force).sum().squareRoot()
        maximumForce = max(maximumForce, forceMagnitude)
      }
      
      print("time: \(Format.time(minimization.time))", terminator: " | ")
      print("energy: \(Format.energy(calculator.energy))", terminator: " | ")
      print("max force: \(Format.force(maximumForce))", terminator: " | ")
      
      let converged = minimization.step(forces: forces)
      if !converged {
        print("Δt: \(Format.time(minimization.Δt))", terminator: " | ")
      }
      print()
      
      if converged {
        break
      }
      
      // Enforce the constraints on leg sulfurs.
      do {
        var positions = minimization.positions
        var positionAccumulator: Float = .zero
        for atomID in legsSulfurIDs {
          let position = positions[Int(atomID)]
          positionAccumulator += position.y
        }
        positionAccumulator /= 3
        for atomID in legsSulfurIDs {
          var position = positions[Int(atomID)]
          position.y = positionAccumulator
          positions[Int(atomID)] = position
        }
        minimization.positions = positions
      }
      
      // Save the frame.
      var frame = initialAtoms
      for atomID in frame.indices {
        let position = minimization.positions[atomID]
        var atom = frame[atomID]
        atom.position = position
        frame[atomID] = atom
      }
      frames.append(frame)
    }
    
    return frames
  }
}

// MARK: - Serialization

extension CageTooltip {
  mutating func loadCachedValue() throws {
    // Find the path.
    let folder = URL(filePath: "/Users/philipturner/Documents/OpenMM/cache")
      .appending(path: "CageTooltip")
    let key = createKey()
    let file = folder.appending(
      component: "\(key).data", directoryHint: .notDirectory)
    
    // Load the cached value.
    var frames: [[Entity]]
    do {
      let data = try Data(contentsOf: file)
      frames = Serialization.decode(frames: data)
    } catch {
      frames = runMinimization()
      
      let data = Serialization.encode(frames: frames)
      try! data.write(to: file, options: .atomic)
    }
    
    // Choose the last frame.
    guard frames.count > 0 else {
      fatalError("No frames to load data from.")
    }
    var atoms = frames.last!
    
    // Load each chunk of the structure.
    feedstock = Array(atoms[0..<feedstock.count])
    atoms =  Array(atoms[feedstock.count...])
    
    apex = Array(atoms[0..<apex.count])
    atoms = Array(atoms[apex.count...])
    
    framework = Array(atoms[0..<framework.count])
    atoms = Array(atoms[framework.count...])
    
    legs = Array(atoms[0..<legs.count])
    atoms = Array(atoms[legs.count...])
    
    guard atoms.count == .zero else {
      fatalError("Failed to decode all of the atoms.")
    }
  }
  
  // Procedure for generating a unique identifier for the current state.
  func createKey() -> String {
    let atoms = feedstock + apex + framework + legs
    let key = Serialization.hash(atoms: atoms)
    
    // RFC 3548 encoding: https://www.rfc-editor.org/rfc/rfc3548#page-6
    // "/" -> "_"
    // "+" -> "-"
    var base64Key = key.base64EncodedString()
    do {
      // Fetch the null-terminated C string.
      var cString = base64Key.utf8CString
      for characterID in cString.indices {
        let byte = cString[characterID]
        let scalar = UnicodeScalar(UInt32(byte))!
        var character = Character(scalar)
        
        if character == "/" {
          character = "_"
        } else if character == "+" {
          character = "-"
        }
        cString[characterID] = CChar(character.asciiValue!)
      }
      base64Key = String(cString: Array(cString))
    }
    return base64Key
  }
}

// MARK: - Positioning

extension CageTooltip {
  mutating func translate(offset: SIMD3<Float>) {
    func translate(fragment: inout [Entity]) {
      for atomID in fragment.indices {
        var atom = fragment[atomID]
        atom.position += offset
        fragment[atomID] = atom
      }
    }
    translate(fragment: &feedstock)
    translate(fragment: &apex)
    translate(fragment: &framework)
    translate(fragment: &legs)
  }
  
  mutating func rotate(angle: Float, axis: SIMD3<Float>) {
    let rotation = Quaternion<Float>(angle: angle, axis: axis)
    let centerOfMass = apex[0].position
    
    func rotate(fragment: inout [Entity]) {
      for atomID in fragment.indices {
        var atom = fragment[atomID]
        var delta = atom.position - centerOfMass
        delta = rotation.act(on: delta)
        atom.position = centerOfMass + delta
        fragment[atomID] = atom
      }
    }
    rotate(fragment: &feedstock)
    rotate(fragment: &apex)
    rotate(fragment: &framework)
    rotate(fragment: &legs)
  }
}

// MARK: - Fragmentation

extension CageTooltip {
  static func createApexFrameworkBoundary(
    frameworkType: CageFrameworkType
  ) -> [SIMD2<UInt32>] {
    switch frameworkType {
    case .adamantane, .adamantasilane:
      return [
        SIMD2(1, 3),
        SIMD2(4, 7),
        SIMD2(7, 11),
      ]
    case .carbatrane:
      return [
        // N-H bonds
        SIMD2(1, 0),
        SIMD2(1, 5),
        SIMD2(1, 10),
        
        // C-H bonds
        SIMD2(2, 3),
        SIMD2(5, 8),
        SIMD2(8, 13),
      ]
    }
  }
  
  static func createFrameworkLegsBoundary(
    frameworkType: CageFrameworkType
  ) -> [SIMD2<UInt32>] {
    switch frameworkType {
    case .adamantane, .adamantasilane:
      return [
        SIMD2(3, 2),
        SIMD2(7, 7),
        SIMD2(11, 12),
      ]
    case .carbatrane:
      return [
        SIMD2(3, 2),
        SIMD2(8, 7),
        SIMD2(13, 12),
      ]
    }
  }
  
  static func createLinkAtoms(
    inner: [Entity],
    outer: [Entity],
    boundary: [SIMD2<UInt32>]
  ) -> [Entity] {
    var boundaryHydrogens: [Entity] = []
    for bond in boundary {
      // Retrieve the atoms from their respective arrays.
      guard bond[0] < inner.count,
            bond[1] < outer.count else {
        fatalError("Bond had invalid indices.")
      }
      let innerAtom = inner[Int(bond[0])]
      let outerAtom = outer[Int(bond[1])]
      
      // Determine the ratio of bond distances.
      var d1: Float
      var d2: Float
      switch (innerAtom.atomicNumber, outerAtom.atomicNumber) {
      case (6, 6):
        // Source: MM4Parameters
        d1 = 1.1120 / 10
        d2 = 1.5270 / 10
      case (7, 6):
        // Source: MM4-amine-params
        d1 = 1.0340 / 10
        d2 = 1.4585 / 10
      case (14, 14):
        // Source: MM4Parameters
        d1 = 1.483 / 10
        d2 = 2.322 / 10
      default:
        fatalError("""
          Unrecognized atom pair: \
          \(innerAtom.atomicNumber), \(outerAtom.atomicNumber)
          """)
      }
      
      // Generate an orbital from the bond vector, and scale it.
      let delta = outerAtom.position - innerAtom.position
      let hydrogenPosition = innerAtom.position + (d1 / d2) * delta
      let hydrogen = Entity(
        position: hydrogenPosition, type: .atom(.hydrogen))
      boundaryHydrogens.append(hydrogen)
    }
    return boundaryHydrogens
  }
}
