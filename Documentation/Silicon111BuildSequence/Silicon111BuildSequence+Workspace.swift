import Foundation
import MolecularRenderer
import HDL
import MM4
import Numerics
import QuartzCore
import xTB

import CairoGraphics
import GIF

// Workspace for rendering to GIF.
func renderGIF(renderer: Renderer) {
  render(renderer: renderer, frameRange: 0 * 60..<30 * 60)
  render(renderer: renderer, frameRange: 30 * 60..<60 * 60)
  render(renderer: renderer, frameRange: 60 * 60..<90 * 60)
  render(renderer: renderer, frameRange: 90 * 60..<120 * 60)
  
  exit(0)
}

func render(renderer: Renderer, frameRange: Range<Int>) {
  // Render to GIF.
  let renderSemaphore: DispatchSemaphore = .init(value: 0)
  let imageHeight: Int = 720
  let imageWidth: Int = 1280
  var gif = GIF(width: imageWidth, height: imageHeight)
  
  // Iterate over the frames.
  let checkpoint0 = Date()
  for frameID in frameRange {
    print("rendering frame:", frameID)
    
    // Set the time.
    let time = MRTime(absolute: frameID, relative: 1, frameRate: 60)
    renderer.renderingEngine.setTime(time)
    
    // Set the camera.
    let camera = renderer.animationProvider.camera(time: time)
    renderer.renderingEngine.setCamera(camera)
    renderer.renderingEngine.setLights([
      MRLight(
        origin: camera.position,
        diffusePower: 1, specularPower: 1)
    ])
    
    // Dispatch work to the GPU.
    var pixelBuffer = [UInt8](
      repeating: .zero, count: 4 * imageWidth * imageHeight)
    renderer.renderingEngine.render { pixels in
      for pixelID in pixelBuffer.indices {
        pixelBuffer[pixelID] = pixels[pixelID]
      }
      renderSemaphore.signal()
    }
    
    // Synchronize with the GPU.
    renderSemaphore.wait()
    
    // Create a Cairo image.
    let image = try! CairoImage(width: imageWidth, height: imageHeight)
    for y in 0..<imageHeight {
      for x in 0..<imageWidth {
        let address = y * imageWidth + x
        let b = pixelBuffer[4 * address + 0]
        let g = pixelBuffer[4 * address + 1]
        let r = pixelBuffer[4 * address + 2]
        let a = pixelBuffer[4 * address + 3]
        
        let pixelVector8 = SIMD4<UInt8>(b, g, r, a)
        let pixelScalar = unsafeBitCast(pixelVector8, to: UInt32.self)
        let color = Color(argb: pixelScalar)
        image[y, x] = color
      }
    }
    
    // Render the captions.
    let captionsDesc = renderer.animationProvider.captions(time: time)
    Monocraft.drawCaptions(image: image, descriptor: captionsDesc)
    
    // Append to the GIF.
    let quantization = OctreeQuantization(fromImage: image)
    let frame = Frame(
      image: image,
      delayTime: 2, // 50 FPS
      localQuantization: quantization)
    gif.frames.append(frame)
  }
  
  let checkpoint1 = Date()
  
  print("encoding GIF")
  let data = try! gif.encoded()
  print("encoded size")
  print(String(format: "%.1f", Float(data.count) / 1e6), "MB")
  
  let checkpoint2 = Date()
  
  print("saving to file")
  let path = "/Users/philipturner/Desktop/Render\(frameRange.lowerBound)_\(frameRange.upperBound).gif"
  let url = URL(fileURLWithPath: path)
  guard FileManager.default.createFile(atPath: path, contents: data) else {
    fatalError("Could not create file at \(url.relativeString).")
  }
  
  let checkpoint3 = Date()
  
  print()
  print("latency overview:")
  print("- checkpoint 0 -> 1 | \(checkpoint1.timeIntervalSince(checkpoint0))")
  print("- checkpoint 1 -> 2 | \(checkpoint2.timeIntervalSince(checkpoint1))")
  print("- checkpoint 2 -> 3 | \(checkpoint3.timeIntervalSince(checkpoint2))")
}



#if false
// Workspace for building onto the silicon tooltip.
func createGeometry() -> [[Entity]] {
  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  do {
    let cacheFolder =
    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
    let folder = URL(filePath: cacheFolder)
    let fileName = "Reaction 48a (2024-06-30 19_40_10 +0000).data"
    let file = folder.appending(
      component: fileName, directoryHint: .notDirectory)
    
    let data = try! Data(contentsOf: file)
    let frames = Serialization.decode(frames: data)
    siliconTooltip.surface = frames.last!
  }
  siliconTooltip.minimizeSurface()
  
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .methane
  cageTooltipDesc.frameworkType = .adamantane(.carbon)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  try! cageTooltip.loadCachedValue()
  
  var reactionDesc = Silicon111ReactionDescriptor()
  reactionDesc.siliconTooltip = siliconTooltip
  reactionDesc.cageTooltip = cageTooltip
  reactionDesc.frameBudget = 8 * 60
  reactionDesc.nearOffset = SIMD3(0.00, 1.20, 0.10)
  reactionDesc.farOffset = reactionDesc.nearOffset! + SIMD3(0.00, 0.40, 0.00)
  
  var reaction = Silicon111Reaction(descriptor: reactionDesc)
  reaction.calculator.electronicTemperature = 1500
  reaction.calculator.maximumIterations = 75
  
  var output: [[Entity]] = []
  output.append(createFrame(reaction: reaction))
  return output
  
  // Run molecular dynamics.
  do {
    for _ in 0..<reaction.frameBudget {
      try reaction.step()
      output.append(createFrame(reaction: reaction))
    }
    output.append(reaction.createProduct(
      type: .donation([.carbon, .carbon])
    ))
    
    // Serialize the product, so the next reaction will be initialized with it.
//    do {
//      let cacheFolder =
//      "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
//      let folder = URL(filePath: cacheFolder)
//      let key = Serialization.fileSafeString("\(Date())")
//      let file = folder.appending(
//        component: "Reaction 49a (\(key)).data", directoryHint: .notDirectory)
//      let data = Serialization.encode(frames: output)
//      try! data.write(to: file, options: .atomic)
//    }
  } catch {
    
  }
  
  return output
}

func createFrame(reaction: Silicon111Reaction) -> [Entity] {
  var output: [Entity] = []
  let siliconTooltip = reaction.createSiliconTooltip()
  output += siliconTooltip.surface
  output += siliconTooltip.anchors
  
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

// Workspace for building onto the silicon tooltip.
//
// HAbst    - Reaction 1a (2024-06-25 23_56_34 +0000).data
// SiH3     - Reaction 2a (2024-06-26 00_03_03 +0000).data
// HAbst    - Reaction 3a (2024-06-26 00_38_20 +0000).data
// SiH3     - Reaction 4a (2024-06-26 00_43_36 +0000).data
// HAbst    - Reaction 5a (2024-06-26 01_01_13 +0000).data
// SiH3     - Reaction 6a (2024-06-26 01_04_21 +0000).data
// HAbst    - Reaction 7a (2024-06-26 01_06_41 +0000).data
// SiH3     - Reaction 8a (2024-06-26 01_08_45 +0000).data
// HAbst    - Reaction 9a (2024-06-29 23_01_06 +0000).data
// HAbst    - Reaction 10a (2024-06-30 00_23_11 +0000).data
// SiH:     - Reaction 11a (2024-06-30 00_40_19 +0000).data
// HDon     - Reaction 12a (2024-06-30 00_50_04 +0000).data
// Rearr.   - Reaction 13a (2024-06-30 00_59_18 +0000).data
// HAbst    - Reaction 14a (2024-06-30 01_18_26 +0000).data
// SiH3     - Reaction 15a (2024-06-30 01_33_14 +0000).data
// HAbst    - Reaction 16a (2024-06-30 01_36_45 +0000).data
// HAbst    - Reaction 17a (2024-06-30 01_42_27 +0000).data
// SiH3Abst - Reaction 18a (2024-06-30 02_15_12 +0000).data
// HDon     - Reaction 19a (2024-06-30 02_21_49 +0000).data
// HAbst    - Reaction 20a (2024-06-30 04_52_38 +0000).data
// SiH3     - Reaction 21a (2024-06-30 04_57_25 +0000).data
// HAbst    - Reaction 22a (2024-06-30 05_02_19 +0000).data
// HAbst    - Reaction 23a (2024-06-30 05_44_01 +0000).data
// Rearr.   - Reaction 24a (2024-06-30 11_56_44 +0000).data
// HAbst    - Reaction 25b (2024-07-06 13_55_27 +0000).data (acetylene)
// HAbst    - Reaction 26b (2024-07-06 14_03_15 +0000).data (adamantyl)
// SiH3     - Reaction 27b (2024-07-06 14_20_16 +0000).data [netSpin = 1.00]
// SiH3     - Reaction 28b (2024-07-06 14_30_15 +0000).data
// HAbst    - Reaction 29b (2024-07-06 14_39_16 +0000).data (acetylene)
// HAbst    - Reaction 30b (2024-07-06 14_45_02 +0000).data (adamantyl)
// HAbst    - Reaction 31b (2024-07-06 15_05_20 +0000).data (acetylene)
// Rearr.   - Reaction 32b (2024-07-06 15_11_41 +0000).data
// HDon     - Reaction 33b (2024-07-06 15_41_17 +0000).data
// HAbst    - Reaction 34b (2024-07-06 21_11_03 +0000).data (acetylene)
// HAbst    - Reaction 35b (2024-07-06 22_06_06 +0000).data [netSpin = 1.00]
// SiH:     - Reaction 36b (2024-07-07 13_28_51 +0000).data (HHHHFF, 80-140°)
// HAbst    - Reaction 37b (2024-07-07 14_36_02 +0000).data (acetylene)
//
// HAbst    - Reaction 36c (2024-07-07 14_53_53 +0000).data (adamantyl)
// SiH3     - Reaction 37c (2024-07-07 14_58_23 +0000).data
// HAbst    - Reaction 38c (2024-07-07 15_22_05 +0000).data (acetylene)
// HAbst    - Reaction 39c (2024-07-07 15_58_03 +0000).data (adamantyl)
// HAbst    - Reaction 40c (2024-07-07 16_23_22 +0000).data (acetylene)
// Rearr.   - Reaction 41c (2024-07-07 16_37_11 +0000).data
// SiH3     - Reaction 42c (2024-07-07 16_52_45 +0000).data
//
// SiH:     - Reaction 38d (2024-07-07 17_18_48 +0000).data (HHHHFF, 120°)
// HAbst    - Reaction 39d (2024-07-07 17_23_39 +0000).data (acetylene)
// HAbst    - Reaction 40d (2024-07-07 17_36_00 +0000).data (acetylene)
// Rearr.   - Reaction 41d (2024-07-07 17_43_21 +0000).data
// HDon     - Reaction 42d (2024-07-07 17_49_31 +0000).data
//
func createGeometry() -> [[Entity]] {
  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  do {
    let cacheFolder =
    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
    let folder = URL(filePath: cacheFolder)
    let fileName = "Reaction 42d (2024-07-07 17_49_31 +0000).data"
    let file = folder.appending(
      component: fileName, directoryHint: .notDirectory)
    
    let data = try! Data(contentsOf: file)
    let frames = Serialization.decode(frames: data)
    siliconTooltip.surface = frames.last!
  }
  siliconTooltip.minimizeSurface()
  
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .hydrogen
  cageTooltipDesc.frameworkType = .atrane(.tin)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  try! cageTooltip.loadCachedValue()
  
  var reactionDesc = Silicon111ReactionDescriptor()
  reactionDesc.siliconTooltip = siliconTooltip
  reactionDesc.cageTooltip = cageTooltip
  reactionDesc.frameBudget = 6 * 60
  reactionDesc.nearOffset = SIMD3(0.00, 1.00, -0.20)
  reactionDesc.farOffset = reactionDesc.nearOffset! // + SIMD3(0.00, 0.20, 0.00)
  
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
      type: .donation([.hydrogen])
    ))
    
    // Serialize the product, so the next reaction will be initialized with it.
//    do {
//      let cacheFolder =
//      "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
//      let folder = URL(filePath: cacheFolder)
//      let key = Serialization.fileSafeString("\(Date())")
//      let file = folder.appending(
//        component: "Reaction 42d (\(key)).data", directoryHint: .notDirectory)
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
  output += siliconTooltip.anchors
  
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

// ======================================================================== //
// These ideas are only valid if the overhang primitive works.
// ======================================================================== //
//
// Compile a large block of hexagonal silicon, take a picture so you can
// sketch the build sequence on the iPad.
// - Fully terminated lattice. (for 1st half cell)
// - Sliced open, halfway through a unit cell. (for 2nd half cell)
//
// Time to put quantum mechanical simulation in the past (except to
// energy-minimize some intermediate structures). Move on to building the
// first atomically precise products and engineering detachment points.
// - Taking a break from animations indefinitely. To accelerate
//   time-to-solution.
// - Omit any details that are lower-level than the primitives required to
//   build hexagonal silicon lattices.
//   - Retaining the requirement that each part's build sequence is specified,
//     at the level of primitives.
//
// Only return to QM simulations / individual reactions level of detail:
// - Designing the AFM tip reconstruction protocol.
//   - Unless you can engineer parts to fracture along (111).
//   - Unless it is valid to assume that crashing the tip into the surface
//     will eventually create (111) surfaces, and this is not a bottleneck.
// - If overhangs or additional primitives are required.
//
// --- Find some justification for skipping the effort of designing a tip
//     reconstruction protocol. Based on that justification, what limitations
//     should I assume going forward? Will all parts have one completely
//     random, atomically imprecise side?
//     - Study part detachment simulations more thoroughly. Does (111)
//       fracture more cleanly than (110)?
//     - Does the current set of primitives permit (slight) overhangs to
//       enable tip reconstruction by building over the breakage site?
//
func createGeometry() -> [Entity] {
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 5 * h + 5 * h2k + 5 * l }
    Material { .elemental(.silicon) }
  }
  return lattice.atoms
}

// Rearr.   - Reaction 1e (2024-07-07 22_51_48 +0000).data
// HAbst    - Reaction 2e (2024-07-07 23_12_20 +0000).data (acetylene)
// SiH3     - Reaction 3e (2024-07-07 23_26_58 +0000).data
// HAbst    - Reaction 4e (2024-07-07 23_33_03 +0000).data (acetylene)
// SiH3     - Reaction 5e (2024-07-07 23_37_07 +0000).data
// HAbst    - Reaction 6e (2024-07-07 23_56_19 +0000).data (acetylene)
// HAbst    - Reaction 7e (2024-07-08 01_02_35 +0000).data [netSpin = 1.00]
// SiH:     - Reaction 8e (2024-07-08 01_21_40 +0000).data (HHHHFF, 180°)
// Rearr.   - Reaction 9e (2024-07-08 01_29_46 +0000).data
// HDon     - Reaction 10e (2024-07-08 01_36_46 +0000).data

// Workspace for building overhangs.
//
// HAbst    - Reaction 1f (2024-07-12 01_02_05 +0000).data (acetylene)
// SiH3     - Reaction 2f (2024-07-12 01_35_44 +0000).data
// HAbst    - Reaction 3f (2024-07-12 02_18_55 +0000).data (acetylene)
// HAbst    - Reaction 4f (2024-07-12 02_34_05 +0000).data (acetylene, T)
// SiH:     - Reaction 5f (2024-07-12 03_01_08 +0000).data (HHHHFF, 180°)
// HDon     - Reaction 6f (2024-07-12 03_13_07 +0000).data
// SiH:     - Reaction 7f (2024-07-12 04_05_57 +0000).data (HHHHFF, 180°)
// HDon     - Reaction 8f (2024-07-12 04_13_19 +0000).data
// HAbst    - Reaction 9f (2024-07-12 04_51_40 +0000).data (acetylene)
// HAbst    - Reaction 10f (2024-07-12 04_56_26 +0000).data (acetylene, T)
// SiH:     - Reaction 11f (2024-07-12 05_04_28 +0000).data (HHHHFF, 180°)
// HDon     - Reaction 12f (2024-07-12 05_08_12 +0000).data
// SiH:     - Reaction 13f (2024-07-12 05_20_15 +0000).data (HHHHFF, 180°)
// HDon     - Reaction 14f (2024-07-12 05_39_12 +0000).data
//
// Twitter: "Completion of an overhang, where the (110) surface is manufactured
// at an obtuse angle to the main (111) surface. This makes it possible to
// extrude logic rods from cubic-phase silicon, oriented vertically (like
// icicles).
//
// ## Spin State of 5f
//
// Singlet Branch
//   -956.50 eV starting structure
//   partial charges:
//     14:  0.45 ->  0.26
//      1: -0.04 -> -0.04
//     50:  0.11 ->  0.15
//   minor damage occurs, but heals after the reaction
//   reaction ends in success (-1721.49 eV)
// Triplet Branch
//   -956.36 eV starting structure
//   reaction ends in damage (-1719.74 eV)
//
// ## Operating Range of 7f
//
// Only examining the 180° variant for simplicity.
//
// SIMD3(-0.05, 0.70, -0.30) - fail
// SIMD3(-0.05, 0.68, -0.30) - fail
// SIMD3(-0.05, 0.67, -0.30) - fail
// SIMD3(-0.05, 0.66, -0.30) - success
// SIMD3(-0.05, 0.65, -0.30) - success (720 frames)
// SIMD3(-0.05, 0.63, -0.30) - success
// SIMD3(-0.05, 0.61, -0.30) - success
// SIMD3(-0.05, 0.59, -0.30) - success
// SIMD3(-0.05, 0.57, -0.30) - success
// SIMD3(-0.05, 0.55, -0.30) - success
//
// SIMD3(-0.05, 0.65, -0.35) - fail
// SIMD3(-0.05, 0.65, -0.33) - success
// SIMD3(-0.05, 0.65, -0.27) - success
// SIMD3(-0.05, 0.65, -0.25) - damage
//
// SIMD3(-0.05, 0.60, -0.35) - fail
// SIMD3(-0.05, 0.60, -0.33) - success
// SIMD3(-0.05, 0.60, -0.27) - success
// SIMD3(-0.05, 0.60, -0.25) - damage
//
// SIMD3(-0.15, 0.65, -0.30) - damage
// SIMD3(-0.13, 0.65, -0.30) - success
// SIMD3(-0.11, 0.65, -0.30) - success
// SIMD3(-0.09, 0.65, -0.30) - success
// SIMD3(-0.07, 0.65, -0.30) - success
// SIMD3(-0.03, 0.65, -0.30) - success
// SIMD3(-0.02, 0.65, -0.30) - success
// SIMD3(-0.01, 0.65, -0.30) - fail
//
// SIMD3(-0.13, 0.60, -0.30) - damage
// SIMD3(-0.11, 0.60, -0.30) - success
// SIMD3(-0.02, 0.60, -0.30) - success
// SIMD3(-0.01, 0.60, -0.30) - success
// SIMD3( 0.01, 0.60, -0.30) - success
// SIMD3( 0.03, 0.60, -0.30) - damage
//
#if false
// Workspace for building overhangs.
func createGeometry() -> [[Entity]] {
  var siliconTooltip = Silicon111Tooltip(type: .modelO)
  do {
    let cacheFolder =
    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
    let folder = URL(filePath: cacheFolder)
    let fileName = "Reaction 13f (2024-07-12 05_20_15 +0000).data"
    let file = folder.appending(
      component: fileName, directoryHint: .notDirectory)
    
    let data = try! Data(contentsOf: file)
    let frames = Serialization.decode(frames: data)
    siliconTooltip.surface = frames.last!
  }
  siliconTooltip.minimizeSurface()
  
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .hydrogen
  cageTooltipDesc.frameworkType = .atrane(.tin)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
  try! cageTooltip.loadCachedValue()
  
  var reactionDesc = Silicon111ReactionDescriptor()
  reactionDesc.siliconTooltip = siliconTooltip
  reactionDesc.cageTooltip = cageTooltip
  reactionDesc.frameBudget = 9 * 60
  reactionDesc.nearOffset = SIMD3(0.25, 0.70, -0.35)
  reactionDesc.farOffset = reactionDesc.nearOffset! + SIMD3(0.00, 0.30, 0.00)
  
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
      type: .donation([.hydrogen])
    ))
    
    // Serialize the product, so the next reaction will be initialized with it.
    do {
      let cacheFolder =
      "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
      let folder = URL(filePath: cacheFolder)
      let key = Serialization.fileSafeString("\(Date())")
      let file = folder.appending(
        component: "Reaction 14f (\(key)).data", directoryHint: .notDirectory)
      let data = Serialization.encode(frames: output)
      try! data.write(to: file, options: .atomic)
    }
  } catch {
    print("[ERROR]", error.localizedDescription)
  }
  
  return output
}

func createFrame(reaction: Silicon111Reaction) -> [Entity] {
  var output: [Entity] = []
  let siliconTooltip = reaction.createSiliconTooltip()
  output += siliconTooltip.surface
  
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

// Bromine abstraction: Y = +0.55 nm
// SiBr3 donation: Y = +0.45 nm
//
// BrAbst - Reaction 1g (2024-07-15 00_02_14 +0000).data
// SiBr3  - Reaction 2g (2024-07-15 00_19_09 +0000).data

import Foundation
import MolecularRenderer
import HDL
import MM4
import Numerics
import QuartzCore
import xTB

#if true
// Workspace for building onto the silicon surface.
//
// Validated:
// SiBr3 Deposition: N(O)(O)(O)Pb* -> (CH2)(CH2)(CF2)Sn* -> Si3Si*
// Br Abstraction (Inverted): Sn-SiBr3 -> C3Si-Br
// Br Abstraction (Inverted): Sn-SiBr2* -> C3Si-Br
// SiHBr2 Deposition: N(O)(O)(O)Pb* -> (CH2)(CH2)(CF2)Sn* -> Si3Si*
// SiH2Br Deposition: N(O)(O)(O)Pb* -> (CH2)(CH2)(CF2)Sn* -> Si3Si*
// H Abstraction (Inverted): Sn-SiH2Br -> C-C2-H
// Br Abstraction (Inverted): Sn-SiHBr* -> C3Si-Br
//
// Testing:
// C2 Deposition: N(CF2)(CF2)(CF2)Pb* -> (CH2)(CH2)(CF2)Sn* -> Si3Si*
//
// Failed:
// SiBr: Deposition (Conventional): Si-BrCl: -> Si3SiH
// SiH: Deposition (Conventional): Si-BrH: -> Si3SiH
// Br Abstraction (Inverted): Sn-SiHBr2 -> C3Si-Br
// Br Abstraction (Inverted): Sn-SiHBr2 -> C-C2-Br
// H Abstraction (Inverted): Sn-SiH2Br -> C3Si-H
//
// Neither silene deposition worked, but it's probably because it's not the
// right geometry. We may need a 5-ring that's about to become a 6-ring.
//
// The above reactions outline a reliable pathway for synthesizing each type
// of silicon diradical on tin radical tool - SiH: and SiBr:. These pathways
// have a lower error rate than the previous ones, which were based entirely
// on acetylene and positional constraint. However, they appear to create
// products whose orientation is unknown.
//
// SiBr3  - Reaction 1h (2024-07-16 03_07_54 +0000).data
// BrAbst - Reaction 2h (2024-07-16 03_57_02 +0000).data (SiRad)
// BrAbst - Reaction 3h (2024-07-16 04_09_54 +0000).data (SiRad)
// SiH2Br - Reaction 1g (2024-07-16 05_05_07 +0000).data
// HAbst  - Reaction 2g (2024-07-16 05_21_07 +0000).data (acetylene)
// BrAbst - Reaction 3g (2024-07-16 05_36_26 +0000).data (SiRad)
//
// ## Thermodynamic Cascade: Sn -> Ge -> Si
//
// S3Sn-SiH3  -> Se3Ge-SiH3
// Se3Ge-SiH3 -> Si3Si-SiH3
//
// SiH3     - Reaction 1i (2024-07-17 02_42_12 +0000).data
// SiH3Abst - Reaction 2i (2024-07-17 02_56_31 +0000).data
//
// S3Sn-SiH2Br  -> Se3Ge-SiH2Br
// Se3Ge-SiH2Br -> Se3Ge-SiHBr*
// Se3Ge-SiHBr* -> Se3Ge-SiH:
// Se3Ge-SiH:   -> H2Si-SiH*-SiH2
//
// SiH2Br - Reaction 1j (2024-07-17 02_49_03 +0000).data
// HAbst  - Reaction 2j (2024-07-17 03_06_17 +0000).data
// BrAbst - Reaction 3j (2024-07-17 03_12_51 +0000).data
// HAbst  - Reaction 4j (2024-07-17 03_43_36 +0000).data
//
// Need to examine the diradical addition with greater scrutiny.
//
// ## GeCl2 Tooltip
//
// The reactions are getting very expensive to simulate. I'm cutting some
// corners when simulating them.
//
// S3Sn-SiH3        -> (GeCl2)3Ge-SiH3 | loose validation that this works
// (GeCl2)3Ge-SiH3  -> Si3Si-SiH3      | loose validation that this works
//
// SiH2Br - Reaction 1j (2024-07-17 12_28_01 +0000).data
// HAbst  - Reaction 2j (2024-07-17 12_35_27 +0000).data
// BrAbst - Reaction 3j (2024-07-17 12_43_33 +0000).data
//
func createGeometry() -> [[Entity]] {
  var siliconTooltip = Silicon111Tooltip(type: .modelA)
//  var siliconTooltip = Silicon111Tooltip(type: .modelS)
  
  // Add a tin radical tooltip to the surface.
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
//  do {
//    let cacheFolder =
//    "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
//    let folder = URL(filePath: cacheFolder)
//    // let fileName = "Reaction 10a (2024-06-30 00_23_11 +0000).data"
//    let fileName = "Reaction 3j (2024-07-17 12_43_33 +0000).data"
//    let file = folder.appending(
//      component: fileName, directoryHint: .notDirectory)
//
//    let data = try! Data(contentsOf: file)
//    let frames = Serialization.decode(frames: data)
//    siliconTooltip.surface = frames.last!
//  }
  siliconTooltip.minimizeSurface()
  
  var cageTooltipDesc = CageTooltipDescriptor()
  cageTooltipDesc.feedstockType = .dihalogenide(.silicon, .hydrogen, .bromine)
  cageTooltipDesc.frameworkType = .atrane(.tin)
  var cageTooltip = CageTooltip(descriptor: cageTooltipDesc)
//  replaceApex(tooltip: &cageTooltip)
  try! cageTooltip.loadCachedValue()
  
  var reactionDesc = Silicon111ReactionDescriptor()
  reactionDesc.siliconTooltip = siliconTooltip
  reactionDesc.cageTooltip = cageTooltip
  reactionDesc.frameBudget = 4 * 60
  reactionDesc.nearOffset = SIMD3(-0.20, 0.80, 0.00)
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
      type: .donation([.bromine])
    ))
    
    // Serialize the product, so the next reaction will be initialized with it.
    do {
      let cacheFolder =
      "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
      let folder = URL(filePath: cacheFolder)
      let key = Serialization.fileSafeString("\(Date())")
      let file = folder.appending(
        component: "Reaction 3j (\(key)).data", directoryHint: .notDirectory)
      let data = Serialization.encode(frames: output)
      try! data.write(to: file, options: .atomic)
    }
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
      atom.atomicNumber = 16
    }
    tooltip.apex[atomID] = atom
  }
  
  // Ensure the (now corrupted) apex-framework boundary is never accessed.
  tooltip.apexFrameworkBoundary = [SIMD2(99000, 999000)]
  
  // Shrink the list of apex atoms.
  var hydrogenCursor = 0
  var removedHydrogens: [UInt32] = []
  for atomID in tooltip.apex.indices {
    let atom = tooltip.apex[atomID]
    if atom.atomicNumber == 1 {
      removedHydrogens.append(UInt32(atomID))
      hydrogenCursor += 1
    }
  }
  for atomID in removedHydrogens.reversed() {
    tooltip.apex.remove(at: Int(atomID))
  }
}

#if false
// Workspace for measuring energies.
func createGeometry() -> [Entity] {
  struct Framework {
    var type: CageFrameworkType
    var apexPassivators: [Element] = [
      .hydrogen, .fluorine,
      .hydrogen, .fluorine,
      .hydrogen, .fluorine,
    ]
  }
  
  struct Reaction {
    var chargedTooltip: CageFeedstockType
    var dischargedTooltip: CageFeedstockType
    var unboundFeedstock: CageFeedstockType
  }
  
  let frameworks: [Framework] = [
//    Framework(type: .adamantasilane(.carbon)),
//    Framework(type: .adamantasilane(.silicon)),
    Framework(type: .adamantasilane(.germanium)),
//    Framework(type: .adamantasilane(.tin)),
//    Framework(type: .adamantasilane(.lead)),
//    Framework(type: .atrane(.silicon)),
//    Framework(type: .atrane(.germanium)),
//    Framework(type: .atrane(.tin)),
//    Framework(type: .atrane(.lead)),
//    Framework(type: .ethynylAdamantane),
//    Framework(type: .adamantane(.carbon)),
//    Framework(type: .adamantane(.silicon)),
//    Framework(type: .adamantane(.germanium)),
  ]
  let frameworkNames: [String] = [
//    "| adamantasilane(C)  ",
//    "| adamantasilane(Si) ",
    "| adamantasilane(Ge) ",
//    "| adamantasilane(Sn) ",
//    "| adamantasilane(Pb) ",
//    "| atrane(Si)         ",
//    "| atrane(Ge)         ",
//    "| atrane(Sn)         ",
//    "| atrane(Pb)         ",
//    "| ethynyl-adamantane ",
//    "| adamantane(C)      ",
//    "| adamantane(Si)     ",
//    "| adamantane(Ge)     ",
  ]
  let feedstocks: [Reaction] = [
    Reaction(
      chargedTooltip: .hydrogen,
      dischargedTooltip: .radical,
      unboundFeedstock: .hydrogen),
    Reaction(
      chargedTooltip: .trihalogenide(.silicon, .hydrogen, .hydrogen, .bromine),
      dischargedTooltip: .radical,
      unboundFeedstock: .trihalogenide(.silicon, .hydrogen, .hydrogen, .bromine)),
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
      replaceApex(tooltip: &dischargedTooltip)
      try! dischargedTooltip.loadCachedValue()
      
      cageTooltipDesc = CageTooltipDescriptor()
      cageTooltipDesc.apexPassivators = framework.apexPassivators
      cageTooltipDesc.feedstockType = reaction.chargedTooltip
      cageTooltipDesc.frameworkType = framework.type
      var chargedTooltip = CageTooltip(descriptor: cageTooltipDesc)
      replaceApex(tooltip: &chargedTooltip)
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
