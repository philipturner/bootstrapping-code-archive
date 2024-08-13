//
//  GenericPart.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/1/24.
//

import Foundation
import HDL
import MM4

protocol GenericPart {
  
}

// Key-value caching system.
// - Key: Creates a 512-bit hash from the atoms, converts to a base64 string,
//   uses that as the filename.
//   - The final 128 bits are reserved for hashing the bonds and anchors.
// - Value: Encodes the atoms and bonds within a factor of ~2x from the
//   information theoretic limit.

#if false
extension MM4GenericPart {
  func cache(directory: String) {
    // Extract the atoms and bonds.
    var rigidBodyAtoms: [Entity] = []
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
      rigidBodyAtoms.append(entity)
    }
    let rigidBodyBonds = rigidBody.parameters.bonds.indices
    
    // Compress the data.
    let valueAtoms = Serialization.serialize(atoms: rigidBodyAtoms)
    let valueBonds = Serialization.serialize(bonds: rigidBodyBonds)
    
    // Create the header.
    var header: SIMD4<UInt64> = .zero
    header[0] = UInt64(key.count)
    header[1] = UInt64(valueAtoms.count)
    header[2] = UInt64(valueBonds.count)
    let headerCasted = unsafeBitCast(header, to: SIMD32<UInt8>.self)
    
    // Combine the header and data into a single binary.
    var data = Data()
    for laneID in 0..<32 {
      let byte = headerCasted[laneID]
      data.append(byte)
    }
    data.append(key)
    data.append(valueAtoms)
    data.append(valueBonds)
    
    // Save the structure to the disk.
    let url = URL(fileURLWithPath: cachePath)
    try! data.write(to: url)
  }
  
  func load(directory: String) -> Topology? {
    // Load the structure from the disk.
    let url = URL(fileURLWithPath: cachePath)
    let data = try? Data(contentsOf: url)
    guard let data else {
      print("[\(Self.self)] Cache miss: file not found.")
      return nil
    }
    
    // Decode the header.
    guard data.count >= 32 else {
      fatalError("Data had invalid header.")
    }
    var headerCasted: SIMD32<UInt8> = .zero
    for laneID in 0..<32 {
      let byte = data[laneID]
      headerCasted[laneID] = byte
    }
    let header = unsafeBitCast(headerCasted, to: SIMD4<UInt64>.self)
    
    // Check that the file has the correct size.
    let keySize = header[0]
    let valueAtomsSize = header[1]
    let valueBondsSize = header[2]
    let expectedSize = 32 + keySize + valueAtomsSize + valueBondsSize
    guard expectedSize == data.count else {
      fatalError("File had the wrong size.")
    }
    
    // Divide the file into segments.
    var cursor: UInt64 = 32
    let keyRange = cursor..<cursor + keySize
    cursor += keySize
    let valueAtomsRange = cursor..<cursor + valueAtomsSize
    cursor += valueAtomsSize
    let valueBondsRange = cursor..<cursor + valueBondsSize
    cursor += valueBondsSize
    guard cursor == data.count else {
      fatalError("Cursor was invalid.")
    }
    
    // Extract the segments of the file.
    let cacheKey = Data(data[keyRange])
    guard key == cacheKey else {
      print("[\(Self.self)] Cache miss: key mismatch.")
      return nil
    }
    let valueAtoms = Data(data[valueAtomsRange])
    let valueBonds = Data(data[valueBondsRange])
    let atoms = Serialization.deserialize(atoms: valueAtoms)
    let bonds = Serialization.deserialize(bonds: valueBonds)
    
    // Create a topology.
    var topology = Topology()
    topology.insert(atoms: atoms)
    topology.insert(bonds: bonds)
    return topology
  }
}
#endif
