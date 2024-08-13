//
//  xTB_GenericPart.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/1/24.
//

import HDL
import MM4

#if false

protocol xTB_GenericPart: GenericPart {
  
}

extension xTB_GenericPart {
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    var emptyParamsDesc = MM4ParametersDescriptor()
    emptyParamsDesc.atomicNumbers = []
    emptyParamsDesc.bonds = []
    
    // Inject a custom parameterization into the MM4Parameters.
    var parameters = try! MM4Parameters(descriptor: emptyParamsDesc)
    parameters.atoms.count = topology.atoms.count
    parameters.atoms.indices = 0..<topology.atoms.count
    parameters.atoms.atomicNumbers = topology.atoms.map(\.atomicNumber)
    parameters.bonds.indices = topology.bonds
    
    var masses: [Float] = []
    for atomicNumber in parameters.atoms.atomicNumbers {
      switch atomicNumber {
      case 1:
        masses.append(4 * Float(MM4YgPerAmu))
      default:
        masses.append(12.011 * Float(MM4YgPerAmu))
      }
    }
    parameters.atoms.masses = masses
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
  
  static func createTopology(rigidBody: MM4RigidBody) -> Topology {
    var topology = Topology()
    let parameters = rigidBody.parameters
    
    var insertedAtoms: [Entity] = []
    for atomID in parameters.atoms.indices {
      let atomicNumber = parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let entity = Entity(storage: storage)
      insertedAtoms.append(entity)
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: parameters.bonds.indices)
    
    return topology
  }
  
  mutating func minimize(anchors: Set<UInt32>) {
    fatalError("Not implemented.")
  }
}

#endif
