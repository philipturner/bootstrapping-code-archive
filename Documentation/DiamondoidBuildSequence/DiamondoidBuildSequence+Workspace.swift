//
//  DiamondoidBuildSequence+Workspace.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/18/24.
//

import Foundation

// Workspace for analysis of the diamondoid build sequence.
#if false
func createGeometry() -> [Entity] {
//  var atoms = Reaction.rawProduct43a
//  guard atoms.count == Reaction.minimizedProduct43a.count else {
//    fatalError("Raw product's count did not match minimized product's count.")
//  }
  let tooltip = CurrentTooltip()
  let atoms = tooltip.reactiveSite + tooltip.nearFramework + tooltip.createOuterAnchorBoundaryAtoms()
  
  do {
    let orbitalCount = atoms.reduce(into: 0) { count, atom in
      switch atom.atomicNumber {
      case 1:
        count += 1
      case 6:
        count += 4
      case 14:
        count += 9
      case 32:
        count += 9
      default:
        fatalError("Unrecognized element.")
      }
    }
    print("orbitals:", orbitalCount)
  }
//  for atomID in atoms.indices {
//    var atom = atoms[atomID]
//    var position = atom.position
//
//    let angle = 90 * Float.pi / 180
//    let rotation = Quaternion<Float>(angle: angle, axis: [1, 0, 0])
//    position = rotation.act(on: position)
//    position += SIMD3(0.00, -0.00, -1.00)
//
//    atom.position = position
//    atoms[atomID] = atom
//  }
  
  //  var vector = SIMD3<Float>(0, 1, 0)
  //  let rotation1 = Quaternion<Float>(angle: -40 * .pi / 180, axis: [1, 0, 0])
  //  let rotation2 = Quaternion<Float>(angle: -100 * .pi / 180, axis: [0, 1, 0])
  //  vector = rotation1.act(on: vector)
  //  vector = rotation2.act(on: vector)
  //  print(vector)
  //  print(Float.acos(vector.y) * 180 / .pi)
  
  return atoms
}

func createGeometry2() -> [[Entity]] {
  var buildPlate = BuildPlate(type: .c33)
  
  #if true
  buildPlate.import(
    atoms: Reaction.minimizedProduct43a, atomCounts: [3, 42])
  
  if false {
    var anchorIDs: [UInt32] = [0, 1, 2]
    for atomID in buildPlate.graphene.indices {
      let atom = buildPlate.graphene[atomID]
      if atom.position.z > 0.17 {
        anchorIDs.append(3 + UInt32(atomID))
      } else if atom.atomicNumber == 1, atom.position.x.magnitude > 0.5 {
        anchorIDs.append(3 + UInt32(atomID))
      }
    }
    
    var atoms = buildPlate.anchors + buildPlate.graphene + buildPlate.product
    
    // Visualize the anchors before minimizing.
    for anchorID in anchorIDs {
      atoms[Int(anchorID)].atomicNumber = 7
    }
    return [atoms]
    
    atoms = minimize(atoms: atoms, anchorIDs: anchorIDs)
    buildPlate.import(atoms: atoms)
    for anchor in buildPlate.anchors {
      guard anchor.position.y.magnitude < 0.001 else {
        fatalError("Did not secure anchor.")
      }
    }

    print()
    let encoded = try! AtomCoder.encode(atoms, encoding: .hdl)
    print(encoded)
    print()
  }
  return [buildPlate.anchors + buildPlate.graphene + buildPlate.product]
  #endif
  
  do {
    // Minimize the build plate.
    var atoms = buildPlate.anchors + buildPlate.graphene + buildPlate.product
    atoms = minimize(atoms: atoms)
    buildPlate.import(atoms: atoms)
    buildPlate.translate(offset: -buildPlate.centerOfMass)
  }
  
  // Use a clean build plate as a metallic surface.
  var metallicSurface = buildPlate
  metallicSurface.translate(offset: [0, -0.335, 0])
  
  // Inject any product structures here.
  buildPlate.import(
    atoms: Reaction.minimizedProduct43a, atomCounts: [3, 42])
  
  // Import a minimized structure for the tooltip.
  var tooltip = CurrentTooltip()
  tooltip.import(atoms: CurrentTooltip.hydrogenTipMinimizedAtoms)
  
  // Rotate the tooltip.
  var approachDirection: SIMD3<Float>
  do {
    let dimerAveragePosition1 = tooltip.dimerCenterOfMass
    
    // DO NOT TILT THE TOOLTIP FROM POINTING STRAIGHT DOWN
    tooltip.rotate(angle: 0 * .pi / 180, axis: [0, 1, 0])

    let dimerAveragePosition2 = tooltip.dimerCenterOfMass
    tooltip.translate(offset: dimerAveragePosition1 - dimerAveragePosition2)
    
    let germaniumAveragePosition = tooltip.germaniumCenterOfMass
    approachDirection = dimerAveragePosition1 - germaniumAveragePosition
    approachDirection /= (
      approachDirection * approachDirection).sum().squareRoot()
  }
  
  // Translate the tooltip.
  let nearOffset = SIMD3<Float>(-0.55, 0.60, -0.70)
  let farOffset = nearOffset - 0.4 * approachDirection
  
  // Preview the reaction trajectory.
  tooltip.translate(offset: nearOffset)
  return [
    buildPlate.anchors +
    buildPlate.graphene +
    buildPlate.product +
    metallicSurface.anchors +
    metallicSurface.graphene +
    metallicSurface.product +
    tooltip.dimer +
    tooltip.reactiveSite +
    tooltip.nearFramework
  ]
  
  // Fill the reaction descriptor.
  var reactionDesc = ReactionDescriptor()
  reactionDesc.buildPlate = buildPlate
  reactionDesc.metallicSurface = metallicSurface
  reactionDesc.tooltip = tooltip
  reactionDesc.frameBudget = 4 * 60
  reactionDesc.nearOffset = nearOffset
  reactionDesc.farOffset = farOffset
  
  var reaction = Reaction(descriptor: reactionDesc)
  var output: [[Entity]] = []
  output.append(createFrame(reaction: reaction))
  
  // Run molecular dynamics.
  for _ in 0..<reactionDesc.frameBudget! {
    reaction.step()
    output.append(createFrame(reaction: reaction))
  }
  
  // Serialize the product structure.
  do {
    let buildPlate = reaction.createBuildPlate()
    let tooltip = reaction.createTooltip()
    
    var product: [Entity] = []
    product += buildPlate.anchors
    product += buildPlate.graphene
    product += buildPlate.product
    product += tooltip.dimer
    print()
    let encoded = try! AtomCoder.encode(product, encoding: .hdl)
    print(encoded)
    print()
  }
  
  return output
}

func createFrame(reaction: Reaction) -> [Entity] {
  var output: [Entity] = []
  let buildPlate = reaction.createBuildPlate()
  let metallicSurface = reaction.metallicSurface
  let tooltip = reaction.createTooltip()
  output += buildPlate.anchors
  output += buildPlate.graphene
  output += buildPlate.product
  output += metallicSurface.anchors
  output += metallicSurface.graphene
  output += metallicSurface.product
  output += tooltip.dimer
  output += tooltip.reactiveSite
  output += tooltip.nearFramework
  return output
}
#endif
