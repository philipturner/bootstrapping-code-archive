//
//  Silicon111_7x7.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/9/24.
//

// Decoding the atom coordinates of the Si(111)-(7x7) reconstruction.

func createGeometry() -> [Entity] {
  // Origin: position of atom 103 in bulk crystal
  // z-axis: points into the crystal
  
  let layer1 = """
  1  5.76  3.33  -4.21
  2  13.44  3.33  -4.17
  3  5.76  -3.33  -4.29
  4  13.44  -3.33  -4.25
  
  """
  
  let layer2 = """
  13  4.01  2.32  -2.94
  14  5.76  3.33  -1.68
  15  9.60  5.54  -3.11
  16  11.55  6.67  -2.41
  17  13.44  5.32  -2.98
  18  13.44  3.33  -1.68
  19  4.01  -2.32  -2.99
  20  5.76  -3.33  -1.73
  21  9.60  -5.54  -3.16
  22  11.55  -6.67  -2.46
  23  13.44  -5.32  -3.03
  24  13.44  -3.33  -1.73
  25  12.21  0.00  -2.24
  26  6.98  0.00  -2.24
  27  4.53  0.00  -2.24
  28  7.49  2.33  -2.98
  29  11.71  2.33  -2.98
  30  9.60  3.29  -2.41
  31  7.49  -2.33  -3.03
  32  11.71  -2.33  -3.03
  33  9.60  -3.29  -2.46
  
  """
  
  let layer3 = """
  103  0.00  0.00  -0.05
  104  13.44  7.76  0.73
  105  5.76  3.33  0.45
  106  13.44  3.33  0.45
  107  11.52  6.65  -0.07
  108  5.76  -3.33  0.45
  109  13.44  -3.33  0.45
  110  11.52  -6.65  -0.07
  111  1.92  1.11  0.74
  112  13.44  1.11  0.87
  113  7.68  4.43  0.80
  114  3.84  -2.22  0.85
  115  9.60  -5.54  0.73
  116  13.44  -5.54  0.80
  117  3.84  0.00  0.00
  118  7.68  0.00  0.00
  119  11.52  0.00  0.00
  120  9.60  3.33  -0.07
  121  9.60  -3.33  -0.07
  122  5.76  1.11  0.87
  123  9.60  1.11  0.72
  124  11.52  4.43  0.80
  125  7.68  -2.22  0.83
  126  11.52  -2.22  0.83
  
  """
  
  func createAtoms(_ rawString: String) -> [Entity] {
    var output: [Entity] = []
    
    // Iterate over the lines.
    let lines = rawString.split(separator: "\n").map(String.init)
    for lineID in lines.indices {
      let line = lines[lineID]
      let words = line.split(separator: " ").map(String.init)
      guard words.count == 4 else {
        fatalError("Unexpected word count.")
      }
      
      // Dissect the line.
      let atomID = Int(words[0])!
      let coordinateX = Float(words[1])!
      let coordinateY = Float(words[2])!
      let coordinateZ = Float(words[3])!
      _ = atomID
      
      // Convert from angstroms to nanometers.
      var position = SIMD3(coordinateX, coordinateY, coordinateZ)
      position /= 10
      
      // Map between coordinate spaces.
      position.z = -position.z
      position = SIMD3(position.x, position.z, -position.y)
      
      // Create a silicon atom.
      let silicon = Entity(position: position, type: .atom(.germanium))
      output.append(silicon)
    }
    
    return output
  }
  let adatoms = createAtoms(layer1)
  let upperLayer = createAtoms(layer2)
  let bulkLayer = createAtoms(layer3)
  
  // Create an index for the unique atoms in the symmetry group.
  var index: [UInt32: Entity] = [:]
  for atomID in adatoms.indices {
    let atom = adatoms[atomID]
    let key = UInt32(atomID) + 1
    index[key] = atom
  }
  for atomID in upperLayer.indices {
    let atom = upperLayer[atomID]
    let key = UInt32(atomID) + 13
    index[key] = atom
  }
  for atomID in bulkLayer.indices {
    let atom = bulkLayer[atomID]
    let key = UInt32(atomID) + 103
    index[key] = atom
  }
  
  // Construct the rhombic unit cell. This one is easier to tile in 3D space.
  // - After coding it, ensure no atoms overlap the neighboring cells.
  var rhombicCell: [Entity] = []
  do {
    let atomIDs: [UInt32] = [
      1, 2,
      13, 14, 15, 16,
      17, 18, 25, 26,
      27, 28, 29, 30,
      103, 104, 105, 106,
      107, 111, 112, 113,
      117, 118, 119, 120,
      122, 123, 124,
    ]
    for atomID in atomIDs {
      let atom = index[atomID]!
      rhombicCell.append(atom)
    }
  }
  do {
    let atomIDs: [UInt32] = [
      2,
      17, 18, 25, 26,
      27, 28, 29, 30,
      106, 112, 117, 118,
      119, 120, 122, 123,
      124,
    ]
    let rotation = Quaternion<Float>(
      angle: 60 * .pi / 180, axis: SIMD3(0.00, 1.00, 0.00))
    
    for atomID in atomIDs {
      var atom = index[atomID]!
      atom.position.z = -atom.position.z
      atom.position = rotation.act(on: atom.position)
      rhombicCell.append(atom)
    }
    
    // TODO: Next, reflect the white triangle from (d) in the paper (huang1988)
    // across an imaginary line.
  }
  
  // Align the reconstruction pattern with the upper atomic layers of the bulk.
  // - Eventually, we will include the second layer in the "surface atoms" for
  //   the Si(111) model. Then, delete them and replace with Si(111)-(7x7).
  var surfaceModel = SurfaceModel(type: .silicon111)
  surfaceModel.topology.remove(atoms: surfaceModel.surfaceAtomIDs)
  
  func alignAtoms(_ atoms: inout [Entity]) {
    for atomID in atoms.indices {
      var atom = atoms[atomID]
      let hexagonConstant = Constant(.hexagon) { .elemental(.silicon) }
      let prismConstant = Constant(.prism) { .elemental(.silicon) }
      
      // Shift down in the XZ plane.
      var shiftZ = hexagonConstant
      shiftZ *= Float(3).squareRoot() / 2
      shiftZ *= 2.0 / 3
      atom.position += shiftZ * SIMD3(0, 0, 1)
      
      // Shift down along the Y normal.
      var shiftY = prismConstant
      shiftY *= 1.0 / 2
      atom.position += shiftY * SIMD3(0, -1, 0)
      
      atoms[atomID] = atom
    }
  }
  alignAtoms(&rhombicCell)

  return surfaceModel.topology.atoms + rhombicCell
}

