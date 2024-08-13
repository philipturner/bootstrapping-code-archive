import Foundation
import MolecularRenderer
import HDL
import MM4
import Numerics
import QuartzCore
import xTB

// Workspace for building a stiffer tooltip model.
//
// Looking for the model S lattice, but inverted. Then, I can place an
// extended version of C3Sn onto it. This will be costly to simulate.
func createSecondGenTooltip() -> Silicon111Tooltip {
  var siliconTooltip = Silicon111Tooltip(type: .modelInvertedS)
  
  // Add the carbon layer.
  for atomID in siliconTooltip.surface.indices {
    var atom = siliconTooltip.surface[atomID]
    guard atom.atomicNumber == 1 else {
      continue
    }
    
    var delta = atom.position
    delta.y = 0
    let distance = (delta * delta).sum().squareRoot()
    
    if distance > 0.35 {
      // Outer three atoms.
      atom.atomicNumber = 14
    } else {
      // Inner three atoms.
      atom.atomicNumber = 6
    }
    atom.position.y += -0.050
    siliconTooltip.surface[atomID] = atom
  }
  
  // Add the germanium layer.
  for atomID in siliconTooltip.surface.indices {
    var atom = siliconTooltip.surface[atomID]
    guard atom.position.y > 0.010 else {
      continue
    }
    
    if atom.position.x.magnitude < 0.010,
       atom.position.z.magnitude < 0.010 {
      // Transmute to tin.
      atom.atomicNumber = 14
      atom.position.y = -0.33
      siliconTooltip.surface.append(atom)
    } else {
      // Transmute to germanium.
      atom.atomicNumber = 14
      atom.position.y += -0.350
      siliconTooltip.surface.append(atom)
    }
  }
  
  // Add the hydrogens.
  for sideID in 0..<3 {
    let angle = Float(sideID) * 120 * .pi / 180
    let rotation = Quaternion(angle: angle, axis: SIMD3(0.00, 1.00, 0.00))
    
    let rawHydrogens: [Entity] = [
      Entity(position: SIMD3(0.47, -0.27, 0.27), type: .atom(.hydrogen)),
      Entity(position: SIMD3(0.19, -0.42, 0.35), type: .atom(.hydrogen)),
      Entity(position: SIMD3(0.19, -0.23, 0.47), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.19, -0.42, 0.35), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.19, -0.23, 0.47), type: .atom(.hydrogen)),
    ]
    for rawHydrogen in rawHydrogens {
      var hydrogen = rawHydrogen
      hydrogen.position = rotation.act(on: hydrogen.position)
      siliconTooltip.surface.append(hydrogen)
    }
  }
  
  // Add the apical hydrogen (for stability).
  siliconTooltip.surface += [
    Entity(position: SIMD3(0.00, -0.48, 0.00), type: .atom(.hydrogen)),
  ]
  
  xTB_Environment.show()
  siliconTooltip.minimizeSurface()
  xTB_Environment.show()
  
  siliconTooltip.surface[25].atomicNumber = 32
  xTB_Environment.show()
  siliconTooltip.minimizeSurface()
  xTB_Environment.show()
  
  siliconTooltip.surface[25].atomicNumber = 50
  xTB_Environment.show()
  siliconTooltip.minimizeSurface()
  xTB_Environment.show()
  
  siliconTooltip.surface.removeLast()
  xTB_Environment.show()
  siliconTooltip.minimizeSurface()
  xTB_Environment.show()
  
  return siliconTooltip
}

#if false
// Workspace for examining transition states of the C-Sn bond insertion.
//
// Formation of GeH: | Reaction 3m (2024-07-20 03_17_37 +0000).data
// Rearrangement     | Reaction 4m (2024-07-20 21_30_17 +0000).data
func createGeometry() -> [Entity] {
  let cacheFolder =
  "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
  let folder = URL(filePath: cacheFolder)
  let fileName = "Reaction 4m (2024-07-20 21_30_17 +0000).data"
  let file = folder.appending(
    component: fileName, directoryHint: .notDirectory)
  
  let data = try! Data(contentsOf: file)
  let frames = Serialization.decode(frames: data)
  
  var siliconTooltip = Silicon111Tooltip(type: .modelA)
  siliconTooltip.surface = frames.last!
  siliconTooltip.minimizeSurface()
  
  // 13 50 SIMD3<Float>(-0.001953125, -0.31835938, 0.0)
  // 20 1 SIMD3<Float>(0.08691406, -0.6220703, -0.08496094)
  // 21 32 SIMD3<Float>(0.044921875, -0.58203125, 0.06640625)
//  siliconTooltip.surface[13].atomicNumber = 14
//  siliconTooltip.surface[20].position.x = 0
//  siliconTooltip.surface[21].position.x = 0
//  siliconTooltip.minimizeSurface()
  
  siliconTooltip.surface[13].atomicNumber = 14
  siliconTooltip.surface[21].atomicNumber = 14
  siliconTooltip.minimizeSurface()
  
  var initialAtoms: [Entity] = []
  initialAtoms += siliconTooltip.surface
  initialAtoms += Silicon111Tooltip.createLinkAtoms(
    inner: siliconTooltip.surface,
    outer: siliconTooltip.anchors,
    boundary: siliconTooltip.boundary)
  
  var calculatorDesc = xTB_CalculatorDescriptor()
  calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
  calculatorDesc.hamiltonian = .tightBinding
  calculatorDesc.positions = initialAtoms.map(\.position)
  let calculator = xTB_Calculator(descriptor: calculatorDesc)
  xTB_Environment.show()
  
  print(Format.energy(calculator.energy))
  xTB_Environment.show()
  
  return initialAtoms
}
#endif


#if true
// Workspace for building onto the silicon tooltip.
//
// ## Pathway 1
//
// HAbst | z=0.65 | Reaction 1l (2024-07-19 03_15_52 +0000).data
// GeH:  | z=0.50 | Reaction 2l (2024-07-19 03_38_02 +0000).data [adamsilane]
//                  Reaction 2l (2024-07-19 03_48_24 +0000).data [atrane]
// HAbst | z=0.65 | Reaction 3l (2024-07-19 12_13_23 +0000).data
//
// ## Pathway 2
//
// HAbst | z=0.65 | Reaction 1l (2024-07-19 12_23_13 +0000).data
// CH2   | z=0.50 | Reaction 2l (2024-07-19 12_26_19 +0000).data
// HDon  | z=0.55 | Reaction 3l (2024-07-19 12_28_44 +0000).data
// HAbst | z=0.65 | Reaction 4l (2024-07-19 12_33_57 +0000).data
// GeH:  | z=0.50 | Reaction 5l (2024-07-19 12_39_16 +0000).data (0°)
//                  Reaction 5l (2024-07-19 12_41_51 +0000).data (90°)
//                  Reaction 5l (2024-07-19 12_44_10 +0000).data (180°)
// HAbst | z=0.70 | Reaction 6l (2024-07-19 12_57_44 +0000).data
// HDon  | z=0.60 | Reaction 7l (2024-07-19 13_07_32 +0000).data
// HAbst | z=0.65 | Reaction 8l (2024-07-19 17_27_14 +0000).data
// CH2   | z=0.50 | Reaction 9l (2024-07-19 17_39_33 +0000).data
//
// ## Pathway 3
//
// Starting with the model S surface, with two CH3 groups already built.
//
// HAbst | z=0.65 | Reaction 1l (2024-07-19 21_48_24 +0000).data
// GeH:  | z=0.50 | Reaction 2l (2024-07-19 22_07_18 +0000).data (0°)
//                  Reaction 2l (2024-07-19 22_11_37 +0000).data (90°)
//                  Reaction 2l (2024-07-19 22_15_44 +0000).data (180°)
//                  Reaction 2l (2024-07-19 22_20_05 +0000).data (270°)
//                  Reaction 2l (2024-07-19 22_01_18 +0000).data (315°)
//
// I cannot reliably abstract a hydrogen from the GeH: diradical. The H atom
// appears repelled by the C2* tool, and the C3Si* tool may have steric
// congestion issues.
//
// ## Manufacturing GeH:
//
// Starting with the model A surface, with a C3Sn tooltip already built.
//
// GeH3  | z=0.85         | Reaction 1m (2024-07-19 23_37_03 +0000).data
// HAbst | z=0.80, r=0.26 | Reaction 2m (2024-07-20 01_00_54 +0000).data
// HAbst | z=0.75, r=0.35 | Reaction 3m (2024-07-20 03_17_37 +0000).data
//               tilt=20° |
//
// Repeating the sequence above, but with a more expensive tooltip model.
//
// GeH3  | z=0.85         | Reaction 1m (2024-07-20 23_19_58 +0000).data
// HAbst | z=0.80, r=0.26 | Reaction 2m (2024-07-21 00_01_48 +0000).data
//
// Alternative ways to get triply passivated germanium onto the C3Sn tip:
// GeH2Br [NO ]
// GeH2Cl [NO ]
// GeH2F  [NO ]
// GeHF2  [NO ]
//
// Which germanium radicals transfer?
// GeH2* [NO ]
// GeH:  [NO ] - the GeH falls over and bonds to a sulfur
//
// I must search for ways to form the GeH: moiety on-site. Perhaps a hydrogen
// abstraction with acetylene, then another hydrogen abstraction with tin.
//
// The first hydrogen abstraction is reliable. It is done with a C3Si tip,
// at approximately the coordinates (r=0.255, z=0.80). It must be done through
// several repeated encounters. Only positions exactly next to the hydrogen
// will abstract it. Many other positions result in no reaction, because the
// vdW forces between the Si and Ge attract them. The specified toroidal
// operating range never results in damage (e.g. Ge detachment).
//
// For the second abstraction, I constrained the available tools to those that
// bind the GeHx group more weakly than C3Sn. (CF2)3Sn and (SiH2)3Sn abstracted
// GeH2* from the tooltip, so I cannot use those. Attempts to donate Br to the
// unpaired electron failed. Surprisingly, the modeled tooltip won in a fight
// against atrane(Sn). The tie was likely broken by van der Waals forces.
// Silicon has a higher Hamaker constant than carbon.
//
// It's okay to have a tripod that's knocked over. You can engineer binding
// sites for that cage with organic chemistry. Preferably, such tripods would
// be recycled multiple times. They are must simpler to manufacture with bulk
// chemistry than HAbst setups, so this primitive is reasonable to include.
//
// ## Hamaker Constants
//
// The conventional mode tool is assumed to be built out of GeC, while the
// tripods are bound to silicon.
//
// I could not find any literature values for the Hamaker constant of Si. I
// need to compare the constants for Si and GeC. The GeH2 group must
// theoretically stick to GeC over Si, in addition to working in simulation.
//
// C = 1.924 * epsilon * (r_vdw)^6
// C assigned to the value for (Ge -> X) + 2 * (H -> X)
//
// Atom | Epsilon        | vdW Radius |
// ---- | -------------- | ---------- |
//    H | 0.017 kcal/mol |    1.640 Å |
//    C | 0.037 kcal/mol |    1.960 Å |
//   Si | 0.140 kcal/mol |    2.290 Å |
//   Ge | 0.200 kcal/mol |    2.440 Å |
//
// Interaction | Epsilon        | vdW Radius | C Value |
// ----------- | -------------- | ---------- | ------- |
//     H ->  C | 0.024 kcal/mol |    3.440 Å |    76.5 |
//     H -> Si | 0.049 kcal/mol |    3.930 Å |   347.3 |
//     H -> Ge | 0.058 kcal/mol |    4.080 Å |   514.7 |
//    Ge ->  C | 0.086 kcal/mol |    4.400 Å |  1200.7 |
//    Ge -> Si | 0.167 kcal/mol |    4.730 Å |  3598.2 |
//    Ge -> Ge | 0.200 kcal/mol |    4.880 Å |  5197.0 |
//
// Atom | C Value for GeH2 Interaction |
// ---- | ---------------------------- |
//    C |                       1353.7 |
//   Si |                       4292.8 |
//   Ge |                       6226.4 |
//
// Material          | Atom Density | Average C Value | Relative Ham. Const. |
// ----------------- | ------------ | --------------- | -------------------- |
// diamond           | 176.3 / nm^3 |          1353.7 |               2.39e5 |
// silicon carbide   |  96.5 / nm^3 |          2823.3 |               2.72e5 |
// germanium carbide |  86.5 / nm^3 |          3790.1 |               3.28e5 |
// silicon           |  49.9 / nm^3 |          4292.8 |               2.14e5 |
// germanium         |  44.2 / nm^3 |          6226.4 |               2.75e5 |
//
// Germanium carbide has the highest Hamaker constant out of all the
// materials, and elemental silicon has the lowest one! This increases the
// confidence that the Ge dissociation misreaction will not be problematic.
//
// ## C-Sn Bond Insertion
//
// There is a troublesome misreaction where the GeH: diradical inserts itself
// into the C-Sn bond on the tooltip. I need to analyze why this happens, then
// consider the solutions:
// - Use a C-Ge or C-Si tooltip with a lower change of bond insertion.
// - Model a blunt tooltip with a full CGe lattice, sterically preventing
//   insertion.
// - Intentionally insert GeH: into a specific bond on the tooltip, then
//   exploit the structure to cause a deterministic deposition without hydrogen
//   stealing.
// - Use a Ge feedstock with CH3 passivation.
//
// (1) Straight up position: -1026.49 eV
// (2) Reaction 3 minimization: -1026.63 eV
// (3) Reaction 4 minimization: -1027.04 eV
//
// Tooltip | State (1)   | State (2)   | State (3)   | ΔE       |
// :------ | ----------: | ----------: | ----------: | -------: |
// C3Si    | -1016.70 eV | -1016.71 eV | -1016.65 eV | +0.05 eV |
// C3Ge    | -1022.58 eV | -1022.60 eV | -1022.74 eV | -0.16 eV |
// C3Sn    | -1026.49 eV | -1026.63 eV | -1027.04 eV | -0.55 eV |
//
// The same structures, but with a silicon diradical feedstock:
//
// Tooltip | State (1)   | State (2)   | State (3)   | ΔE       |
// :------ | ----------: | ----------: | ----------: | -------: |
// C3Si    | -1010.01 eV | unstable    | -1009.77 eV | +0.24 eV |
// C3Ge    | -1016.17 eV | unstable    | -1016.53 eV | -0.36 eV |
// C3Sn    | -1020.21 eV | unstable    | -1021.57 eV | -0.36 eV |
//
// ## New Course of Action
//
// I have had enough failures with attempting to add Ge directly to silicon.
// GeH3 crashes the simulator, GeH: likely cannot be synthesized, and GeH2
// doesn't stick. I need to search for a deterministic way to add Ge directly
// to a carbon atom.
//
// Starting with the model S surface, with two CH3 groups already built. All
// reactions use the C3Ge/C3Ge-C2 universal tooltip unless noted otherwise.
//
// > Reactions with a single star (*) need to profiled for hydrogen stealing.
//
// HAbst  | z=0.63, tilt=30° | Reaction 1l (2024-07-21 02_02_46 +0000).data
// HAbst  | z=0.65           | Reaction 2l (2024-07-21 02_08_03 +0000).data
// Branch Point
//
// SiH2\* | z=0.70           | Reaction 3l (2024-07-21 02_21_11 +0000).data
// HAbst  | z=0.80           | Reaction 4l (2024-07-21 02_27_53 +0000).data
// HAbst  | z=0.80           | Reaction 5l (2024-07-21 02_34_41 +0000).data
// HAbst  | z=0.63, tilt=30° | Reaction 6l (2024-07-21 02_52_29 +0000).data
// Rearr. | z=0.55           | Reaction 7l (2024-07-21 02_59_38 +0000).data
// Branch Point
//
// CH2    | z=0.60           | Reaction 8l (2024-07-21 13_13_16 +0000).data
// Rearr. | z=0.60           | Reaction 9l (2024-07-21 13_17_19 +0000).data
// HDon   | z=0.60           | Reaction 10l (2024-07-21 13_21_13 +0000).data
// Cage Completion
//
// SiH2   | z=0.65           | Reaction 8l (2024-07-21 13_29_48 +0000).data
// Dead End
//
// HDon   | z=0.60, C3Sn     | Reaction 8l (2024-07-21 13_56_06 +0000).data
// CH2\*  | z=0.50           | Reaction 9l (2024-07-21 14_05_24 +0000).data
// Cage Completion
//
// GeH2\* | z=0.70           | Reaction 3l (2024-07-21 14_18_36 +0000).data
// HAbst  | z=0.63, tilt=30° | Reaction 4l (2024-07-21 14_43_28 +0000).data
// HAbst  | z=0.35           | Reaction 5l (2024-07-21 14_59_52 +0000).data
// Dead End
//
// > Reaction 5l above had SCF convergence issues.
//
// SiH3\* | z=0.68           | Reaction 3l (2024-07-21 20_39_18 +0000).data
// HAbst**| z=0.65           | Reaction 4l (2024-07-21 20_58_00 +0000).data
// GeH3\* | z=0.68           | Reaction 3l (2024-07-21 20_43_01 +0000).data
// HAbst**| z=0.65           | Reaction 4l (2024-07-21 21_03_11 +0000).data
// SiH3\* | z=0.60           | Reaction 2l (2024-07-21 21_27_42 +0000).data
// HAbst  | z=0.65           | Reaction 3l (2024-07-21 21_38_59 +0000).data
// HAbst  | z=0.40, C3Si     | Reaction 4l (2024-07-21 22_27_31 +0000).data
// HAbst  | z=0.30, C3Si     | Reaction 5l (2024-07-21 22_49_32 +0000).data
//        | z=0.65, C3Ge-C2  | Reaction 5l (2024-07-21 22_58_23 +0000).data
// HAbst  | z=0.90           | Reaction 6l (2024-07-21 23_04_40 +0000).data
// HAbst  | z=0.70           | Reaction 7l (2024-07-21 23_28_45 +0000).data
//
// > \**Minimization had 6-membered ring, but may be contaminated with
// > artificial charge localization. Restarting from the result of Reaction 1l,
// > for a conservative analysis.
//
// > Reaction 5l above (C3Si variant) had SCF convergence issues.
//
func createGeometry() -> [[Entity]] {
  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  
//  for atomID in siliconTooltip.surface.indices {
//    // Right:  14 1 SIMD3<Float>(0.390625, -0.15234375, 0.005859375)
//    // Front:  16 1 SIMD3<Float>(0.19921875, -0.15136719, 0.3359375)
//    // Center: 19 1 SIMD3<Float>(-0.001953125, -0.14550781, 0.0)
//    let atom = siliconTooltip.surface[atomID]
//    guard atomID == 14 || atomID == 16 else {
//      continue
//    }
//
//    // Transmute a hydrogen passivator to carbon.
//    siliconTooltip.surface[atomID].atomicNumber = 6
//    siliconTooltip.surface[atomID].position.y = -0.19
//
//    // Add three new hydrogens.
//    let positionDeltas: [SIMD3<Float>] = [
//      SIMD3(0.00, -0.10, -0.10),
//      SIMD3(-0.10, -0.10, 0.05),
//      SIMD3(0.10, -0.10, 0.05),
//    ]
//    for positionDelta in positionDeltas {
//      let position = atom.position + positionDelta
//      let hydrogen = Entity(position: position, type: .atom(.hydrogen))
//      siliconTooltip.surface.append(hydrogen)
//    }
//  }
  
//  for atomID in siliconTooltip.surface.indices {
//    var atom = siliconTooltip.surface[atomID]
//    guard atom.atomicNumber == 1 else {
//      continue
//    }
//
//    atom.atomicNumber = 6
//    atom.position.y += -0.050
//    atom.position.x *= 0.90
//    atom.position.z *= 0.90
//    siliconTooltip.surface[atomID] = atom
//  }
//  siliconTooltip.surface += [
//    Entity(position: SIMD3(0.00, -0.33, 0.00), type: .atom(.germanium)),
//  ]
//  for sideID in 0..<3 {
//    let angle = Float(sideID) * 120 * .pi / 180
//    let rotation = Quaternion(angle: angle, axis: SIMD3(0.00, 1.00, 0.00))
//
//    let rawHydrogens: [Entity] = [
//      Entity(position: SIMD3(0.30, -0.30, 0.05), type: .atom(.hydrogen)),
//      Entity(position: SIMD3(-0.30, -0.30, 0.05), type: .atom(.hydrogen)),
//    ]
//    for rawHydrogen in rawHydrogens {
//      var hydrogen = rawHydrogen
//      hydrogen.position = rotation.act(on: hydrogen.position)
//      siliconTooltip.surface.append(hydrogen)
//    }
//  }
  
  do {
    let cacheFolder =
    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
    let folder = URL(filePath: cacheFolder)
    let fileName = "Reaction 7l (2024-07-21 23_28_45 +0000).data"
    let file = folder.appending(
      component: fileName, directoryHint: .notDirectory)
    
    let data = try! Data(contentsOf: file)
    let frames = Serialization.decode(frames: data)
    siliconTooltip.surface = frames.last!
  }
  siliconTooltip.minimizeSurface()
  
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .methylene
  cageTooltipDesc.frameworkType = .adamantasilane(.germanium)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  replaceApex(tooltip: &cageTooltip)
  try! cageTooltip.loadCachedValue()
  
  // TODO: Rotate the cage tooltip 90 degrees and try again.
  
  var reactionDesc = Silicon111ReactionDescriptor()
  reactionDesc.siliconTooltip = siliconTooltip
  reactionDesc.cageTooltip = cageTooltip
  reactionDesc.frameBudget = 4 * 60
  reactionDesc.nearOffset = SIMD3(-0.20, 0.60, -0.10)
  reactionDesc.farOffset = reactionDesc.nearOffset! + SIMD3(0.00, 0.20, 0.00)
  
  var reaction = Silicon111Reaction(descriptor: reactionDesc)
  
  var output: [[Entity]] = []
  output.append(createFrame(reaction: reaction))
  return output
  
  // Run molecular dynamics.
  do {
    for _ in 0..<reaction.frameBudget {
      try reaction.step()
      output.append(createFrame(reaction: reaction))
    }
    output.append(try reaction.createProduct(
      type: .donation([.carbon, .hydrogen, .hydrogen])
    ))
    
    // Serialize the product, so the next reaction will be initialized with it.
    //
    // Alternatively, save the trajectory in case you lose it.
//    do {
//      let cacheFolder =
//      "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
//      let folder = URL(filePath: cacheFolder)
//      let key = Serialization.fileSafeString("\(Date())")
//      let file = folder.appending(
//        component: "Reaction 7l (\(key)).data", directoryHint: .notDirectory)
//      let data = Serialization.encode(frames: output)
//      try! data.write(to: file, options: .atomic)
//    }
  } catch {
    print("[ERROR]", error.localizedDescription)
  }
  
  return output
}

func createFrame(reaction: Silicon111Reaction) -> [Entity] {
  var output: [Entity] = []
  let siliconTooltip = reaction.createSiliconTooltip()
  output += siliconTooltip.surface
  output += Silicon111Tooltip.createLinkAtoms(
    inner: siliconTooltip.surface,
    outer: siliconTooltip.anchors,
    boundary: siliconTooltip.boundary)
  
  let cageTooltip = reaction.createCageTooltip()
  output += cageTooltip.feedstock
  output += cageTooltip.apex
  output += cageTooltip.framework
  output += CageTooltip.createLinkAtoms(
    inner: cageTooltip.framework,
    outer: cageTooltip.legs,
    boundary: cageTooltip.frameworkLegsBoundary)
  return output
}
#endif

func replaceApex(tooltip: inout CageTooltip) {
  for atomID in tooltip.apex.indices {
    var atom = tooltip.apex[atomID]
    if atom.position.y < -0.020,
       atom.atomicNumber == 6 || atom.atomicNumber == 14 {
      atom.atomicNumber = 6
    }
    tooltip.apex[atomID] = atom
  }
  
  // Ensure the (now corrupted) apex-framework boundary is never accessed.
  tooltip.apexFrameworkBoundary = [SIMD2(99000, 999000)]
  
  // Shrink the list of apex atoms.
//  var hydrogenCursor = 0
//  var removedHydrogens: [UInt32] = []
//  for atomID in tooltip.apex.indices {
//    let atom = tooltip.apex[atomID]
//    if atom.atomicNumber == 1 {
//      removedHydrogens.append(UInt32(atomID))
//      hydrogenCursor += 1
//    }
//  }
//  for atomID in removedHydrogens.reversed() {
//    tooltip.apex.remove(at: Int(atomID))
//  }
}

#if false
// Workspace for measuring energies.
func createGeometry() -> [Entity] {
  struct Framework {
    var type: CageFrameworkType
    var apexPassivators: [Element] = [
      .hydrogen, .hydrogen,
      .hydrogen, .hydrogen,
      .hydrogen, .hydrogen,
    ]
  }
  
  struct Reaction {
    var chargedTooltip: CageFeedstockType
    var dischargedTooltip: CageFeedstockType
    var unboundFeedstock: CageFeedstockType
  }
  
  let frameworks: [Framework] = [
    Framework(type: .ethynylAdamantane),
    Framework(type: .adamantane(.carbon)),
    Framework(type: .adamantane(.silicon)),
    Framework(type: .adamantane(.germanium)),
    Framework(type: .atrane(.silicon)),
    Framework(type: .atrane(.germanium)),
    Framework(type: .atrane(.tin)),
    Framework(type: .atrane(.lead)),
    Framework(type: .adamantasilane(.carbon)),
    Framework(type: .adamantasilane(.silicon)),
    Framework(type: .adamantasilane(.germanium)),
    Framework(type: .adamantasilane(.tin)),
    Framework(type: .adamantasilane(.lead)),
  ]
  let frameworkNames: [String] = [
    "| ethynyl-adamantane ",
    "| adamantane(C)      ",
    "| adamantane(Si)     ",
    "| adamantane(Ge)     ",
    "| atrane(Si)         ",
    "| atrane(Ge)         ",
    "| atrane(Sn)         ",
    "| atrane(Pb)         ",
    "| adamantasilane(C)  ",
    "| adamantasilane(Si) ",
    "| adamantasilane(Ge) ",
    "| adamantasilane(Sn) ",
    "| adamantasilane(Pb) ",
  ]
  let feedstocks: [Reaction] = [
    Reaction(
      chargedTooltip: .germene,
      dischargedTooltip: .radical,
      unboundFeedstock: .germene),
    Reaction(
      chargedTooltip: .germylene,
      dischargedTooltip: .radical,
      unboundFeedstock: .germylene),
    Reaction(
      chargedTooltip: .germane,
      dischargedTooltip: .radical,
      unboundFeedstock: .germane),
  ]
  
  // Cache the feedstocks once, for all tooltips.
  var unboundFeedstocks: [[Entity]] = []
  for feedstockID in feedstocks.indices {
    let reaction = feedstocks[feedstockID]
    var unboundAtoms = CageTooltip.createFeedstock(
      type: reaction.unboundFeedstock)
    unboundAtoms = minimize(atoms: unboundAtoms)
    unboundFeedstocks.append(unboundAtoms)
  }
  
  // Iterate over all possible tooltip-feedstock combinations.
  var output: [Entity] = []
  print()
  for frameworkID in frameworks.indices {
    print(frameworkNames[frameworkID], terminator: " |")
    for feedstockID in feedstocks.indices {
      let reaction = feedstocks[feedstockID]
      let framework = frameworks[frameworkID]
      
      var cageTooltipDesc = CageTooltipDescriptor()
      cageTooltipDesc.apexPassivators = framework.apexPassivators
      cageTooltipDesc.feedstockType = reaction.dischargedTooltip
      cageTooltipDesc.frameworkType = framework.type
      var dischargedTooltip = CageTooltip(descriptor: cageTooltipDesc)
      try! dischargedTooltip.loadCachedValue()
      
      cageTooltipDesc = CageTooltipDescriptor()
      cageTooltipDesc.apexPassivators = framework.apexPassivators
      cageTooltipDesc.feedstockType = reaction.chargedTooltip
      cageTooltipDesc.frameworkType = framework.type
      var chargedTooltip = CageTooltip(descriptor: cageTooltipDesc)
      try! chargedTooltip.loadCachedValue()
      
      let dischargedTooltipAtoms =
      dischargedTooltip.legs +
      dischargedTooltip.framework +
      dischargedTooltip.apex +
      dischargedTooltip.feedstock
      
      let chargedTooltipAtoms =
      chargedTooltip.legs +
      chargedTooltip.framework +
      chargedTooltip.apex +
      chargedTooltip.feedstock
      
      let unboundFeedstockAtoms = unboundFeedstocks[feedstockID]
      
      func measureEnergy(atoms: [Entity]) -> Double {
        var calculatorDesc = xTB_CalculatorDescriptor()
        calculatorDesc.atomicNumbers = atoms.map(\.atomicNumber)
        calculatorDesc.hamiltonian = .tightBinding
        calculatorDesc.positions = atoms.map(\.position)
        
        xTB_Environment.show()
        let calculator = xTB_Calculator(descriptor: calculatorDesc)
        return calculator.energy
      }
      
      // Measure and report the binding energy.
      var removalEnergy: Double = .zero
      removalEnergy += measureEnergy(atoms: dischargedTooltipAtoms)
      removalEnergy -= measureEnergy(atoms: chargedTooltipAtoms)
      removalEnergy += measureEnergy(atoms: unboundFeedstockAtoms)
      let energyInEV = removalEnergy / 160.218
      let repr = "+\(String(format: "%.2f", energyInEV)) eV"
      print(" " + repr, terminator: " |")
      
      // Display some atoms for structure debugging.
      let reagents: [[Entity]] = [
        chargedTooltipAtoms,
        dischargedTooltipAtoms,
        unboundFeedstockAtoms,
      ]
      for reagentID in reagents.indices {
        var reagentAtoms = reagents[reagentID]
        for atomID in reagentAtoms.indices {
          let offset = SIMD3<Float>(
            1.50 * Float(feedstockID),
            -1.50 * Float(frameworkID),
            1.50 * Float(reagentID))
          reagentAtoms[atomID].position += offset
        }
        output += reagentAtoms
      }
    }
    print()
  }
  
  return output
}
#endif
