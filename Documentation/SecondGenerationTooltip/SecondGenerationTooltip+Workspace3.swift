//
//  Workspace3.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/28/24.
//

import Foundation
import HDL
import Numerics

// Workspace for sifting through the build sequence and converting it into
// one executed through replication.
// - Count the number of operations in the existing sequence specification.
//   - How many types of tripods?
//   - How many tripods of each type?
// - Map the atrane tripod tools to the corresponding apices.
//   - Gather total build sequence statistics like the above.
//
// ## Commence First Layer
//
// [??/??] Placing Initial Monomers
// repeat 3 times
//   HAbst (Ge-C2)
//   CH2 (NC3Sn -> C3Ge)
//   HDon (NC3Sn -> C3Ge) to CH2
// HAbst (Ge-C2) from CH3
// HAbst (Ge-C2) from Si3Si
// SiH2 (C3Ge) in two strokes
//
// TODO: Revise the next part. Cage formation proceeds differently.
//
// [??/??] Forming First Cage
// repeat 3 times
//   HAbst (Ge-C2) from carbon
//   HAbst (Ge-C2) from silicon
//   Rearr. (Ge-CH3)
// HDon (NC3Ge) to C3Si
// leave Si3Si unpassivated
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
// [] Forming C3Ge Apex
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
// [] Forming CSi2Si Apex
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
// ## Charging and Discharging Operations

#if false
func createGeometry() -> [Entity] {
  // Carbon atoms to anchor: [0, 1, 2, 7, 8, 13]
  let tooltipAnchorIDs: [UInt32] = [0, 1, 2, 7, 8, 13]
  var tooltipAtoms: [Entity] = [
    Entity(position: SIMD3(1.4204, 0.7689, 1.1989), type: .atom(.carbon)),
    Entity(position: SIMD3(1.2006, 0.9904, 1.2004), type: .atom(.carbon)),
    Entity(position: SIMD3(1.4089, 0.9801, 0.9748), type: .atom(.carbon)),
    Entity(position: SIMD3(1.3036, 1.0969, 1.0813), type: .atom(.silicon)),
    Entity(position: SIMD3(1.4232, 1.2064, 1.1800), type: .atom(.carbon)),
    Entity(position: SIMD3(1.5258, 0.8756, 1.0824), type: .atom(.silicon)),
    Entity(position: SIMD3(1.6320, 0.9966, 1.1832), type: .atom(.carbon)),
    Entity(position: SIMD3(1.1997, 0.7698, 1.4213), type: .atom(.carbon)),
    Entity(position: SIMD3(1.4013, 0.5380, 1.4026), type: .atom(.carbon)),
    Entity(position: SIMD3(1.2932, 0.6387, 1.5242), type: .atom(.silicon)),
    Entity(position: SIMD3(1.4305, 0.7472, 1.6769), type: .atom(.silicon)),
    Entity(position: SIMD3(1.5221, 0.6366, 1.2914), type: .atom(.silicon)),
    Entity(position: SIMD3(1.6771, 0.7436, 1.4268), type: .atom(.silicon)),
    Entity(position: SIMD3(0.9727, 0.9780, 1.4081), type: .atom(.carbon)),
    Entity(position: SIMD3(1.0810, 0.8751, 1.5257), type: .atom(.silicon)),
    Entity(position: SIMD3(1.1786, 0.9953, 1.6352), type: .atom(.carbon)),
    Entity(position: SIMD3(1.0775, 1.0945, 1.3006), type: .atom(.silicon)),
    Entity(position: SIMD3(1.1717, 1.2107, 1.4170), type: .atom(.carbon)),
    Entity(position: SIMD3(1.3128, 0.8803, 1.3121), type: .atom(.silicon)),
    Entity(position: SIMD3(1.4278, 0.9918, 1.4185), type: .atom(.carbon)),
    Entity(position: SIMD3(1.3004, 1.1048, 1.5238), type: .atom(.germanium)),
    Entity(position: SIMD3(1.5471, 0.9009, 1.5427), type: .atom(.silicon)),
    Entity(position: SIMD3(1.5286, 1.1043, 1.3011), type: .atom(.silicon)),
    Entity(position: SIMD3(1.3496, 0.7149, 1.1356), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.1410, 0.9229, 1.1385), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.4667, 1.0382, 0.9033), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.3444, 0.9151, 0.9161), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.2153, 1.1801, 0.9960), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.3695, 1.2853, 1.2314), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.4903, 1.2564, 1.1104), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.6118, 0.7909, 0.9962), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.6834, 1.0629, 1.1141), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.7099, 0.9436, 1.2367), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.1368, 0.7144, 1.3512), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.3358, 0.4786, 1.3388), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.4592, 0.4659, 1.4602), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.1905, 0.5449, 1.5766), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.5316, 0.6537, 1.7307), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.3632, 0.7877, 1.8018), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.5714, 0.5407, 1.1892), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.8024, 0.7815, 1.3587), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.7302, 0.6504, 1.5287), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.9147, 0.9117, 1.3444), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.9008, 1.0361, 1.4654), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.9952, 0.7895, 1.6114), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.2304, 0.9429, 1.7146), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.1086, 1.0633, 1.6835), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.9898, 1.1743, 1.2112), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.1017, 1.2567, 1.4867), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.2186, 1.2916, 1.3622), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.6180, 1.0116, 1.6127), type: .atom(.hydrogen)),
    Entity(position: SIMD3(1.6151, 1.1951, 1.3807), type: .atom(.hydrogen)),
  ]
  
  
  // Rotate the tooltip from (111) to (100).
  do {
    let origin = SIMD3<Float>(1.30, 1.10, 1.52)
    let basisVector0 = SIMD3<Float>(1, 0, -1) / Float(2).squareRoot()
    let basisVector1 = SIMD3<Float>(-1, -1, -1) / Float(3).squareRoot()
    let basisVector2 = SIMD3<Float>(-1, 2, -1) / Float(6).squareRoot()
    
    let coaxialRotation = Quaternion<Float>(
      angle: 150 * .pi / 180, axis: SIMD3(0.00, 1.00, 0.00))
    
    for atomID in tooltipAtoms.indices {
      var atom = tooltipAtoms[atomID]
      var delta = atom.position - origin
      delta = SIMD3(
        (delta * basisVector0).sum(),
        (delta * basisVector1).sum(),
        (delta * basisVector2).sum())
      
      atom.position = delta
      atom.position = coaxialRotation.act(on: atom.position)
      tooltipAtoms[atomID] = atom
    }
  }
  
  // Translate the tooltip.
  for atomID in tooltipAtoms.indices {
    var atom = tooltipAtoms[atomID]
    atom.position += SIMD3(0.20, 0.55, 0.05)
    tooltipAtoms[atomID] = atom
  }
  
  // Generate a surface model.
  // Silicon atoms to anchor: [0, 1, 2, 5, 6, 9]
  let surfaceAnchorIDs: [UInt32] = [0, 1, 2, 5, 6, 9]
  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  siliconTooltip.surface.remove(at: 19)
  siliconTooltip.surface.remove(at: 14)
  siliconTooltip.surface += [
    Entity(position: SIMD3(0.38, -0.18, 0.00), type: .atom(.carbon)),
    Entity(position: SIMD3(0.38, -0.23, 0.10), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.38, -0.23, -0.10), type: .atom(.hydrogen)),
  ]
  
  // Move the entire tooltip, so the anchor-surface boundary will generate
  // correctly.
  for atomID in siliconTooltip.anchors.indices {
    var atom = siliconTooltip.anchors[atomID]
    atom.position.y = -atom.position.y
    siliconTooltip.anchors[atomID] = atom
  }
  for atomID in siliconTooltip.surface.indices {
    var atom = siliconTooltip.surface[atomID]
    atom.position.y = -atom.position.y
    siliconTooltip.surface[atomID] = atom
  }
  
  // Hard-code the coordinates of the feedstock atoms.
  let feedstock: [Entity] = [
    Entity(position: SIMD3(0.20, 0.30, 0.00), type: .atom(.silicon)),
    Entity(position: SIMD3(0.15, 0.23, 0.13), type: .atom(.hydrogen)),
    Entity(position: SIMD3(0.15, 0.23, -0.13), type: .atom(.hydrogen)),
  ]
  
  // Collect the atoms into one array.
  var systemAtoms: [Entity] = []
  systemAtoms += tooltipAtoms
  systemAtoms += feedstock
  systemAtoms += siliconTooltip.surface
  systemAtoms += Silicon111Tooltip.createLinkAtoms(
    inner: siliconTooltip.surface,
    outer: siliconTooltip.anchors,
    boundary: siliconTooltip.boundary)
  
  // Correct the anchor indices.
  var anchorIDs: [UInt32] = []
  anchorIDs += tooltipAnchorIDs
  anchorIDs += surfaceAnchorIDs.map {
    var copy = $0
    copy += UInt32(tooltipAtoms.count)
    copy += UInt32(feedstock.count)
    return copy
  }
  do {
    // Add all of the link atoms to the anchors.
    let start = (tooltipAtoms + feedstock + siliconTooltip.surface).count
    let end = systemAtoms.count
    for atomID in start..<end {
      anchorIDs.append(UInt32(atomID))
    }
  }
  
  systemAtoms = [
    Entity(position: SIMD3(-0.1646,  0.8570,  0.0571), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1059,  0.8552, -0.0985), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1604,  0.8711, -0.2507), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0166,  0.8023, -0.2577), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0039,  0.6130, -0.2662), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2546,  0.8021, -0.1008), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2512,  0.6128, -0.1157), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1068,  0.8555,  0.2137), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1601,  0.8838,  0.3644), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0188,  0.8168,  0.3787), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0166,  0.5859,  0.4066), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2634,  0.8201,  0.2162), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2887,  0.5902,  0.2349), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3717,  0.8740,  0.0571), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2885,  0.7992,  0.2108), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3052,  0.6106,  0.1980), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2904,  0.8121, -0.1028), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3112,  0.6245, -0.1075), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0156,  0.7878,  0.0579), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0135,  0.5950,  0.0514), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.2088,  0.5352,  0.0394), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.0713,  0.5080,  0.2034), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0752,  0.5410, -0.1091), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1540,  0.9655,  0.0509), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0999,  0.9641, -0.0942), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2131,  0.8455, -0.3424), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1579,  0.9797, -0.2465), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0876,  0.8544, -0.3773), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1011,  0.5686, -0.2848), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0581,  0.5858, -0.3515), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3946,  0.8513, -0.1019), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2945,  0.5855, -0.2117), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3148,  0.5673, -0.0407), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1083,  0.9641,  0.2028), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1564,  0.9926,  0.3606), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2133,  0.8594,  0.4563), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0855,  0.8992,  0.4830), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0798,  0.5473,  0.5120), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1410,  0.5308,  0.4643), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3852,  0.9052,  0.2119), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4034,  0.5351,  0.1602), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3278,  0.5542,  0.3730), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3660,  0.9825,  0.0617), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4776,  0.8489,  0.0564), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3592,  0.8455,  0.3331), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2743,  0.5624,  0.2901), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4108,  0.5869,  0.1851), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3566,  0.8743, -0.2204), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4162,  0.5996, -0.0915), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2850,  0.5849, -0.2051), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0611,  0.3617,  0.1750), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0792,  0.3920, -0.1168), type: .atom(.hydrogen)),
    
    Entity(position: SIMD3( 0.2258,  0.2994,  0.0092), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1403,  0.2379,  0.1126), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1622,  0.2647, -0.1195), type: .atom(.hydrogen)),
    
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1940,  0.0035, -0.3307), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3808,  0.0101, -0.0016), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1903,  0.0030,  0.3321), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1886,  0.0048,  0.3315), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3816,  0.0032, -0.0008), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1904,  0.0042, -0.3293), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0010, -0.0008, -0.0003), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1912,  0.1496, -0.3460), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2028,  0.1496,  0.3354), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1998,  0.1512,  0.3390), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3914,  0.1496,  0.0080), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1879,  0.1506, -0.3417), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3900,  0.2024,  0.0134), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.4404,  0.2252,  0.1074), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4557,  0.2403, -0.0650), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.10, 0.00, -0.10)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(0.00, 0.00, -0.10)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(0.00, 0.00, -0.10)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(0.00, 0.00, -0.10)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.2646,  0.8570, -0.0429), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0059,  0.8552, -0.1985), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2604,  0.8711, -0.3507), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0820,  0.8057, -0.3591), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0845,  0.6160, -0.3666), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3502,  0.7954, -0.2010), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3349,  0.6060, -0.2143), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0068,  0.8555,  0.1137), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2601,  0.8838,  0.2644), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0809,  0.8172,  0.2792), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0803,  0.5864,  0.3097), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3620,  0.8175,  0.1164), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3816,  0.5865,  0.1342), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2717,  0.8740, -0.0429), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1907,  0.8094,  0.1157), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2162,  0.6224,  0.1145), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1896,  0.8058, -0.1999), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2185,  0.6186, -0.1956), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0826,  0.7862, -0.0414), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0740,  0.5921, -0.0435), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1261,  0.5324, -0.0402), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.1632,  0.5048,  0.1058), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1564,  0.5391, -0.2080), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2548,  0.9653, -0.0505), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0036,  0.9641, -0.1920), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3131,  0.8462, -0.4425), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2603,  0.9795, -0.3437), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0129,  0.8614, -0.4780), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0150,  0.5784, -0.3877), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1465,  0.5844, -0.4504), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4933,  0.8346, -0.2030), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3772,  0.5761, -0.3101), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3966,  0.5580, -0.1393), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0040,  0.9641,  0.1023), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2568,  0.9926,  0.2594), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3133,  0.8600,  0.3564), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0149,  0.9009,  0.3829), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1777,  0.5478,  0.4141), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0437,  0.5331,  0.3698), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4864,  0.8989,  0.1125), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4949,  0.5304,  0.0580), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4219,  0.5493,  0.2717), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2674,  0.9827, -0.0443), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3773,  0.8480, -0.0432), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2579,  0.8691,  0.2340), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1867,  0.5775,  0.2088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3228,  0.6025,  0.1034), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2564,  0.8626, -0.3201), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3254,  0.6005, -0.1834), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1900,  0.5719, -0.2893), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1470,  0.3585,  0.0780), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1529,  0.3903, -0.2178), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1871,  0.2957, -0.0182), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1146,  0.2549,  0.1043), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1203,  0.2298, -0.1323), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1941,  0.0033, -0.3309), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3786,  0.0136, -0.0024), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1903,  0.0031,  0.3321), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1886,  0.0049,  0.3314), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3817,  0.0034, -0.0008), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1904,  0.0042, -0.3292), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0014, -0.0038,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1931,  0.1491, -0.3491), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2029,  0.1497,  0.3354), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2004,  0.1513,  0.3369), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3912,  0.1499,  0.0080), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1878,  0.1507, -0.3414), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3601,  0.2092, -0.0007), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.4028,  0.2432,  0.0939), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4268,  0.2485, -0.0778), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.06, -0.08, -0.06)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(-0.03, -0.04, -0.03)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(-0.03, -0.04, -0.03)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(-0.03, -0.04, -0.03)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.3246,  0.7770, -0.1029), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0541,  0.7752, -0.2585), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3204,  0.7911, -0.4107), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1418,  0.7259, -0.4192), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1417,  0.5362, -0.4236), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4099,  0.7154, -0.2608), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3909,  0.5265, -0.2712), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0532,  0.7755,  0.0537), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3201,  0.8038,  0.2044), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1401,  0.7387,  0.2203), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1356,  0.5089,  0.2561), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4203,  0.7340,  0.0567), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4342,  0.5021,  0.0762), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2117,  0.7940, -0.1029), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1323,  0.7447,  0.0607), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1617,  0.5605,  0.0669), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.1298,  0.7281, -0.2602), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1624,  0.5425, -0.2513), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1419,  0.7081, -0.1008), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1281,  0.5157, -0.0979), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0751,  0.4681, -0.0883), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.2135,  0.4257,  0.0515), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2111,  0.4632, -0.2620), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3161,  0.8855, -0.1091), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0567,  0.8842, -0.2525), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3732,  0.7661, -0.5024), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3204,  0.8995, -0.4038), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0731,  0.7812, -0.5385), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0419,  0.4996, -0.4450), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2043,  0.5017, -0.5058), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5533,  0.7532, -0.2633), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4315,  0.4941, -0.3670), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4526,  0.4785, -0.1962), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0619,  0.8843,  0.0428), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3178,  0.9125,  0.1977), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3733,  0.7808,  0.2966), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0751,  0.8257,  0.3220), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2345,  0.4707,  0.3593), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0121,  0.4573,  0.3186), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5471,  0.8116,  0.0529), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5457,  0.4428, -0.0002), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4748,  0.4650,  0.2137), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2154,  0.9028, -0.1092), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3158,  0.7618, -0.1021), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1956,  0.8182,  0.1730), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1303,  0.5158,  0.1605), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2685,  0.5407,  0.0573), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1957,  0.7860, -0.3803), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2697,  0.5257, -0.2424), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1298,  0.4899, -0.3404), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1836,  0.2808,  0.0254), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2090,  0.3154, -0.2646), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1769,  0.2607, -0.0316), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1146,  0.2328,  0.0998), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1267,  0.1700, -0.1355), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1943,  0.0037, -0.3316), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3794,  0.0094, -0.0027), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1905,  0.0037,  0.3320), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1886,  0.0052,  0.3315), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3820,  0.0036, -0.0009), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1902,  0.0012, -0.3292), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0022, -0.0106,  0.0004), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1957,  0.1490, -0.3554), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2032,  0.1503,  0.3352), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2009,  0.1516,  0.3379), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3957,  0.1499,  0.0072), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1854,  0.1463, -0.3459), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3586,  0.2030, -0.0068), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3964,  0.2447,  0.0866), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4227,  0.2433, -0.0854), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.04, 0.00, 0.24)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(-0.02, 0.00, 0.12)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(-0.02, 0.00, 0.12)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(-0.02, 0.00, 0.12)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.3646,  0.7770,  0.1371), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0941,  0.7752, -0.0185), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3604,  0.7911, -0.1707), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1804,  0.7300, -0.1816), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1825,  0.5417, -0.2012), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4492,  0.7141, -0.0214), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4318,  0.5253, -0.0414), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0932,  0.7755,  0.2937), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3601,  0.8038,  0.4444), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1815,  0.7346,  0.4581), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1708,  0.5021,  0.4757), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4610,  0.7354,  0.2965), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4708,  0.5036,  0.3068), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1717,  0.7940,  0.1371), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0890,  0.7214,  0.2907), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1198,  0.5363,  0.2687), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0926,  0.7539, -0.0292), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1296,  0.5724, -0.0498), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1814,  0.7080,  0.1364), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1650,  0.5167,  0.1177), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0405,  0.4694,  0.0975), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.2507,  0.4287,  0.2669), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2519,  0.4626, -0.0433), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3559,  0.8853,  0.1291), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1072,  0.8841, -0.0119), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4130,  0.7657, -0.2624), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3622,  0.8996, -0.1636), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1122,  0.7938, -0.2970), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0835,  0.5038, -0.2238), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2456,  0.5143, -0.2854), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5928,  0.7514, -0.0223), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4767,  0.4983, -0.1369), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4899,  0.4732,  0.0338), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0924,  0.8841,  0.2831), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3555,  0.9124,  0.4381), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4135,  0.7813,  0.5366), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1155,  0.8145,  0.5647), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2655,  0.4517,  0.5777), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0435,  0.4543,  0.5335), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5872,  0.8137,  0.2934), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5857,  0.4482,  0.2324), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5066,  0.4605,  0.4439), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1764,  0.9024,  0.1486), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2755,  0.7611,  0.1345), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1575,  0.7700,  0.4134), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0841,  0.4775,  0.3525), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2275,  0.5205,  0.2634), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1505,  0.8390, -0.1363), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2365,  0.5541, -0.0388), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1010,  0.5339, -0.1470), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2438,  0.2875,  0.2214), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2407,  0.3144, -0.0577), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1550,  0.2647,  0.0391), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0923,  0.1833,  0.1448), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1026,  0.2345, -0.0960), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1940,  0.0038, -0.3307), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3776,  0.0135, -0.0006), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1896, -0.0004,  0.3329), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1887,  0.0046,  0.3325), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3820,  0.0036, -0.0008), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1905,  0.0046, -0.3293), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0019, -0.0127, -0.0006), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1927,  0.1500, -0.3456), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1964,  0.1447,  0.3501), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2043,  0.1502,  0.3463), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3958,  0.1495,  0.0089), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1883,  0.1510, -0.3424), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3397,  0.2055,  0.0264), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3905,  0.2331,  0.1190), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3896,  0.2630, -0.0520), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.04, 0.04, -0.06)
    systemAtoms[atomID] = atom
  }
  
  // Tooltip and feedstock moved -0.10 nm along Z:
  // Move hydrogen -0.00 nm along X: energy minimum is -2653.89 eV
  // Move hydrogen -0.05 nm along X: energy minimum is -2653.89 eV
  // Move hydrogen -0.10 nm along X: energy minimum is -2655.03 eV, detaches
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(-0.02, 0.02, -0.03)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(-0.02, 0.02, -0.03)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(-0.02, 0.02, -0.03)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.4046,  0.8170,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1341,  0.8152, -0.0785), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4004,  0.8311, -0.2307), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2209,  0.7685, -0.2406), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2226,  0.5796, -0.2557), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4892,  0.7545, -0.0812), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4716,  0.5656, -0.0989), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1332,  0.8155,  0.2337), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4001,  0.8438,  0.3844), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2207,  0.7770,  0.3989), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2092,  0.5457,  0.4219), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4995,  0.7729,  0.2366), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5076,  0.5407,  0.2495), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1317,  0.8340,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0495,  0.7624,  0.2317), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0831,  0.5770,  0.2164), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0519,  0.7822, -0.0862), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0900,  0.5990, -0.1007), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2209,  0.7456,  0.0771), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2044,  0.5522,  0.0643), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0064,  0.4941,  0.0496), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.2870,  0.4643,  0.2156), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2922,  0.5007, -0.0974), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3954,  0.9253,  0.0703), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1427,  0.9241, -0.0711), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4530,  0.8057, -0.3224), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4017,  0.9396, -0.2237), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1529,  0.8296, -0.3576), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1232,  0.5423, -0.2780), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2853,  0.5506, -0.3397), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6329,  0.7917, -0.0827), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5150,  0.5378, -0.1949), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5315,  0.5147, -0.0244), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1327,  0.9239,  0.2215), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3971,  0.9524,  0.3772), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4534,  0.8213,  0.4767), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1556,  0.8596,  0.5040), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3039,  0.4975,  0.5251), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0820,  0.4996,  0.4813), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6278,  0.8480,  0.2339), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6208,  0.4833,  0.1737), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5458,  0.4990,  0.3864), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1313,  0.9427,  0.0839), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2366,  0.8051,  0.0757), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1171,  0.8151,  0.3534), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0499,  0.5220,  0.3039), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1911,  0.5633,  0.2109), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1125,  0.8590, -0.1984), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1977,  0.5837, -0.0918), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0611,  0.5586, -0.1971), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2690,  0.3189,  0.1860), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2872,  0.3520, -0.1118), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1459,  0.2790,  0.0194), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0865,  0.2077,  0.1350), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0925,  0.2323, -0.1110), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1942,  0.0038, -0.3308), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3766,  0.0166, -0.0015), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1902,  0.0030,  0.3325), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1886,  0.0050,  0.3320), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3819,  0.0038, -0.0009), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1906,  0.0047, -0.3293), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0014, -0.0122, -0.0002), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1926,  0.1499, -0.3463), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2015,  0.1494,  0.3382), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2026,  0.1509,  0.3418), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3925,  0.1501,  0.0079), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1874,  0.1511, -0.3416), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3312,  0.2104,  0.0147), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3790,  0.2425,  0.1076), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3852,  0.2635, -0.0643), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(0.00, -0.04, 0.00)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(0.00, -0.02, 0.00)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(0.00, -0.02, 0.00)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(0.00, -0.02, 0.00)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.4046,  0.7770,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1341,  0.7752, -0.0785), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4004,  0.7911, -0.2307), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2206,  0.7295, -0.2410), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2222,  0.5408, -0.2576), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4889,  0.7141, -0.0812), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4708,  0.5252, -0.0992), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1332,  0.7755,  0.2337), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4001,  0.8038,  0.3844), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2207,  0.7370,  0.3988), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2087,  0.5055,  0.4212), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4996,  0.7331,  0.2366), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5072,  0.5010,  0.2494), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1317,  0.7940,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0495,  0.7229,  0.2318), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0807,  0.5378,  0.2144), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0522,  0.7456, -0.0872), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0887,  0.5628, -0.1025), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2209,  0.7067,  0.0769), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2041,  0.5142,  0.0626), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0023,  0.4600,  0.0467), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.2865,  0.4267,  0.2139), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2910,  0.4622, -0.0991), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3959,  0.8854,  0.0700), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1439,  0.8841, -0.0713), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4530,  0.7657, -0.3224), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4021,  0.8996, -0.2236), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1528,  0.7916, -0.3576), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1229,  0.5036, -0.2803), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2853,  0.5121, -0.3415), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6328,  0.7506, -0.0827), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5151,  0.4971, -0.1947), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5296,  0.4740, -0.0239), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1329,  0.8840,  0.2219), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3970,  0.9124,  0.3773), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4534,  0.7812,  0.4767), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1557,  0.8196,  0.5041), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3036,  0.4563,  0.5236), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0816,  0.4591,  0.4806), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6279,  0.8083,  0.2339), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6205,  0.4428,  0.1744), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5443,  0.4590,  0.3865), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1335,  0.9027,  0.0850), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2362,  0.7633,  0.0754), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1170,  0.7758,  0.3535), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0471,  0.4817,  0.3009), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1886,  0.5226,  0.2083), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1118,  0.8252, -0.1979), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1959,  0.5460, -0.0923), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0602,  0.5226, -0.1992), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2691,  0.2823,  0.1801), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2821,  0.3138, -0.1146), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1377,  0.2556,  0.0161), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1025,  0.2025,  0.1503), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1031,  0.2265, -0.1258), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1943,  0.0039, -0.3310), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3770,  0.0146, -0.0017), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1900,  0.0023,  0.3329), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1888,  0.0052,  0.3326), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3822,  0.0033, -0.0010), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1906,  0.0048, -0.3294), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0012, -0.0088, -0.0001), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1931,  0.1496, -0.3486), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1991,  0.1484,  0.3435), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2049,  0.1503,  0.3475), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3952,  0.1491,  0.0081), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1872,  0.1512, -0.3418), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3277,  0.2054,  0.0113), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3741,  0.2421,  0.1031), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3774,  0.2596, -0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(0.00, -0.04, 0.00)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(0.00, -0.02, 0.00)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(0.00, -0.02, 0.00)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(0.00, -0.02, 0.00)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.4046,  0.7370,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1341,  0.7352, -0.0785), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4004,  0.7511, -0.2307), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2202,  0.6916, -0.2416), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2236,  0.5037, -0.2614), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4898,  0.6753, -0.0813), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4747,  0.4865, -0.1026), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1332,  0.7355,  0.2337), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4001,  0.7638,  0.3844), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2210,  0.6960,  0.3983), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2123,  0.4642,  0.4177), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5010,  0.6957,  0.2364), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5139,  0.4640,  0.2477), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1317,  0.7540,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0487,  0.6799,  0.2301), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0740,  0.4946,  0.2083), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0522,  0.7058, -0.0872), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0837,  0.5224, -0.1028), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2218,  0.6686,  0.0766), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2110,  0.4774,  0.0595), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0105,  0.4212,  0.0420), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.2939,  0.3907,  0.2102), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2944,  0.4260, -0.1036), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3962,  0.8454,  0.0694), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1433,  0.8443, -0.0714), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4527,  0.7249, -0.3224), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4031,  0.8596, -0.2244), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1525,  0.7559, -0.3571), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1247,  0.4652, -0.2832), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2864,  0.4766, -0.3460), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6332,  0.7138, -0.0822), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5196,  0.4602, -0.1982), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5326,  0.4341, -0.0275), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1315,  0.8442,  0.2229), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3962,  0.8725,  0.3783), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4534,  0.7409,  0.4766), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1557,  0.7768,  0.5046), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3071,  0.4144,  0.5200), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0855,  0.4146,  0.4749), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6275,  0.7738,  0.2335), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6275,  0.4078,  0.1718), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5509,  0.4204,  0.3843), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1327,  0.8626,  0.0861), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2363,  0.7238,  0.0754), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1171,  0.7288,  0.3530), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0420,  0.4380,  0.2952), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1811,  0.4767,  0.1984), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1120,  0.7854, -0.1978), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1898,  0.5019, -0.0883), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0582,  0.4841, -0.2011), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2777,  0.2471,  0.1731), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2801,  0.2782, -0.1217), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1214,  0.2242,  0.0096), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1148,  0.1985,  0.1599), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1058,  0.2188, -0.1422), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1948,  0.0046, -0.3315), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3772,  0.0125, -0.0024), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1898,  0.0022,  0.3337), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1891,  0.0066,  0.3336), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3829,  0.0028, -0.0012), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1907,  0.0056, -0.3297), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0003, -0.0048,  0.0001), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1947,  0.1496, -0.3534), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1961,  0.1476,  0.3507), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2077,  0.1505,  0.3554), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4022,  0.1474,  0.0068), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1867,  0.1517, -0.3433), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3166,  0.1978,  0.0036), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3595,  0.2426,  0.0934), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3596,  0.2531, -0.0801), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.02, 0.00, 0.00)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(-0.01, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(-0.01, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(-0.01, 0.00, 0.00)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.4246,  0.7370,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1541,  0.7352, -0.0785), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4204,  0.7511, -0.2307), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2400,  0.6924, -0.2417), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2432,  0.5047, -0.2615), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5099,  0.6755, -0.0813), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4948,  0.4868, -0.1030), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1532,  0.7355,  0.2337), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4201,  0.7638,  0.3844), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2409,  0.6965,  0.3983), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2335,  0.4650,  0.4184), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5214,  0.6968,  0.2363), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5359,  0.4654,  0.2478), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1117,  0.7540,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0285,  0.6788,  0.2296), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0535,  0.4930,  0.2086), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0320,  0.7032, -0.0865), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0632,  0.5195, -0.1007), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2418,  0.6680,  0.0767), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2317,  0.4763,  0.0601), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0306,  0.4157,  0.0432), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.3160,  0.3915,  0.2113), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3144,  0.4267, -0.1040), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4157,  0.8454,  0.0692), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1621,  0.8443, -0.0708), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4726,  0.7246, -0.3224), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4235,  0.8597, -0.2246), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1726,  0.7572, -0.3571), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1442,  0.4663, -0.2831), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3058,  0.4775, -0.3463), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6533,  0.7143, -0.0822), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5397,  0.4607, -0.1986), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5527,  0.4342, -0.0279), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1510,  0.8441,  0.2225), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4164,  0.8725,  0.3789), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4733,  0.7404,  0.4766), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1757,  0.7777,  0.5045), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3284,  0.4161,  0.5211), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1069,  0.4147,  0.4755), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6472,  0.7759,  0.2333), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6493,  0.4097,  0.1712), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5740,  0.4219,  0.3842), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1110,  0.8626,  0.0857), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2166,  0.7250,  0.0756), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0971,  0.7270,  0.3527), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0221,  0.4377,  0.2965), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1607,  0.4755,  0.1987), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0924,  0.7809, -0.1982), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1694,  0.4996, -0.0857), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0387,  0.4813, -0.1994), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3013,  0.2467,  0.1794), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3004,  0.2795, -0.1253), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1169,  0.2241,  0.0096), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1179,  0.2074,  0.1612), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1023,  0.2260, -0.1427), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1948,  0.0046, -0.3315), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3769,  0.0128, -0.0027), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1898,  0.0026,  0.3335), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1891,  0.0064,  0.3335), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3828,  0.0020, -0.0013), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1908,  0.0057, -0.3297), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0003, -0.0032,  0.0002), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1944,  0.1497, -0.3527), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1954,  0.1483,  0.3475), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2075,  0.1504,  0.3545), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4015,  0.1464,  0.0065), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1865,  0.1518, -0.3428), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3132,  0.1975,  0.0003), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3575,  0.2447,  0.0884), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3547,  0.2513, -0.0852), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.02, 0.00, 0.00)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(-0.01, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(-0.01, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(-0.01, 0.00, 0.00)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.4446,  0.7370,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1741,  0.7352, -0.0785), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4404,  0.7511, -0.2307), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2614,  0.6892, -0.2403), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2711,  0.5015, -0.2546), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5348,  0.6826, -0.0811), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5319,  0.4939, -0.1031), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1732,  0.7355,  0.2337), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4401,  0.7638,  0.3844), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2617,  0.6951,  0.3980), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2697,  0.4645,  0.4220), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5453,  0.7047,  0.2360), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5790,  0.4760,  0.2516), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0917,  0.7540,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0081,  0.6805,  0.2308), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0199,  0.4926,  0.2184), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.0101,  0.6957, -0.0831), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0309,  0.5094, -0.0858), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2643,  0.6699,  0.0775), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2761,  0.4787,  0.0671), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0768,  0.4109,  0.0575), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.3620,  0.3944,  0.2182), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3537,  0.4287, -0.1001), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4339,  0.8455,  0.0693), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1803,  0.8444, -0.0724), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4925,  0.7236, -0.3222), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4412,  0.8599, -0.2277), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1920,  0.7496, -0.3568), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1729,  0.4582, -0.2702), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3304,  0.4745, -0.3418), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6747,  0.7320, -0.0808), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5763,  0.4698, -0.1995), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5928,  0.4441, -0.0286), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1725,  0.8443,  0.2240), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4352,  0.8727,  0.3825), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4933,  0.7387,  0.4761), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1948,  0.7759,  0.5033), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3663,  0.4269,  0.5275), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1467,  0.4049,  0.4777), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6639,  0.7940,  0.2308), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6933,  0.4253,  0.1732), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6208,  0.4372,  0.3880), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0889,  0.8626,  0.0829), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1970,  0.7265,  0.0761), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0785,  0.7287,  0.3526), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0107,  0.4449,  0.3108), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1252,  0.4681,  0.2049), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0750,  0.7609, -0.1999), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1350,  0.4871, -0.0635), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0111,  0.4692, -0.1848), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3521,  0.2489,  0.1913), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3459,  0.2824, -0.1226), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1434,  0.2138, -0.0098), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1418,  0.2734,  0.1248), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1197,  0.2741, -0.1418), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1941,  0.0032, -0.3311), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3795,  0.0015, -0.0030), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1898,  0.0024,  0.3325), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1889,  0.0050,  0.3315), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3816, -0.0013, -0.0012), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1903,  0.0046, -0.3293), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0063,  0.0161, -0.0016), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1923,  0.1490, -0.3490), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1972,  0.1491,  0.3398), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2006,  0.1513,  0.3398), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3948,  0.1433,  0.0093), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1879,  0.1511, -0.3410), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3359,  0.1870, -0.0142), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3811,  0.2390,  0.0703), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3809,  0.2304, -0.1036), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.02, 0.00, 0.00)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(-0.03, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(-0.03, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(-0.03, 0.00, 0.00)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.4646,  0.7370,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1941,  0.7352, -0.0785), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4604,  0.7511, -0.2307), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2816,  0.6887, -0.2400), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2919,  0.5009, -0.2535), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5553,  0.6837, -0.0811), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5535,  0.4952, -0.1026), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1932,  0.7355,  0.2337), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4601,  0.7638,  0.3844), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2817,  0.6953,  0.3981), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2916,  0.4650,  0.4233), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5655,  0.7052,  0.2359), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.6003,  0.4767,  0.2516), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0717,  0.7540,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0120,  0.6805,  0.2308), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0021,  0.4924,  0.2204), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0102,  0.6946, -0.0826), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0097,  0.5081, -0.0841), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2844,  0.6693,  0.0776), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.2970,  0.4779,  0.0679), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0979,  0.4097,  0.0594), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.3832,  0.3942,  0.2194), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3755,  0.4289, -0.0991), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4533,  0.8455,  0.0696), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2002,  0.8443, -0.0723), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5125,  0.7234, -0.3221), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4609,  0.8599, -0.2283), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2120,  0.7483, -0.3568), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1938,  0.4572, -0.2685), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3509,  0.4738, -0.3407), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6947,  0.7344, -0.0808), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5975,  0.4711, -0.1991), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6150,  0.4458, -0.0283), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1927,  0.8443,  0.2237), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4553,  0.8727,  0.3828), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5132,  0.7384,  0.4761), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2146,  0.7762,  0.5032), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3897,  0.4293,  0.5282), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1699,  0.4042,  0.4806), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6836,  0.7952,  0.2307), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7147,  0.4266,  0.1730), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6429,  0.4383,  0.3879), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0684,  0.8626,  0.0826), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1770,  0.7268,  0.0761), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0587,  0.7289,  0.3525), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0346,  0.4462,  0.3130), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1030,  0.4665,  0.2089), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0552,  0.7583, -0.2000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1137,  0.4863, -0.0614), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0098,  0.4674, -0.1829), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3741,  0.2482,  0.1951), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3726,  0.2829, -0.1233), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1403,  0.2148, -0.0128), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1338,  0.2854,  0.1157), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1164,  0.2776, -0.1432), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1941,  0.0032, -0.3311), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3794,  0.0021, -0.0030), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1899,  0.0028,  0.3323), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1889,  0.0051,  0.3314), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3811, -0.0022, -0.0011), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1903,  0.0045, -0.3292), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0062,  0.0158, -0.0017), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1923,  0.1490, -0.3488), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1987,  0.1497,  0.3373), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2004,  0.1516,  0.3386), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3888,  0.1427,  0.0106), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1879,  0.1512, -0.3405), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3329,  0.1872, -0.0136), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3761,  0.2391,  0.0719), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787,  0.2321, -0.1019), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.02, 0.00, 0.00)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(-0.03, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(-0.03, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(-0.03, 0.00, 0.00)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.4846,  0.7370,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2141,  0.7352, -0.0785), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4804,  0.7511, -0.2307), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3019,  0.6875, -0.2395), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3133,  0.4996, -0.2517), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5760,  0.6850, -0.0810), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5757,  0.4967, -0.1018), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2132,  0.7355,  0.2337), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.4801,  0.7638,  0.3844), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3017,  0.6955,  0.3981), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3127,  0.4654,  0.4245), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5855,  0.7052,  0.2359), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.6208,  0.4768,  0.2521), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0517,  0.7540,  0.0771), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0319,  0.6806,  0.2309), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0233,  0.4922,  0.2219), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0304,  0.6936, -0.0823), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0112,  0.5069, -0.0831), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3044,  0.6689,  0.0777), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3178,  0.4772,  0.0688), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1184,  0.4087,  0.0608), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.4038,  0.3936,  0.2207), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3984,  0.4288, -0.0974), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4728,  0.8455,  0.0702), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2201,  0.8443, -0.0725), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5326,  0.7233, -0.3221), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4801,  0.8599, -0.2288), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2322,  0.7456, -0.3569), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2154,  0.4552, -0.2659), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3720,  0.4724, -0.3391), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7148,  0.7374, -0.0808), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6194,  0.4725, -0.1984), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6380,  0.4481, -0.0276), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2129,  0.8442,  0.2235), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4754,  0.8727,  0.3828), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5332,  0.7383,  0.4761), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2345,  0.7765,  0.5032), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4117,  0.4311,  0.5289), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1918,  0.4040,  0.4830), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7036,  0.7952,  0.2307), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7353,  0.4267,  0.1737), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6638,  0.4390,  0.3885), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0480,  0.8626,  0.0823), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1571,  0.7271,  0.0761), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0388,  0.7290,  0.3525), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0571,  0.4472,  0.3147), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0817,  0.4651,  0.2119), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0354,  0.7562, -0.2000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0928,  0.4854, -0.0604), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0307,  0.4658, -0.1817), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3949,  0.2474,  0.1977), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4011,  0.2828, -0.1218), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1386,  0.2161, -0.0156), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1266,  0.2959,  0.1068), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1163,  0.2805, -0.1454), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1934, -0.0635,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020, -0.0654, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818, -0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1941,  0.0031, -0.3311), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3792,  0.0026, -0.0030), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1934, -0.0664,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000, -0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1901,  0.0032,  0.3322), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1889,  0.0052,  0.3313), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779, -0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3807, -0.0026, -0.0011), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1903,  0.0044, -0.3292), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0063,  0.0161, -0.0018), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1925,  0.1490, -0.3489), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2002,  0.1501,  0.3356), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2003,  0.1517,  0.3380), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3825,  0.1425,  0.0114), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1879,  0.1512, -0.3401), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3311,  0.1876, -0.0117), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3716,  0.2382,  0.0760), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3788,  0.2347, -0.0977), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1890, -0.2119,  0.1088), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3082, -0.0425,  0.3988), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4991, -0.0422,  0.0691), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1873, -0.0441, -0.4663), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0020, -0.2139, -0.2186), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1925, -0.0447, -0.4676), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3787, -0.2152, -0.2166), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5010, -0.0206, -0.2883), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4991, -0.0457,  0.0695), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3102, -0.0463,  0.3981), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1890, -0.2148,  0.1098), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0006, -0.2162,  0.4347), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0000, -0.0216,  0.5763), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3742, -0.2162, -0.2175), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4971, -0.0210, -0.2880), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.02, 0.00, 0.00)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(-0.01, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(-0.01, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(-0.01, 0.00, 0.00)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.5179,  0.7495,  0.0779), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2475,  0.7517, -0.0731), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5099,  0.7722, -0.2302), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3328,  0.7032, -0.2356), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3446,  0.5144, -0.2478), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.6062,  0.7004, -0.0829), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.6045,  0.5115, -0.1032), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2499,  0.7434,  0.2381), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5167,  0.7706,  0.3860), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3387,  0.7015,  0.4017), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3440,  0.4708,  0.4256), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.6191,  0.7117,  0.2353), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.6493,  0.4821,  0.2497), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0167,  0.7709,  0.0865), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0671,  0.6921,  0.2375), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0507,  0.5042,  0.2244), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0629,  0.7083, -0.0742), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0401,  0.5210, -0.0804), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3384,  0.6801,  0.0802), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3472,  0.4887,  0.0709), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1463,  0.4218,  0.0635), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.4316,  0.3996,  0.2203), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4284,  0.4397, -0.0946), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5062,  0.8581,  0.0743), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2535,  0.8605, -0.0658), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5612,  0.7486, -0.3231), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5071,  0.8808, -0.2237), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2597,  0.7587, -0.3523), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2464,  0.4708, -0.2634), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4033,  0.4880, -0.3356), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7457,  0.7509, -0.0837), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6463,  0.4871, -0.2007), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6694,  0.4644, -0.0304), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2502,  0.8524,  0.2298), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5115,  0.8795,  0.3844), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5715,  0.7452,  0.4766), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2728,  0.7820,  0.5080), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4422,  0.4323,  0.5295), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2214,  0.4123,  0.4833), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7396,  0.7986,  0.2307), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7625,  0.4303,  0.1703), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6932,  0.4435,  0.3857), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0087,  0.8792,  0.0922), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1229,  0.7476,  0.0862), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0001,  0.7398,  0.3615), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0812,  0.4561,  0.3167), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0547,  0.4800,  0.2109), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0039,  0.7723, -0.1908), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0642,  0.4972, -0.0605), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0622,  0.4824, -0.1795), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4168,  0.2543,  0.1910), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4299,  0.2915, -0.1096), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1380,  0.1847, -0.0177), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1078,  0.2715,  0.0972), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1062,  0.2577, -0.1414), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2171, -0.1236,  0.1166), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0154, -0.0879, -0.2359), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4079, -0.0998, -0.2324), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2147, -0.0527, -0.3535), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3891, -0.0270, -0.0115), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1708, -0.0486,  0.1110), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0083, -0.0480,  0.4503), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1543,  0.0544,  0.3196), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2137, -0.0560,  0.3410), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3732, -0.0666, -0.2312), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3753, -0.0338, -0.0013), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1761,  0.0144, -0.3229), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0348, -0.0248, -0.0060), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2161,  0.0902, -0.3898), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1152,  0.1947,  0.2922), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2667,  0.0819,  0.3371), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4297,  0.1004,  0.0255), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1642,  0.1576, -0.2869), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3275,  0.1552, -0.0156), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3680,  0.2044,  0.0728), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3731,  0.2066, -0.1003), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2219, -0.2712,  0.1072), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3159, -0.1270,  0.4200), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5215, -0.0214,  0.0548), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1775,  0.0160, -0.4701), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0109, -0.2340, -0.2382), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2142, -0.1186, -0.4853), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4307, -0.2453, -0.2311), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5287, -0.0496, -0.3005), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4723, -0.1230,  0.0648), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2834,  0.0668,  0.3891), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1600, -0.1946,  0.1424), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0343, -0.1867,  0.4769), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0207,  0.0082,  0.5860), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3799, -0.2112, -0.2597), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4949, -0.0152, -0.2963), type: .atom(.hydrogen)),
  ]
  
  // Move the tooltip and feedstock.
  for atomID in tooltipAtoms.indices {
    var atom = systemAtoms[atomID]
    atom.position += SIMD3(-0.02, 0.00, 0.00)
    systemAtoms[atomID] = atom
  }
  systemAtoms[tooltipAtoms.count + 0].position += SIMD3(-0.01, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 1].position += SIMD3(-0.01, 0.00, 0.00)
  systemAtoms[tooltipAtoms.count + 2].position += SIMD3(-0.01, 0.00, 0.00)
  
  systemAtoms = [
    Entity(position: SIMD3(-0.5376,  0.7489,  0.0780), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2673,  0.7509, -0.0731), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5298,  0.7718, -0.2301), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3528,  0.7027, -0.2356), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3645,  0.5139, -0.2478), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.6261,  0.6998, -0.0828), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.6242,  0.5109, -0.1031), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2698,  0.7428,  0.2381), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.5367,  0.7702,  0.3860), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3587,  0.7012,  0.4017), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3638,  0.4705,  0.4257), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.6390,  0.7112,  0.2353), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.6690,  0.4816,  0.2498), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0034,  0.7706,  0.0863), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0870,  0.6918,  0.2375), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0701,  0.5039,  0.2245), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.0827,  0.7075, -0.0743), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0596,  0.5202, -0.0805), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3581,  0.6793,  0.0802), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3666,  0.4878,  0.0709), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.1655,  0.4209,  0.0637), type: .atom(.germanium)),
    Entity(position: SIMD3(-0.4512,  0.3990,  0.2204), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.4482,  0.4390, -0.0945), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.5258,  0.8574,  0.0744), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2732,  0.8597, -0.0656), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5812,  0.7482, -0.3230), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5271,  0.8803, -0.2235), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2798,  0.7583, -0.3523), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2663,  0.4704, -0.2635), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4233,  0.4875, -0.3355), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7656,  0.7503, -0.0835), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6660,  0.4866, -0.2005), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.6892,  0.4638, -0.0302), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2702,  0.8518,  0.2296), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5316,  0.8791,  0.3843), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.5915,  0.7448,  0.4766), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2929,  0.7818,  0.5079), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4620,  0.4320,  0.5296), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2411,  0.4120,  0.4833), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7595,  0.7980,  0.2305), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7822,  0.4298,  0.1704), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.7129,  0.4430,  0.3857), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0118,  0.8788,  0.0918), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1029,  0.7477,  0.0862), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0200,  0.7397,  0.3614), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1006,  0.4559,  0.3168), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0353,  0.4799,  0.2111), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0161,  0.7715, -0.1909), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0448,  0.4965, -0.0609), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0818,  0.4815, -0.1796), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4370,  0.2536,  0.1914), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4502,  0.2909, -0.1095), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1343,  0.1856, -0.0182), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1022,  0.2734,  0.0954), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1025,  0.2582, -0.1421), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2161, -0.1231,  0.1163), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0147, -0.0882, -0.2362), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.4072, -0.0990, -0.2317), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2142, -0.0536, -0.3536), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3873, -0.0249, -0.0114), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1717, -0.0493,  0.1115), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0079, -0.0467,  0.4504), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1547,  0.0553,  0.3193), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2132, -0.0568,  0.3411), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3736, -0.0650, -0.2315), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3755, -0.0334, -0.0015), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1760,  0.0155, -0.3228), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0334, -0.0251, -0.0062), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.2153,  0.0890, -0.3912), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1152,  0.1951,  0.2909), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2683,  0.0803,  0.3382), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4283,  0.1013,  0.0259), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1634,  0.1584, -0.2859), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3240,  0.1569, -0.0155), type: .atom(.carbon)),
    Entity(position: SIMD3( 0.3640,  0.2063,  0.0731), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3695,  0.2087, -0.1000), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2216, -0.2707,  0.1061), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3143, -0.1298,  0.4197), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5195, -0.0182,  0.0551), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1773,  0.0180, -0.4700), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0123, -0.2342, -0.2387), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2140, -0.1207, -0.4848), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4302, -0.2445, -0.2291), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.5281, -0.0492, -0.2999), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4735, -0.1223,  0.0638), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.2836,  0.0688,  0.3890), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1609, -0.1950,  0.1437), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.0353, -0.1850,  0.4784), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0210,  0.0105,  0.5856), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.3809, -0.2093, -0.2609), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.4950, -0.0125, -0.2964), type: .atom(.hydrogen)),
  ]
  
  return systemAtoms
}
#endif


#if false
// TODO: Next, investigate the rearrangement reaction that connects the Si
// to the third carbon atom in the cage (across from it). We may need to swap
// that reaction out for a different one, and redo major portions of the build
// sequence.
func createGeometry() -> [Entity] {
  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  do {
    let cacheFolder =
    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
    let folder = URL(filePath: cacheFolder)
    let fileName = "Reaction 3l (2024-07-21 02_21_11 +0000).data"
    let file = folder.appending(
      component: fileName, directoryHint: .notDirectory)
    
    let data = try! Data(contentsOf: file)
    let frames = Serialization.decode(frames: data)
    siliconTooltip.surface = frames.last!
  }
  siliconTooltip.minimizeSurface()
  
  siliconTooltip.surface = [
    Entity(position: SIMD3( 0.1992,  0.0703,  0.1064), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0010,  0.0605, -0.2168), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3809,  0.0693, -0.2236), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1914, -0.0039, -0.3301), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3848, -0.0049, -0.0068), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1914,  0.0664,  0.1133), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0000,  0.0693,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1904, -0.0010,  0.3330), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1855, -0.0020,  0.3242), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3789,  0.0684, -0.2178), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3799, -0.0010,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1904, -0.0039, -0.3281), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0049, -0.0156,  0.0107), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1904, -0.1504, -0.3438), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4023, -0.1943, -0.0078), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2070, -0.1475,  0.3398), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1543, -0.1875,  0.2783), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3887, -0.1475,  0.0078), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1895, -0.1504, -0.3418), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4932, -0.2246, -0.0596), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3184, -0.2412, -0.0596), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4072, -0.2363,  0.0918), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2510, -0.2354,  0.2617), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1104, -0.2402,  0.3633), type: .atom(.hydrogen)),
//    Entity(position: SIMD3(-0.0781, -0.2910,  0.1660), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0449, -0.2236,  0.1211), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1143, -0.3242,  0.0400), type: .atom(.hydrogen)),
  ]
  siliconTooltip.minimizeSurface()
  
  siliconTooltip.surface = [
    Entity(position: SIMD3( 0.1973,  0.0693,  0.1074), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0010,  0.0615, -0.2168), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3809,  0.0684, -0.2227), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1914, -0.0029, -0.3301), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3838, -0.0039, -0.0059), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1895,  0.0654,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0020,  0.0693,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1914, -0.0029,  0.3320), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1855, -0.0010,  0.3262), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3789,  0.0684, -0.2178), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3799, -0.0010,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1904, -0.0029, -0.3281), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0039, -0.0215,  0.0088), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1904, -0.1494, -0.3428), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3975, -0.1934, -0.0068), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2070, -0.1484,  0.3398), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1592, -0.1875,  0.2871), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3887, -0.1475,  0.0078), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1885, -0.1494, -0.3408), type: .atom(.hydrogen)),
    
//    Entity(position: SIMD3( 0.4873, -0.2256, -0.0586), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3135, -0.2393, -0.0566), type: .atom(.hydrogen)),
    
    Entity(position: SIMD3( 0.4033, -0.2344,  0.0938), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2559, -0.2334,  0.2656), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1221, -0.2393,  0.3750), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0410, -0.2197,  0.1357), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0986, -0.3389,  0.0693), type: .atom(.hydrogen)),
  ]
  siliconTooltip.minimizeSurface()
  
  siliconTooltip.surface = [
    Entity(position: SIMD3( 0.1943,  0.0762,  0.1123), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0039,  0.0605, -0.2168), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3818,  0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1943, -0.0029, -0.3301), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3760, -0.0039, -0.0010), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1865,  0.0615,  0.1104), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0010,  0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1904, -0.0020,  0.3320), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1865, -0.0029,  0.3262), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779,  0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3799, -0.0020,  0.0000), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1885, -0.0029, -0.3281), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0117, -0.0215,  0.0068), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1914, -0.1494, -0.3447), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3203, -0.1885,  0.0098), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2041, -0.1484,  0.3379), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1680, -0.1885,  0.2734), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3906, -0.1484,  0.0078), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1875, -0.1494, -0.3408), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3252, -0.2344, -0.0889), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3906, -0.2441,  0.0713), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2559, -0.2441,  0.3047), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0850, -0.2334,  0.3271), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1416, -0.2148,  0.0830), type: .atom(.silicon)),
//    Entity(position: SIMD3( 0.1006, -0.3545,  0.0596), type: .atom(.hydrogen)),
  ]
  siliconTooltip.minimizeSurface()
  
  siliconTooltip.surface = [
    Entity(position: SIMD3( 0.1924,  0.0742,  0.1113), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0020,  0.0615, -0.2168), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3809,  0.0674, -0.2197), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1924, -0.0029, -0.3301), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.3770, -0.0029, -0.0010), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1875,  0.0625,  0.1094), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.0020,  0.0684,  0.4385), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1904, -0.0020,  0.3301), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1865, -0.0020,  0.3271), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3779,  0.0684, -0.2188), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.3799, -0.0020, -0.0010), type: .atom(.silicon)),
    Entity(position: SIMD3(-0.1895, -0.0029, -0.3281), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.0078, -0.0254,  0.0049), type: .atom(.silicon)),
    Entity(position: SIMD3( 0.1904, -0.1494, -0.3438), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3281, -0.1895,  0.0146), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.2041, -0.1484,  0.3359), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1768, -0.1895,  0.2773), type: .atom(.carbon)),
    Entity(position: SIMD3(-0.3896, -0.1475,  0.0078), type: .atom(.hydrogen)),
    Entity(position: SIMD3(-0.1875, -0.1494, -0.3408), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.3369, -0.2373, -0.0830), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.4023, -0.2402,  0.0781), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.2676, -0.2402,  0.3096), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.0957, -0.2373,  0.3330), type: .atom(.hydrogen)),
    Entity(position: SIMD3( 0.1504, -0.2207,  0.0869), type: .atom(.silicon)),
  ]
  
//  print()
//  print(try! AtomCoder.encode(siliconTooltip.surface, encoding: .hdl))
//  print()
  return siliconTooltip.surface
}
#endif

#if false
// Workspace for building onto the silicon tooltip.
//
// To be archived in Silicon111BuildSequence+Workspace3.
//
// HAbst | z=0.70, Ge-C2  | Reaction 1n (2024-07-28 12_59_19 +0000).data
// HDon  | z=0.45, C3Si   | Reaction 2n (2024-07-28 13_04_54 +0000).data
//       | z=0.45, C2SiSi |
// HAbst | z=0.70, Ge-C2  | Reaction 3n (2024-07-28 13_17_50 +0000).data
// SiH3  | z=0.50, Si3Ge  | Reaction 4n (2024-07-28 13_28_23 +0000).data
//       | z=0.50, CSi2Ge |
//       | z=0.50, CSi2Si |
// HAbst | z=0.65, Ge-C2  | Reaction 5n (2024-07-28 13_44_43 +0000).data
// HAbst | z=0.60, C3Si   | Reaction 6n (2024-07-28 13_55_06 +0000).data
//       | z=0.55, C2SiSi | Reaction 6n (2024-07-28 14_09_40 +0000).data
//
func createGeometry() -> [[Entity]] {
  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  siliconTooltip.surface[19] = Entity(
    position: SIMD3(0.00, -0.20, 0.00), type: .atom(.chlorine))
  
  #if false
  for atomID in siliconTooltip.surface.indices {
    var atom = siliconTooltip.surface[atomID]
    guard atom.atomicNumber == 1 else {
      continue
    }
    
    atom.atomicNumber = 6
    atom.position.y += -0.050
    atom.position.x *= 0.90
    atom.position.z *= 0.90
    siliconTooltip.surface[atomID] = atom
  }
  siliconTooltip.surface += [
    Entity(position: SIMD3(0.00, -0.33, 0.00), type: .atom(.silicon)),
  ]
  for sideID in 0..<3 {
    let angle = Float(sideID) * 120 * .pi / 180
    let rotation = Quaternion(angle: angle, axis: SIMD3(0.00, 1.00, 0.00))
    
    let rawHydrogens: [Entity] = [
      Entity(position: SIMD3(0.30, -0.30, 0.05), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.30, -0.30, 0.05), type: .atom(.hydrogen)),
    ]
    for rawHydrogen in rawHydrogens {
      var hydrogen = rawHydrogen
      hydrogen.position = rotation.act(on: hydrogen.position)
      siliconTooltip.surface.append(hydrogen)
    }
  }
  siliconTooltip.surface += [
    Entity(position: SIMD3(0.00, -0.50, 0.00), type: .atom(.chlorine))
  ]
  #endif
  
//  do {
//    let cacheFolder =
//    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
//    let folder = URL(filePath: cacheFolder)
//    let fileName = "Reaction 3n (2024-07-28 13_17_50 +0000).data"
//    let file = folder.appending(
//      component: fileName, directoryHint: .notDirectory)
//
//    let data = try! Data(contentsOf: file)
//    let frames = Serialization.decode(frames: data)
//    siliconTooltip.surface = frames.last!
//  }
  siliconTooltip.minimizeSurface()
  
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .methylene
  cageTooltipDesc.frameworkType = .adamantasilane(.silicon)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  replaceApex(tooltip: &cageTooltip)
  try! cageTooltip.loadCachedValue()
  
  var reactionDesc = Silicon111ReactionDescriptor()
  reactionDesc.siliconTooltip = siliconTooltip
  reactionDesc.cageTooltip = cageTooltip
  reactionDesc.frameBudget = 4 * 60
  reactionDesc.nearOffset = SIMD3(0.05, 0.50, 0.05)
  reactionDesc.farOffset = reactionDesc.nearOffset! + SIMD3(0.00, 0.20, 0.00)
  
  var reaction = Silicon111Reaction(descriptor: reactionDesc)
  
  var output: [[Entity]] = []
  output.append(createFrame(reaction: reaction))
  
  
  // Run molecular dynamics.
  do {
    for _ in 0..<reaction.frameBudget {
      try reaction.step()
      output.append(createFrame(reaction: reaction))
    }
    output.append(try reaction.createProduct(
      type: .rearrangement
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
//        component: "Reaction 6n (\(key)).data", directoryHint: .notDirectory)
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

func replaceApex(tooltip: inout CageTooltip) {
  var carbonID: Int = .zero
  for atomID in tooltip.apex.indices {
    var atom = tooltip.apex[atomID]
    if atom.position.y < -0.020,
       atom.atomicNumber == 6 || atom.atomicNumber == 14 {
      
      if carbonID == 0 || carbonID == 1 || carbonID == 2 {
        atom.atomicNumber = 6
      } else {
        atom.atomicNumber = 14
      }
      carbonID += 1
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
#endif
