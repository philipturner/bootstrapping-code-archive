//
//  GoldTooltip.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/19/24.
//

import Foundation
import HDL
import xTB

enum GoldTooltipType {
  case au17
  case au25
  case au32
  case au40
}

// Gold tooltip structure.
struct GoldTooltip {
  var apex: [Entity]
  var surface: [Entity]
  var anchors: [Entity]
  
  init(type: GoldTooltipType) {
    let lattice = Self.createLattice(type: type)
    let topology = Self.createTopology(lattice: lattice)
    
    switch type {
    case .au17, .au32:
      apex = [topology.atoms[0]]
      surface = Array(topology.atoms[1..<4])
      anchors = Array(topology.atoms[4...])
    case .au25, .au40:
      apex = [topology.atoms[0]]
      surface = Array(topology.atoms[1..<5])
      anchors = Array(topology.atoms[5...])
    }
  }
  
  static func createLattice(type: GoldTooltipType) -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 10 * k + 10 * l }
      Material { .elemental(.gold) }
      
      // Shape the tip.
      Volume {
        Convex {
          switch type {
          case .au17, .au32:
            Origin { 2 * h + 2 * l }
          case .au25, .au40:
            Origin { 2 * h + 3 * l }
          }
          Origin { 2 * k }
          Plane { -h + k + l }
        }
        Convex {
          Origin { 3 * h + 2 * l }
          Origin { 2 * k }
          Plane { h + k - l }
        }
        Convex {
          Origin { 3 * h + 2 * l }
          Origin { 2 * k }
          Plane { h - k + l }
        }
        Replace { .empty }
      }
      
      // Mark the apical atom.
      Volume {
        Origin { 3.25 * h + 2.25 * l }
        Origin { 2 * k }
        Plane { h + k + l }
        Replace { .atom(.lead) }
      }
      
      // Shape the back side.
      Volume {
        Convex {
          switch type {
          case .au17, .au25:
            Origin { 2.5 * h }
          case .au32, .au40:
            Origin { 1.5 * h }
          }
          Origin { 2 * k }
          Plane { -h - k - l }
        }
        Concave {
          switch type {
          case .au17, .au25:
            Origin { 1.5 * k }
            Origin { 1.5 * l }
          case .au32, .au40:
            Origin { 1 * k }
            Origin { 1 * l }
          }
          Plane { -k }
          Plane { -l }
        }
        Concave {
          switch type {
          case .au17:
            Origin { 3 * h }
          case .au25, .au32, .au40:
            Origin { 2 * h }
          }
          Plane { -h - l }
        }
        Concave {
          switch type {
          case .au17:
            Origin { 3 * h }
          case .au25, .au32, .au40:
            Origin { 2 * h }
          }
          Plane { -h - k }
        }
        Replace { .empty }
      }
      
      // Shape the extra atomic layer for Au40.
      Volume {
        Convex {
          Origin { 2.75 * k }
          Plane { k }
        }
        Convex {
          Origin { 2.75 * l }
          Plane { l }
        }
        Replace { .empty }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    var topology = Topology()
    topology.insert(atoms: lattice.atoms)
    
    // Center the atoms at the origin.
    do {
      var leadPosition: SIMD3<Float>?
      for atomID in topology.atoms.indices {
        let atom = topology.atoms[atomID]
        guard atom.atomicNumber == 82 else {
          continue
        }
        leadPosition = atom.position
      }
      guard let leadPosition else {
        fatalError("Could not find lead atom position.")
      }
      for atomID in topology.atoms.indices {
        var atom = topology.atoms[atomID]
        atom.position -= leadPosition
        topology.atoms[atomID] = atom
      }
    }
    
    // Rotate the atoms, so the tip points straight down.
    do {
      var eigenvector0 = SIMD3<Float>(1, 0, -1)
      var eigenvector1 = SIMD3<Float>(-1, -1, -1)
      var eigenvector2 = SIMD3<Float>(1, -2, 1)
      eigenvector0 /= (eigenvector0 * eigenvector0).sum().squareRoot()
      eigenvector1 /= (eigenvector1 * eigenvector1).sum().squareRoot()
      eigenvector2 /= (eigenvector2 * eigenvector2).sum().squareRoot()
      
      // Iterate over the atoms.
      for atomID in topology.atoms.indices {
        var atom = topology.atoms[atomID]
        var position = atom.position
        
        let coordinate0 = (position * eigenvector0).sum()
        let coordinate1 = (position * eigenvector1).sum()
        let coordinate2 = (position * eigenvector2).sum()
        position = SIMD3(coordinate0, coordinate1, coordinate2)
        
        atom.position = position
        topology.atoms[atomID] = atom
      }
    }
    
    // Sort by y-coordinate.
    topology.atoms.sort(by: {
      $0.position.y < $1.position.y
    })
    
    // Remove the markers.
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.atomicNumber = 79
      topology.atoms[atomID] = atom
    }
    
    return topology
  }
}

// MARK: - Minimization

extension GoldTooltip {
  struct MinimizationDescriptor {
    var electronicTemperature: Float?
    var maximumFIREIterations: Int?
    var maximumSCFIterations: Int?
  }
  
  // Run an energy minimization and return the trajectory.
  func runMinimization(descriptor: MinimizationDescriptor) -> [[Entity]] {
    guard let electronicTemperature = descriptor.electronicTemperature,
          let maximumFIREIterations = descriptor.maximumFIREIterations,
          let maximumSCFIterations = descriptor.maximumSCFIterations else {
      fatalError("Descriptor was incomplete.")
    }
    
    let atoms = apex + surface + anchors
    
    var calculatorDesc = xTB_CalculatorDescriptor()
    calculatorDesc.atomicNumbers = atoms.map(\.atomicNumber)
    calculatorDesc.positions = atoms.map(\.position)
    
    let calculator = xTB_Calculator(descriptor: calculatorDesc)
    calculator.electronicTemperature = electronicTemperature
    calculator.maximumIterations = maximumSCFIterations
    print()
    print(calculator.energy)
    
    // Set up an energy minimization.
    var minimizationDesc = FIREMinimizationDescriptor()
    do {
      let atomStart = UInt32(apex.count + surface.count)
      let atomCount = UInt32(atoms.count)
      minimizationDesc.anchors = Set(Array(atomStart..<atomCount))
    }
    minimizationDesc.masses = atoms.map {
      if $0.atomicNumber == 1 {
        return Float(4.0 * 1.660539)
      } else {
        return Float(12.011 * 1.660539)
      }
    }
    minimizationDesc.positions = atoms.map(\.position)
    var minimization = FIREMinimization(descriptor: minimizationDesc)
    
    // Iterate through the timesteps.
    print()
    var frames: [[Entity]] = [atoms]
    for _ in 0..<maximumFIREIterations {
      calculator.molecule.positions = minimization.positions
      
      var forces = calculator.molecule.forces
      var maximumForce: Float = .zero
      for atomID in calculator.molecule.atomicNumbers.indices {
        if minimization.anchors.contains(UInt32(atomID)) {
          continue
        }
        var force = forces[atomID]
        var forceMagnitude = (force * force).sum().squareRoot()
        if forceMagnitude > 50000 {
          force *= 50000 / forceMagnitude
          forceMagnitude = 50000
        }
        maximumForce = max(maximumForce, forceMagnitude)
        forces[atomID] = force
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
        // Abnormal termination.
        break
      }
      
      var frame = atoms
      for atomID in frame.indices {
        let position = minimization.positions[atomID]
        var atom = frame[atomID]
        atom.position = position
        frame[atomID] = atom
      }
      frames.append(frame)
    }
    
    // Return the initial structure plus the state during each singlepoint.
    return frames
  }
}

// MARK: - Serialization

extension GoldTooltip {
  mutating func loadCachedValue() throws {
    // Find the path.
    let folder = URL(filePath: "/Users/philipturner/Documents/OpenMM/cache")
      .appending(path: "GoldTooltip")
    let key = createKey()
    let file = folder.appending(
      component: "\(key).data", directoryHint: .notDirectory)
    
    // Load the cached value.
    let data = try Data(contentsOf: file)
    let frames = Serialization.decode(frames: data)
    
    // Choose the last frame.
    guard frames.count > 0 else {
      fatalError("No frames to load data from.")
    }
    var atoms = frames.last!
    
    // Load each chunk of the structure.
    apex = Array(atoms[0..<apex.count])
    atoms = Array(atoms[apex.count...])
    
    surface = Array(atoms[0..<surface.count])
    atoms = Array(atoms[surface.count...])
    
    anchors = Array(atoms[0..<anchors.count])
    atoms = Array(atoms[anchors.count...])
    
    guard atoms.count == .zero else {
      fatalError("Failed to decode all of the atoms.")
    }
  }
  
  // Procedure for generating a unique identifier for the current state.
  func createKey() -> String {
    let atoms = apex + surface + anchors
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

extension GoldTooltip {
  mutating func translate(offset: SIMD3<Float>) {
    func translate(fragment: inout [Entity]) {
      for atomID in fragment.indices {
        var atom = fragment[atomID]
        atom.position += offset
        fragment[atomID] = atom
      }
    }
    translate(fragment: &apex)
    translate(fragment: &surface)
    translate(fragment: &anchors)
  }
}
