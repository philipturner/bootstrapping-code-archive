import Foundation
import MolecularRenderer
import HDL
import MM4
import Numerics
import QuartzCore
import xTB

// Next animation: "Bootstrapping procedure: atomically precise AFM tip builds
// process-unlimited amount of identical copies."
//
// This is worthy of getting the Jeremy Blake soundtrack!!! It also seems
// doable by the end of August.
//
// - Specify a build sequence for a useful part.
//   - Design a variation where all reactions are carried out with a copy of
//     the same tooltip.
//   - Analyze steric congestion and accomodate for direction-dependent
//     behavior in primitives.
// - Make code that can lay out all of the tripods, and auto-generate the order
//   in which they are traveled to.
//   - Also, able to animate the chemical processes that decorate the surface.
//   - Cl2, atomic hydrogen, vapor deposition of tripods
// - Make code that can animate the 2nd generation tooltip being built.
// - Make code that can animate the 2nd generation tooltip being used.
//   - Assembly code that includes both charging/discharging steps, and the
//     operations at the workpiece site.
//   - Segmentation of a tripod monolayer into sparse and dense regions.
// - Invoke one build sequence multiple times, on structurally similar build
//   sites (32 copies of the same tooltip).
//
// ========================================================================== //
// Bootstrapping Procedure
// ========================================================================== //
//
// # Part 1: Surface Preparation
//
// # Part 2: Tooltip Construction
//
// The first number in brackets is the number of elementary AFM motions. The
// second number in brackets indicates the amount of tripods consumed. If a
// tripod is recycled as part of the reaction, it is consumed once, not twice.
// Furthermore, if the tripod returns to its initial state, it is not consumed.
// Tripods that never change state (rearrangement tools) are never consumed.
//
// ## Commence First Layer
//
// [??/??] Placing Initial Monomers
// repeat 3 times
//   HAbst (Ge-C2)
//   CH2 (NC3Ge)
//   HDon (NC3Si) to CH2
// HAbst (Ge-C2)
// SiH3 (NS3Sn)
//
// [??/??] Forming First Cage
// repeat 3 times
//   HAbst (Ge-C2) from carbon
//   HAbst (Ge-C2) from silicon
//   Rearr. (Ge-CH3)
// HDon (NC3Ge) to C3Si
// leave Si3Si unpassivated --> revisit at [COMMENT 1] (TODO: find COMMENT 1)
//
// [??/??] Forming Second Cage
// HAbst (Ge-C2)
// CH2 (NC3Ge)
// HDon (NC3Si) # reuse in 1
// HAbst (Ge-C2)
// HDon (NC3Si) # reuse in 2
//
// HAbst (Ge-C2)
// SiH3 (NS3Ge)
// HAbst (Ge-C2) on carbon
// HAbst (NC3Si) on silicon # 1 restored
//
// HAbst (Ge-C2)
// SiH3 (NS3Ge)
// HAbst (Ge-C2) on carbon
// HAbst (NC3Si) on silicon # 2 restored
//
// [??/??] Forming Third Cage
// exact same procedure as for second cage
//
// [??/??] Forming Fourth Cage
// exact same procedure as for second cage
//
// ## Finalize First Layer
//
// ## Commence Second Layer
//
// [11/11] Placing Initial Monomers
// repeat 3 times
//   HAbst (Ge-C2)
//   CH2 (NC3Ge)
//   HDon (NC3Si) to CH2
// HAbst (Ge-C2)
// SiH3 (NS3Ge)
//
// [11/8] Forming C3Si Apex
// repeat 3 times
//   HAbst (Ge-C2) from carbon
//   HAbst (Ge-C2) from silicon
//   Rearr. (Ge-CH3)
// HDon (NC3Ge) to C3Si
// HDon (NC3Ge) to HC2Si
//
// [12/10] Forming C3Ge Apex
// repeat 2 times
//   HAbst (Ge-C2)
//   CH2 (NC3Ge)
//   HDon (NC3Ge) to CH2 # reuse in 1
// HAbst (Ge-C2) on carbon
// GeH3 (NS3Ge)
// repeat 2 times
//   HAbst (Ge-C2) on carbon
//   HAbst (NC3Ge) on germanium # 1 restored
//
// [13/11] Forming CSi2Si Apex
// repeat 2 times
//   HAbst (Ge-C2)
//   SiH3 (NS3Ge) # reuse in 1
// HAbst (Ge-C2) on carbon
// SiH3 (NS3Ge)
// HAbst (Ge-C2) on silicon
// repeat 2 times
//   HAbst (NS3Ge) on silicon monoradical # 1 permanently spent
//   HAbst (Ge-C2)
//   Rearr. (Ge-CH3)
// leave CSi2Si apex unpassivated
//
// ## Finalize Second Layer
//
// # Part 3: Tooltip Replication
//
// Inverted mode sequence:     ??? operations, ??? tripods, ~??? days
// Conventional mode sequence: ??? operations, ??? tripods, ~??? days
//
// Review the build sequence above.
// - Count the number of operations in the existing sequence specification.
// - Map the atrane tripod tools to the corresponding apices.
// - Analyze steric congestion. Adjust the sequence if necessary.
//
// # Part 4: Batch of 32 Tooltips
//
// Manufacture a batch of 32 tooltips.
// - Count the number of tripods needed.
// - Can one lay out the entire feedstock depot in one static scene?
// - Perhaps use a split view of two subregions.

#if false
// Workspace for designing the tripod supply.
func createGeometry() -> [Entity] {
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * h + 10 * h2k + 4 * l }
    Material { .elemental(.silicon) }
  }
  
  // Generate random spots for all of the needed tripods. Start by passivating
  // with H and Cl, then scanning over the surface for viable zones.
  //
  // Another task that can be accomplished in parallel: setting up
  // trifluorobenzene legs and getting them to use ONIOM.
  //
  // TODO: Wrap the end result in some nice data structures.
  var atoms = lattice.atoms
  for atomID in atoms.indices {
    var atom = atoms[atomID]
    atom.position = SIMD3(atom.position.x, atom.position.z, atom.position.y)
    atoms[atomID] = atom
  }
  
  return atoms
}
#endif

#if false
// Workspace for experimenting with tripod legs.
func createGeometry() -> [Entity] {
  // MARK: - Leg
  
  // Compile the starting lattice.
  let carbonLattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 3 * h + 3 * h2k + 1 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 0.25 * l }
        Plane { l }
      }
      Convex {
        Origin { 1 * h2k }
        Plane { k - h }
      }
      Convex {
        Origin { 3 * h }
        Plane { k + 2 * h }
      }
      Convex {
        Origin { 0.5 * h2k }
        Plane { -h2k }
      }
      
      Replace { .empty }
    }
  }
  
  // Rescale from lonsdaleite to graphene.
  var grapheneHexagonScale: Float
  do {
    let grapheneConstant: Float = 2.45 / 10
    let lonsdaleiteConstant = Constant(.hexagon) { .elemental(.carbon) }
    grapheneHexagonScale = 1 / lonsdaleiteConstant
    grapheneHexagonScale *= grapheneConstant
  }

  var carbons: [Entity] = carbonLattice.atoms
  for atomID in carbons.indices {
    carbons[atomID].position.z = 0
    carbons[atomID].position.x *= grapheneHexagonScale
    carbons[atomID].position.y *= grapheneHexagonScale
  }
  
  var topology = Topology()
  topology.insert(atoms: carbons)
  
  // Add the bulk atom bonds.
  do {
    let matches = topology.match(topology.atoms)
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
  }
  
  // Transmute the corners to fluorine.
  do {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    for atomID in topology.atoms.indices {
      let atomsMap = atomsToAtomsMap[atomID]
      if atomsMap.count == 1 {
        topology.atoms[atomID].atomicNumber = 9
      }
    }
  }
  
  // Add the remaining atoms.
  topology.atoms += [
    Entity(position: SIMD3(0.25, 0.15, 0.00), type: .atom(.oxygen)),
    Entity(position: SIMD3(0.33, 0.08, 0.00), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.03, 0.57, 0.00), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.45, 0.57, 0.00), type: .atom(.hydrogen)),
  ]
  
  // TODO: Minimize the atoms, then embed the raw minimized positions into the
  // source code.
  
  // MARK: - Cage Tooltip
  
  // Instantiate the cage tooltip.
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .hydrogen
  cageTooltipDesc.frameworkType = .adamantane(.carbon)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  try! cageTooltip.loadCachedValue()
  
  // Measure the angle of the framework-leg bond. Use this to undo any
  // rotation of the tripod from the pre-compiled direction.
  do {
    // Pick two atoms to analyze.
    let boundaryBond = cageTooltip.frameworkLegsBoundary[0]
    let frameworkAtom = cageTooltip.framework[Int(boundaryBond[0])]
    let legAtom = cageTooltip.legs[Int(boundaryBond[1])]
    
    // Find the direction vector.
    var direction = legAtom.position - frameworkAtom.position
    direction.y = .zero
    direction /= (direction * direction).sum().squareRoot()
    
    // Extract the angle from this vector.
    let angle = Float.atan2(y: direction.x, x: direction.z)
    
    // Create a quaternion with the negative of the angle.
    let rotation = Quaternion<Float>(
      angle: -angle, axis: SIMD3(0.00, 1.00, 0.00))
    
    // Rotate every atom in the tripod.
    func rotate(atoms: inout [Entity]) {
      for atomID in atoms.indices {
        var atom = atoms[atomID]
        atom.position = rotation.act(on: atom.position)
        atoms[atomID] = atom
      }
    }
    rotate(atoms: &cageTooltip.feedstock)
    rotate(atoms: &cageTooltip.apex)
    rotate(atoms: &cageTooltip.framework)
    rotate(atoms: &cageTooltip.legs)
  }
  
  // Combine the legs and tripod into one array.
  var output: [Entity] = []
  output += cageTooltip.feedstock
  output += cageTooltip.apex
  output += cageTooltip.framework
  
  // TODO: Minimize the leg every time before adding here. Then, remove the
  // last hydrogen in the leg.
  for legID in 0..<1 {
    let targetBond = cageTooltip.frameworkLegsBoundary[legID]
    let targetAtom = cageTooltip.framework[Int(targetBond[0])]
    
    // TODO: Rotate the leg around the pivot point.
    
    // Rotate the leg around the Y axis.
    let angleDegrees = Float(legID) * 120
    let rotationY = Quaternion<Float>(
      angle: angleDegrees, axis: SIMD3(0.00, 1.00, 0.00))
    
    var atoms = topology.atoms
    // ...
  }
  
  return output
}
#endif
