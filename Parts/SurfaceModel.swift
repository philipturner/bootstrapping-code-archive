//
//  SurfaceModel.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/7/24.
//

import HDL
import MM4

enum SurfaceModelType {
  case silicon100
  case silicon110
  case silicon111
  case silicon311
  case gold111
}

struct SurfaceModel {
  var topology: Topology
  var type: SurfaceModelType
  var surfaceAtomIDs: [UInt32] = []
  
  init(type: SurfaceModelType) {
    self.type = type
    
    let lattice = Self.createLattice(type: type)
    switch type {
    case .silicon100, .silicon110, .silicon111, .silicon311:
      topology = Self.createSiliconTopology(lattice: lattice)
    case .gold111:
      topology = Self.createGoldTopology(lattice: lattice)
    }
    
    transmuteSurfaceAtoms()
    switch type {
    case .silicon100, .silicon110, .silicon111, .silicon311:
      minimize()
      depassivate()
    case .gold111:
      break
    }
    
    let basis = Self.basis(type: type)
    rotate(basis: basis)
    
    let center = Self.center(type: type)
    translate(center: center)
  }
  
  static func createLattice(type: SurfaceModelType) -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 10 * k + 10 * l }
      
      switch type {
      case .silicon100, .silicon110, .silicon111, .silicon311:
        Material { .elemental(.silicon) }
      case .gold111:
        Material { .elemental(.gold) }
      }
      
      switch type {
      case .silicon100:
        Volume {
          Origin { 5 * k }
          Plane { k }
          Replace { .empty }
        }
        
        Volume {
          Origin { 4.75 * k }
          Plane { k }
          Replace { .atom(.germanium) }
        }
        
      case .silicon110:
        Volume {
          Origin { 5.0 * h + 5.0 * k }
          Plane { h + k }
          Replace { .empty }
        }
        
        Volume {
          Origin { 4.75 * h + 4.75 * k }
          Plane { h + k }
          Replace { .atom(.germanium) }
        }
        
      case .silicon111:
        Volume {
          Origin { 5.0 * h + 5.0 * k + 5.0 * l }
          Plane { h + k + l }
          Replace { .empty }
        }
        
        Volume {
          Origin { 4.75 * h + 4.75 * k + 4.75 * l }
          Plane { h + k + l }
          Replace { .atom(.germanium) }
        }
        
      case .silicon311:
        Volume {
          Origin { 5.01 * h + 5.01 * k + 5.01 * l }
          Plane { 3 * h + k + l }
          Replace { .empty }
        }
        
        Volume {
          Origin { 4.75 * h + 4.75 * k + 4.75 * l }
          Plane { 3 * h + k + l }
          Replace { .atom(.germanium) }
        }
        
      case .gold111:
        Volume {
          Origin { 5.0 * h + 5.0 * k + 5.0 * l }
          Plane { h + k + l }
          Replace { .empty }
        }
        
        Volume {
          Origin { 4.75 * h + 4.75 * k + 4.75 * l }
          Plane { h + k + l }
          Replace { .atom(.tin) }
        }
      }
    }
  }
  
  static func createSiliconTopology(lattice: Lattice<Cubic>) -> Topology {
    guard lattice.atoms.allSatisfy({ $0.atomicNumber != 79 }) else {
      fatalError("Incorrect lattice.")
    }
    
    // Add passivation.
    var reconstruction = Reconstruction()
    reconstruction.material = .elemental(.silicon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
    return reconstruction.topology
  }
  
  static func createGoldTopology(lattice: Lattice<Cubic>) -> Topology {
    guard lattice.atoms.allSatisfy({ $0.atomicNumber != 14 }) else {
      fatalError("Incorrect lattice.")
    }
    
    var topology = Topology()
    topology.insert(atoms: lattice.atoms)
    return topology
  }
}

// MARK: - Energy Minimization

extension SurfaceModel {
  // Sets the surface atom IDs, while simultaneously restoring the atomic
  // numbers to the correct ones.
  mutating func transmuteSurfaceAtoms() {
    switch type {
    case .silicon100, .silicon110, .silicon111, .silicon311:
      for atomID in topology.atoms.indices {
        var atom = topology.atoms[atomID]
        if atom.atomicNumber == 32 {
          atom.atomicNumber = 14
          surfaceAtomIDs.append(UInt32(atomID))
        }
        topology.atoms[atomID] = atom
      }
    case .gold111:
      for atomID in topology.atoms.indices {
        var atom = topology.atoms[atomID]
        if atom.atomicNumber == 50 {
          atom.atomicNumber = 79
          surfaceAtomIDs.append(UInt32(atomID))
        }
        topology.atoms[atomID] = atom
      }
    }
  }
  
  // Extract the bulk atoms from a silicon lattice.
  static func extractBulkAtomIDs(topology: Topology) -> [UInt32] {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    var bulkAtomIDs: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let atomElement = Element(rawValue: atom.atomicNumber)!
      let atomRadius = atomElement.covalentRadius
      
      let neighborIDs = atomsToAtomsMap[atomID]
      var centerNeighborCount: Int = .zero
      var correctBondCount: Int = .zero
      
      for neighborID in neighborIDs {
        let neighbor = topology.atoms[Int(neighborID)]
        let neighborElement = Element(rawValue: neighbor.atomicNumber)!
        let neighborRadius = neighborElement.covalentRadius
        if neighbor.atomicNumber != 1,
           neighbor.atomicNumber != 9,
           neighbor.atomicNumber != 17,
           neighbor.atomicNumber != 35 {
          centerNeighborCount += 1
        }
        
        let delta = atom.position - neighbor.position
        let bondLength = (delta * delta).sum().squareRoot()
        let expectedBondLength = atomRadius + neighborRadius
        if bondLength / expectedBondLength < 1.1 {
          correctBondCount += 1
        }
      }
      
      if centerNeighborCount == 4, correctBondCount == 4 {
        bulkAtomIDs.append(UInt32(atomID))
      }
    }
    return bulkAtomIDs
  }
  
  // Extract the enclosed sublattice of the silicon lattice.
  static func createEnclosedSet(
    topology: Topology, bulkAtomIDs: [UInt32]
  ) -> [UInt32] {
    var output: [UInt32] = []
    
    let bulkAtomIDSet = Set(bulkAtomIDs)
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    for atomID in topology.atoms.indices {
      guard bulkAtomIDSet.contains(UInt32(atomID)) else {
        continue
      }
      let list = atomsToAtomsMap[atomID]
      
      var isInnerBulkAtom = true
      for neighborID in list {
        if !bulkAtomIDSet.contains(neighborID) {
          isInnerBulkAtom = false
        }
      }
      if isInnerBulkAtom {
        output.append(UInt32(atomID))
      }
    }
    return output
  }
  
  // Minimize a silicon surface.
  mutating func minimize() {
    guard topology.atoms.allSatisfy({ $0.atomicNumber != 79 }) else {
      fatalError("Incorrect lattice.")
    }
    
    // Allow four atomic layers to relax.
    var bulkAtomIDs = Self.extractBulkAtomIDs(topology: topology)
    for _ in 0..<3 {
      bulkAtomIDs = Self.createEnclosedSet(
        topology: topology, bulkAtomIDs: bulkAtomIDs)
    }
    
    // Set up an MM4 energy minimization.
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    for atomID in bulkAtomIDs {
      parameters.atoms.masses[Int(atomID)] = .zero
    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = parameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = topology.atoms.map(\.position)
    
    // Run the minimization and overwrite the atom coordinates.
    forceField.minimize(tolerance: 0.1)
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      let position = forceField.positions[atomID]
      atom.position = position
      topology.atoms[atomID] = atom
    }
  }
}

// MARK: - Presentation

extension SurfaceModel {
  // Depassivate the upper atomic layer of a silicon surface.
  //
  // This operation does not mutate or invalidate the surface atom IDs. It
  // relies on determinism in how the passivators were originally compiled.
  mutating func depassivate() {
    guard topology.atoms.allSatisfy({ $0.atomicNumber != 79 }) else {
      fatalError("Incorrect lattice.")
    }
    
    let surfaceAtomSet = Set(surfaceAtomIDs)
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    var removedAtoms: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      guard atom.atomicNumber == 1 else {
        continue
      }
      
      let atomsMap = atomsToAtomsMap[atomID]
      let siliconID = atomsMap.first!
      if surfaceAtomSet.contains(siliconID) {
        removedAtoms.append(UInt32(atomID))
      }
    }
    topology.remove(atoms: removedAtoms)
  }
  
  // A new set of axes, where the surface normal points toward +Y.
  static func basis(type: SurfaceModelType) -> (
    x: SIMD3<Float>,
    y: SIMD3<Float>,
    z: SIMD3<Float>
  ) {
    switch type {
    case .silicon100:
      return (
        SIMD3(1.00, 0.00, 0.00),
        SIMD3(0.00, 1.00, 0.00),
        SIMD3(0.00, 0.00, 1.00))
    case .silicon110:
      return (
        SIMD3(0.00, 0.00, -1.00),
        SIMD3(1.00, 1.00, 0.00) / Float(2).squareRoot(),
        SIMD3(1.00, -1.00, 0.00) / Float(2).squareRoot())
    case .silicon111, .gold111:
      return (
        SIMD3(-1.00, 0.00, 1.00) / Float(2).squareRoot(),
        SIMD3(1.00, 1.00, 1.00) / Float(3).squareRoot(),
        SIMD3(-1.00, 2.00, -1.00) / Float(6).squareRoot())
    case .silicon311:
      return (
        SIMD3(0.00, -1.00, 1.00) / Float(2).squareRoot(),
        SIMD3(3.00, 1.00, 1.00) / Float(11).squareRoot(),
        SIMD3(2.00, -3.00, -3.00) / Float(22).squareRoot())
    }
  }
  
  // Rotate the atoms, so the specified vectors become the cardinal axes.
  mutating func rotate(basis: (
    x: SIMD3<Float>,
    y: SIMD3<Float>,
    z: SIMD3<Float>
  )) {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(
        (position * basis.x).sum(),
        (position * basis.y).sum(),
        (position * basis.z).sum())
      
      atom.position = position
      topology.atoms[atomID] = atom
    }
  }
  
  // Analytically compute where the center of the lattice is.
  static func center(type: SurfaceModelType) -> SIMD3<Float> {
    switch type {
    case .silicon100:
      let latticeConstant = Constant(.square) { .elemental(.silicon) }
      return SIMD3(
        0.5 * (10 * latticeConstant),
        0.5 * (10 * latticeConstant),
        0.5 * (10 * latticeConstant))
    case .silicon110:
      let latticeConstant = Constant(.square) { .elemental(.silicon) }
      return SIMD3(
        -0.5 * (10 * latticeConstant),
         0.5 * (10 * latticeConstant) * Float(2).squareRoot(),
         0)
    case .silicon111:
      let latticeConstant = Constant(.square) { .elemental(.silicon) }
      return SIMD3(
        0,
        0.5 * (10 * latticeConstant) * Float(3).squareRoot(),
        0)
    case .silicon311:
      let latticeConstant = Constant(.square) { .elemental(.silicon) }
      return SIMD3(
        0,
        0.5 * (50 * latticeConstant) / Float(11).squareRoot(),
        -0.5 * (44 * latticeConstant) / Float(22).squareRoot())
    case .gold111:
      let latticeConstant = Constant(.square) { .elemental(.gold) }
      return SIMD3(
        0,
        0.5 * (10 * latticeConstant) * Float(3).squareRoot(),
        0)
    }
  }
  
  // Translate the atoms, to the specified center becomes the world origin.
  mutating func translate(center: SIMD3<Float>) {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position -= center
      topology.atoms[atomID] = atom
    }
  }
}
