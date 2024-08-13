//
//  Silicon111Tooltip.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/23/24.
//

import Foundation
import HDL
import MM4
import xTB

enum Silicon111TooltipType {
  // 10 silicon atom model.
  case modelA
  
  // 13 silicon atom model.
  case modelS
  
  // 19 silicon atom model.
  case modelL
  
  // 13 silicon atom model, for overhangs.
  case modelO
  
  // 13 silicon atom model, for simulating a 2nd generation tooltip on.
  case modelInvertedS
}

struct Silicon111Tooltip {
  // The atoms included in quantum mechanical simulation.
  var surface: [Entity]
  
  // The atoms omitted from quantum mechanical simulation.
  var anchors: [Entity]
  
  // The bonds along the surface-anchor boundary.
  var boundary: [SIMD2<UInt32>]
  
  init(type: Silicon111TooltipType) {
    // Choose the lattice for this type.
    var lattice: Lattice<Cubic>
    switch type {
    case .modelA:
      lattice = Self.createModelALattice()
    case .modelS:
      lattice = Self.createModelSLattice()
    case .modelL:
      lattice = Self.createModelLLattice()
    case .modelO:
      lattice = Self.createModelOLattice()
    case .modelInvertedS:
      lattice = Self.createModelInvertedSLattice()
    }
    
    // Center the reaction site at the origin.
    var latticeAtoms = lattice.atoms
    Self.position(atoms: &latticeAtoms, type: type)
    
    // Load the energy-minimized atoms.
    let bulkModel = Silicon111BulkModel(atoms: latticeAtoms, type: type)
    var minimizedAtoms: [Entity] = []
    for atomID in bulkModel.atomicNumbers.indices {
      let atomicNumber = bulkModel.atomicNumbers[atomID]
      let position = bulkModel.rigidBody.positions[atomID]
      let element = Element(rawValue: atomicNumber)!
      let atom = Entity(position: position, type: .atom(element))
      minimizedAtoms.append(atom)
    }
    
    // Create a topology for fragmentation.
    var topology = Topology()
    topology.insert(atoms: minimizedAtoms)
    topology.insert(bonds: bulkModel.rigidBody.parameters.bonds.indices)
    (surface, anchors, boundary) = Silicon111Tooltip
      .fragment(topology: topology)
    
    // Change the Ge markers back into Si.
    for atomID in surface.indices {
      var atom = surface[atomID]
      if atom.atomicNumber == 32 {
        atom.atomicNumber = 14
      }
      surface[atomID] = atom
    }
    
    // Load the energy-minimized surface.
    minimizeSurface()
  }
  
  static func createModelALattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 4 * (h + k + l) }
      Material { .elemental(.silicon) }
      
      Volume {
        Convex {
          Origin { 1.75 * (h + k + l) }
          Plane { h + k + l }
        }
        
        Replace { .empty }
      }
      
      // Highlight atoms for simulating quantum mechanically.
      Volume {
        Concave {
          // Cut out a prism aligned with (111).
          Concave {
            Convex {
              Origin { 0.75 * h }
              Plane { -2 * h + k + l }
            }
            Convex {
              Origin { -0.75 * h }
              Plane { 2 * h - k - l }
            }
            
            Convex {
              Origin { 0.75 * k }
              Plane { h - 2 * k + l }
            }
            Convex {
              Origin { -0.75 * k }
              Plane { -h + 2 * k - l }
            }
            
            Convex {
              Origin { 0.75 * l }
              Plane { h + k - 2 * l }
            }
            Convex {
              Origin { -0.75 * l }
              Plane { -h - k + 2 * l }
            }
          }
          
          // Cut off the back side.
          Concave {
            Convex {
              Origin { 1 * (h + k + l) }
              Plane { h + k + l }
            }
          }
        }
        
        Replace { .atom(.germanium) }
      }
    }
  }
  
  static func createModelSLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 4 * (h + k + l) }
      Material { .elemental(.silicon) }
      
      Volume {
        Origin { 2 * (h + k + l) }
        Plane { h + k + l }
        Replace { .empty }
      }
      
      // Highlight atoms for simulating quantum mechanically.
      Volume {
        Concave {
          // Cut out a hexagon.
          Concave {
            Convex {
              Origin { 1 * h }
              Plane { h }
            }
            Convex {
              Origin { 2.75 * h }
              Plane { -h }
            }
            Convex {
              Origin { 1 * k }
              Plane { k }
            }
            Convex {
              Origin { 2.75 * k }
              Plane { -k }
            }
            Convex {
              Origin { 1 * l }
              Plane { l }
            }
            Convex {
              Origin { 2.75 * l }
              Plane { -l }
            }
          }
          
          // Shape the back side.
          Concave {
            Convex {
              Origin { 1.75 * (h + k + l) }
              Plane { h + k + l }
            }
          }
        }
        Replace { .atom(.germanium) }
      }
    }
  }
  
  static func createModelLLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 4 * (h + k + l) }
      Material { .elemental(.silicon) }
      
      Volume {
        Origin { 2 * (h + k + l) }
        Plane { h + k + l }
        Replace { .empty }
      }
      
      // Highlight atoms for simulating quantum mechanically.
      Volume {
        Concave {
          // Cut out a hexagon.
          Concave {
            Convex {
              Origin { 1 * h }
              Plane { h }
            }
            Convex {
              Origin { 2.75 * h }
              Plane { -h }
            }
            Convex {
              Origin { 1 * k }
              Plane { k }
            }
            Convex {
              Origin { 2.75 * k }
              Plane { -k }
            }
            Convex {
              Origin { 1 * l }
              Plane { l }
            }
            Convex {
              Origin { 2.75 * l }
              Plane { -l }
            }
          }
          
          // Shape the bottom cage for the "L" model.
          Concave {
            Convex {
              Origin { -0.25 * h }
              Plane { -h + k + l }
            }
            Convex {
              Origin { -0.25 * k }
              Plane { h - k + l }
            }
            Convex {
              Origin { -0.25 * l }
              Plane { h + k - l }
            }
          }
          
          // Shape the back side.
          Concave {
            Convex {
              Origin { 1.5 * (h + k + l) }
              Plane { h + k + l }
            }
          }
        }
        Replace { .atom(.germanium) }
      }
    }
  }
  
  static func createModelOLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 4 * (h + k + l) }
      Material { .elemental(.silicon) }

      Volume {
        Concave {
          Convex {
            Origin { 2.00 * (h + k + l) }
            Plane { h + k + l }
          }
          Convex {
            // Cut out the front-diagonal.
            Convex {
              Origin { 2.50 * (h + k + l) }
              Plane { h + k + l }
            }
            
            // Cut out the lower wall.
            Convex {
              Origin { 2.00 * h + 1.75 * k + 2.00 * l }
              Plane { h - 2 * k + l }
            }
            
            // Cut out the side walls.
            Convex {
              Origin { 2.5 * (k + l) }
              Plane { k + l }
            }
            Convex {
              Origin { 2.5 * (k + h) }
              Plane { k + h }
            }
          }
        }
        Replace { .empty }
      }
      
      // Highlight atoms for simulating quantum mechanically.
      Volume {
        Concave {
          // Highlight the front-diagonal.
          Convex {
            Origin { 2.50 * (h + k + l) }
            Plane { -h - k - l }
          }
          
          // Highlight the upper and lower walls.
          Convex {
            Origin { 2.25 * h + 1.75 * k + 2.25 * l }
            Plane { -h + 2 * k - l }
          }
          Convex {
            Origin { 0.5 * h + 1.75 * k + 0.5 * l }
            Plane { h - 2 * k + l }
          }
          
          // Highlight the side walls.
          Convex {
            Origin { 4 * l }
            Plane { h - k - l }
          }
          Convex {
            Origin { 4 * h }
            Plane { -h - k + l }
          }
          
          // Remove the stragglers.
          Convex {
            Origin { 0.75 * h }
            Plane { h + k - l }
          }
          Convex {
            Origin { 0.75 * l }
            Plane { -h + k + l }
          }
          
          // Highlight the back-diagonal.
          Convex {
            Origin { 1.75 * (h + k + l) }
            Plane { h + k + l }
          }
          
          // Cut out 5 atoms that aren't needed.
          Convex {
            Convex {
              Origin { 2.00 * (h + k + l) }
              Plane { h + k + l }
            }
            Convex {
              Origin { 0.75 * (h + l) }
              Plane { h - k + l }
            }
          }
        }
        
        Replace { .atom(.germanium) }
      }
    }
  }
  
  static func createModelInvertedSLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 4 * (h + k + l) }
      Material { .elemental(.silicon) }
      
      Volume {
        Origin { 2.5 * (h + k + l) }
        Plane { h + k + l }
        Replace { .empty }
      }
      
      // Highlight atoms for simulating quantum mechanically.
      Volume {
        Concave {
          // Cut out a hexagon.
          Concave {
            Convex {
              Origin { 1.5 * h }
              Plane { h }
            }
            Convex {
              Origin { 3.25 * h }
              Plane { -h }
            }
            Convex {
              Origin { 1.5 * k }
              Plane { k }
            }
            Convex {
              Origin { 3.25 * k }
              Plane { -k }
            }
            Convex {
              Origin { 1.5 * l }
              Plane { l }
            }
            Convex {
              Origin { 3.25 * l }
              Plane { -l }
            }
          }
          
          // Shape the back side.
          Concave {
            Convex {
              Origin { 2.00 * (h + k + l) }
              Plane { h + k + l }
            }
          }
        }
        Replace { .atom(.germanium) }
      }
    }
  }
  
  // Translates and rotates the lattice, so the surface layer is at Z = 0.
  static func position(
    atoms: inout [Entity],
    type: Silicon111TooltipType
  ) {
    var eigenvector0 = SIMD3<Float>(1, 0, -1)
    var eigenvector1 = SIMD3<Float>(-1, -1, -1)
    var eigenvector2 = SIMD3<Float>(1, -2, 1)
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
      
      switch type {
      case .modelA:
        position.y += 1.5677946
      case .modelS:
        position.y += 1.8813536
      case .modelL:
        position.y += 1.8813536
      case .modelO:
        position.y += 1.8813536
      case .modelInvertedS:
        position.y += 2.1949127
      }
      
      atom.position = position
      atoms[atomID] = atom
    }
  }
  
  // Fragments the topology into two parts.
  static func fragment(topology: Topology) -> (
    surface: [Entity], anchors: [Entity], boundary: [SIMD2<UInt32>]
  ) {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    // Each atom's new ID, in whatever list it was assigned to.
    var newAtomIDs = [UInt32](repeating: .max, count: topology.atoms.count)
    var surface: [Entity] = []
    var surfaceHydrogens: [Entity] = []
    var anchors: [Entity] = []
    var anchorHydrogens: [Entity] = []
    
    // Iterate over the silicon atoms.
    for atomID in topology.atoms.indices {
      // Omit the hydrogens from this loop.
      let atom = topology.atoms[atomID]
      if atom.atomicNumber == 1 {
        continue
      }
      
      // Determine which fragment this belongs to.
      let isSurface = (atom.atomicNumber == 32)
      
      // Find the new ID.
      var newAtomID: UInt32
      if isSurface {
        newAtomID = UInt32(surface.count)
      } else {
        newAtomID = UInt32(anchors.count)
      }
      
      // Write the new ID.
      newAtomIDs[Int(atomID)] = newAtomID
      
      // Write the atom.
      if isSurface {
        surface.append(atom)
      } else {
        anchors.append(atom)
      }
      
      // Iterate over the neighbors.
      let atomsMap = atomsToAtomsMap[atomID]
      for otherAtomID in atomsMap {
        // Only process the hydrogens in this loop.
        let otherAtom = topology.atoms[Int(otherAtomID)]
        guard otherAtom.atomicNumber == 1 else {
          continue
        }
        
        if isSurface {
          surfaceHydrogens.append(otherAtom)
        } else {
          anchorHydrogens.append(otherAtom)
        }
      }
    }
    
    // Generate the links between the layers.
    var boundary: [SIMD2<UInt32>] = []
    for bondID in topology.bonds.indices {
      let bond = topology.bonds[bondID]
      
      var siliconID: UInt32?
      var germaniumID: UInt32?
      for laneID in 0..<2 {
        let atomID = bond[laneID]
        let atom = topology.atoms[Int(atomID)]
        if atom.atomicNumber == 14 {
          siliconID = UInt32(atomID)
        } else if atom.atomicNumber == 32 {
          germaniumID = UInt32(atomID)
        }
      }
      guard let siliconID,
            let germaniumID else {
        continue
      }
      
      // The Ge marker goes on the inside.
      let newGermaniumID = newAtomIDs[Int(germaniumID)]
      let newSiliconID = newAtomIDs[Int(siliconID)]
      let link = SIMD2<UInt32>(newGermaniumID, newSiliconID)
      boundary.append(link)
    }
    
    // Add the hydrogens to the end of each list.
    surface += surfaceHydrogens
    anchors += anchorHydrogens
    
    // Finally, return the components of the topology.
    return (surface, anchors, boundary)
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

// Optimizing the bulk region at the MM4 level of theory.
struct Silicon111BulkModel: MM4GenericPart {
  var atomicNumbers: [UInt8]
  var rigidBody: MM4RigidBody
  
  init(
    atoms: [Entity],
    type: Silicon111TooltipType
  ) {
    var reconstruction = Reconstruction()
    reconstruction.material = .elemental(.silicon)
    reconstruction.topology.insert(atoms: atoms)
    reconstruction.compile()
    
    // Save the compiled atomic numbers.
    var topology = reconstruction.topology
    atomicNumbers = topology.atoms.map(\.atomicNumber)
    
    // Switch the Ge markers over to Si, so they can be parametrized and
    // expected distances between bulk atoms will be correct.
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 32 {
        atom.atomicNumber = 14
      }
      topology.atoms[atomID] = atom
    }
    rigidBody = Self.createRigidBody(topology: topology)
    
    // Choose a file name for the structure.
    let cacheFolder =
    "/Users/philipturner/Documents/OpenMM/cache/Silicon111BulkModel"
    let folder = URL(filePath: cacheFolder)
    let key = Serialization.fileSafeString("\(type)")
    let file = folder.appending(
      component: "\(key).data", directoryHint: .notDirectory)
    
    // Create the structure in one of two ways.
    do {
      let data = try Data(contentsOf: file)
      let frames = Serialization.decode(frames: data)
      guard frames.count == 1 else {
        fatalError("The number of serialized frames was incorrect.")
      }
      let structure = frames[0]
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = structure.map(\.position)
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    } catch {
      let bulkAtomIDs = Self.extractBulkAtomIDs(topology: topology)
      minimize(anchors: Set(bulkAtomIDs))
      
      // Convert to an array of 'Element'.
      let structure = zip(atomicNumbers, rigidBody.positions).map {
        let element = Element(rawValue: $0)!
        let atom = Entity(position: $1, type: .atom(element))
        return atom
      }
      let data = Serialization.encode(frames: [structure])
      try! data.write(to: file, options: .atomic)
    }
  }
}

// Optimizing the inner region at the xTB level of theory.
extension Silicon111Tooltip {
  func runMinimization() -> [[Entity]] {
    // Set up the calculator.
    let initialLinkAtoms = Silicon111Tooltip
      .createLinkAtoms(inner: surface, outer: anchors, boundary: boundary)
    let initialAtoms = surface + initialLinkAtoms
    
    var calculatorDesc = xTB_CalculatorDescriptor()
    calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
    calculatorDesc.positions = initialAtoms.map(\.position)
    let calculator = xTB_Calculator(descriptor: calculatorDesc)
    
    // Set up an energy minimization.
    var minimizationDesc = FIREMinimizationDescriptor()
    minimizationDesc.anchors = Set(
      Array(surface.count..<initialAtoms.count).map(UInt32.init))
    minimizationDesc.masses = initialAtoms.map {
      if $0.atomicNumber == 1 {
        return Float(4.0 * 1.660539)
      } else {
        return Float(12.011 * 1.660539)
      }
    }
    minimizationDesc.positions = initialAtoms.map(\.position)
    var minimization = FIREMinimization(descriptor: minimizationDesc)
    
    // Iterate through the timesteps.
    var frames: [[Entity]] = [surface]
    for _ in 0..<500 {
      // Enforce the constraints on link atoms.
      do {
        var inner = surface
        for atomID in inner.indices {
          var atom = inner[atomID]
          atom.position = minimization.positions[atomID]
          inner[atomID] = atom
        }
        let linkAtoms = Silicon111Tooltip
          .createLinkAtoms(inner: inner, outer: anchors, boundary: boundary)
        
        for atomID in linkAtoms.indices {
          let linkAtom = linkAtoms[atomID]
          let position = linkAtom.position
          
          let projectedAtomID = surface.count + atomID
          minimization.positions[projectedAtomID] = position
        }
      }
      calculator.molecule.positions = minimization.positions
      
      // Fetch the forces.
      var forces = calculator.molecule.forces
      
      // Clamp the magnitude of the forces.
      for forceID in forces.indices {
        var force = forces[forceID]
        let forceMagnitude = (force * force).sum().squareRoot()
        if forceMagnitude > 20000 {
          force *= 20000 / forceMagnitude
        }
        forces[forceID] = force
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
      
      // Save the frame.
      var frame: [Entity] = []
      for atomID in surface.indices {
        var atom = surface[atomID]
        atom.position = minimization.positions[atomID]
        frame.append(atom)
      }
      frames.append(frame)
    }
    
    return frames
  }
  
  // Procedure for generating a unique identifier for the current state.
  func createKey() -> String {
    let atoms = surface
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
  
  mutating func minimizeSurface() {
    // Choose a file name for the trajectory.
    let cacheFolder =
    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Tooltip"
    let folder = URL(filePath: cacheFolder)
    let key = createKey()
    let file = folder.appending(
      component: "\(key).data", directoryHint: .notDirectory)
    
    // Create the frames in one of two ways.
    var frames: [[Entity]]
    do {
      let data = try Data(contentsOf: file)
      frames = Serialization.decode(frames: data)
    } catch {
      frames = runMinimization()
      
      let data = Serialization.encode(frames: frames)
      try! data.write(to: file, options: .atomic)
    }
    
    // Choose the last frame as the optimized structure.
    let structure = frames.last!
    guard structure.count == surface.count else {
      fatalError("Optimized structure had incorrect atom count.")
    }
    surface = structure
  }
}
