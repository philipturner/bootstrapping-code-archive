//
//  Reference+Animation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/8/24.
//

#if false

// Workspace for scripting together an offline render.
// - Start with a skeleton of the animation. Duplicate a still of the starting
//   frame. It should last for the expected duration of each scene.
func createGeometry() -> [[Entity]] {
  var frames: [[Entity]] = []
//   frames += createReaction1()
//  frames += createReaction2()
//   frames += createReaction3()
//  frames += createReaction4()
  frames += createFinalProduct()
  
  // Reposition the camera.
  let rotation1 = Quaternion<Float>(angle: 5 * .pi / 6, axis: [0, 1, 0])
  let rotation2 = Quaternion<Float>(angle: .pi / 10, axis: [1, 0, 0])
  let offset = SIMD3<Float>(0, -0.6, -7)
  for frameID in frames.indices {
    var frame = frames[frameID]
    for atomID in frame.indices {
      var atom = frame[atomID]
      atom.position = rotation1.act(on: atom.position)
      atom.position = rotation2.act(on: atom.position)
      atom.position += offset
      frame[atomID] = atom
    }
    frames[frameID] = frame
  }
  
  return frames
}

// MARK: - Animation Scenes

func createInitialBuildPlate() -> BuildPlate {
  var buildPlate = BuildPlate()
  buildPlate.rotate(angle: -.pi / 2, axis: [1, 0, 0])
  buildPlate.translate(offset: -buildPlate.centerOfMass)
  return buildPlate
}

func createInitialTooltip() -> CurrentTooltip {
  var tooltip = CurrentTooltip()
  tooltip.rotate(angle: .pi, axis: [0, 0, 1])
  tooltip.translate(offset: -tooltip.centerOfMass)
  do {
    let dimer = tooltip.dimer
    let offsetY = -dimer[0].position.y
    tooltip.translate(offset: [0, offsetY, 0])
  }
  return tooltip
}

func createReaction1() -> [[Entity]] {
  var buildPlate = createInitialBuildPlate()
  var tooltip = createInitialTooltip()
  
  buildPlate.topology.atoms = minimize(atoms: buildPlate.topology.atoms)
  tooltip.topology.atoms = minimize(atoms: tooltip.topology.atoms)

  var reactionDesc = ReactionDescriptor()
  reactionDesc.buildPlate = buildPlate
  reactionDesc.tooltip = tooltip
  reactionDesc.frameBudget = 375
  reactionDesc.xMin = 0.1
  reactionDesc.xMax = 1.0
  var reaction = Reaction(descriptor: reactionDesc)
  
  var frames: [[Entity]] = []
  for _ in 0..<30 {
    frames.append(
      reaction.buildPlate.topology.atoms +
      reaction.tooltip.topology.atoms)
  }
  
  for _ in 0..<reaction.frameBudget {
    reaction.step()
    
    var frame: [Entity] = []
    let reactionPositions = reaction.positions
    for atomID in reactionPositions.indices {
      let atomicNumber = reaction.calculator.molecule.atomicNumbers[atomID]
      let position = reactionPositions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let atom = Entity(storage: storage)
      frame.append(atom)
    }
    frames.append(frame)
  }
  for _ in 0..<30 {
    frames.append(frames.last!)
  }
  return frames
}

func createReaction2() -> [[Entity]] {
  var buildPlate = createInitialBuildPlate()
  var tooltip = createInitialTooltip()
  
  buildPlate.topology.atoms = minimize(
    atoms: Reaction.product1, anchorIDs: buildPlate.anchorAtomIDs)
  for atomID in tooltip.dimerAtomIDs {
    tooltip.topology.atoms[Int(atomID)].atomicNumber = 1
  }
  tooltip.translate(offset: [0, 0, 0.15])
  tooltip.topology.atoms = minimize(atoms: tooltip.topology.atoms)

  var reactionDesc = ReactionDescriptor()
  reactionDesc.buildPlate = buildPlate
  reactionDesc.tooltip = tooltip
  reactionDesc.frameBudget = 4 * 40
  reactionDesc.xMin = 0.4
  reactionDesc.xMax = 0.8
  var reaction = Reaction(descriptor: reactionDesc)
  
  var frames: [[Entity]] = []
  for _ in 0..<30 {
    frames.append(
      reaction.buildPlate.topology.atoms +
      reaction.tooltip.topology.atoms)
  }
  
  for _ in 0..<reaction.frameBudget {
    reaction.step()
    
    var frame: [Entity] = []
    let reactionPositions = reaction.positions
    for atomID in reactionPositions.indices {
      let atomicNumber = reaction.calculator.molecule.atomicNumbers[atomID]
      let position = reactionPositions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let atom = Entity(storage: storage)
      frame.append(atom)
    }
    frames.append(frame)
  }
  for _ in 0..<30 {
    frames.append(frames.last!)
  }
  return frames
}

func createReaction3() -> [[Entity]] {
  var buildPlate = createInitialBuildPlate()
  var tooltip = createInitialTooltip()
  
  buildPlate.topology.atoms = minimize(
    atoms: Reaction.product2, anchorIDs: buildPlate.anchorAtomIDs)
  tooltip.translate(offset: [0, 0, -0.2])
  tooltip.topology.atoms = minimize(atoms: tooltip.topology.atoms)

  var reactionDesc = ReactionDescriptor()
  reactionDesc.buildPlate = buildPlate
  reactionDesc.tooltip = tooltip
  reactionDesc.frameBudget = 8 * 40
  reactionDesc.xMin = 0.2
  reactionDesc.xMax = 1.0
  var reaction = Reaction(descriptor: reactionDesc)
  
  var frames: [[Entity]] = []
  for _ in 0..<30 {
    frames.append(
      reaction.buildPlate.topology.atoms +
      reaction.tooltip.topology.atoms)
  }
  
  for _ in 0..<reaction.frameBudget {
    reaction.step()
    
    var frame: [Entity] = []
    let reactionPositions = reaction.positions
    for atomID in reactionPositions.indices {
      let atomicNumber = reaction.calculator.molecule.atomicNumbers[atomID]
      let position = reactionPositions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let atom = Entity(storage: storage)
      frame.append(atom)
    }
    frames.append(frame)
  }
  for _ in 0..<30 {
    frames.append(frames.last!)
  }
  return frames
}

func createReaction4() -> [[Entity]] {
  var buildPlate = createInitialBuildPlate()
  var tooltip = createInitialTooltip()
  
  buildPlate.topology.atoms = minimize(
    atoms: Reaction.product3, anchorIDs: buildPlate.anchorAtomIDs)
  for atomID in tooltip.dimerAtomIDs {
    tooltip.topology.atoms[Int(atomID)].atomicNumber = 1
  }
  tooltip.translate(offset: [0.1, 0, -0.2])
  tooltip.topology.atoms = minimize(atoms: tooltip.topology.atoms)

  var reactionDesc = ReactionDescriptor()
  reactionDesc.buildPlate = buildPlate
  reactionDesc.tooltip = tooltip
  reactionDesc.frameBudget = 4 * 40
  reactionDesc.xMin = 0.5
  reactionDesc.xMax = 0.9
  var reaction = Reaction(descriptor: reactionDesc)
  
  var frames: [[Entity]] = []
  for _ in 0..<30 {
    frames.append(
      reaction.buildPlate.topology.atoms +
      reaction.tooltip.topology.atoms)
  }
  
  for _ in 0..<reaction.frameBudget {
    reaction.step()
    
    var frame: [Entity] = []
    let reactionPositions = reaction.positions
    for atomID in reactionPositions.indices {
      let atomicNumber = reaction.calculator.molecule.atomicNumbers[atomID]
      let position = reactionPositions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let atom = Entity(storage: storage)
      frame.append(atom)
    }
    frames.append(frame)
  }
  for _ in 0..<30 {
    frames.append(frames.last!)
  }
  return frames
}

func createFinalProduct() -> [[Entity]] {
  var buildPlate = createInitialBuildPlate()
  var tooltip = createInitialTooltip()
  
  buildPlate.topology.atoms = Reaction.product4
  buildPlate.topology.atoms = minimize(
    atoms: Reaction.product4, anchorIDs: buildPlate.anchorAtomIDs)
  for atomID in tooltip.dimerAtomIDs {
    tooltip.topology.atoms[Int(atomID)].atomicNumber = 1
  }
  tooltip.translate(offset: [0.1, 0.9, -0.2])
  tooltip.topology.atoms = minimize(atoms: tooltip.topology.atoms)
  tooltip.topology.remove(atoms: [tooltip.dimerAtomIDs[0]])
  
  let still = buildPlate.topology.atoms + tooltip.topology.atoms
  return Array(repeating: still, count: 120)
}

// MARK: - Offline Rendering

func renderOffline(renderingEngine: MRRenderer) {
  struct Provider: MRAtomProvider {
    var atomFrames: [[Entity]] = []
    
    init() {
      atomFrames = createGeometry()
    }
    
    func atoms(time: MolecularRenderer.MRTime) -> [MolecularRenderer.MRAtom] {
      var frameID = time.absolute.frames
      frameID = max(frameID, 0)
      frameID = min(frameID, atomFrames.count - 1)
      
      let atomFrame = atomFrames[frameID]
      return atomFrame.map {
        MRAtom(origin: $0.position, element: $0.atomicNumber)
      }
    }
  }
  
  // Set up the renderer.
  let atomProvider = Provider()
  renderingEngine.setAtomProvider(atomProvider)
  renderingEngine.setQuality(
    MRQuality(minSamples: 7, maxSamples: 32, qualityCoefficient: 100))
  
  let position: SIMD3<Float> = .init(0, 0, 1)
  let rotation: (
    SIMD3<Float>,
    SIMD3<Float>,
    SIMD3<Float>
  ) = (
    SIMD3(1, 0, 0),
    SIMD3(0, 1, 0),
    SIMD3(0, 0, 1)
  )
  renderingEngine.setCamera(
    MRCamera(position: position, rotation: rotation, fovDegrees: 30))
  renderingEngine.setLights([
    MRLight(origin: position, diffusePower: 1, specularPower: 1)
  ])
  
  // Render to GIF.
  let renderSemaphore: DispatchSemaphore = .init(value: 0)
  let imageHeight: Int = 1080
  let imageWidth: Int = 1920
  var gif = GIF(width: imageWidth, height: imageHeight)
  
  let checkpoint0 = Date()
  for frameID in 0..<(atomProvider.atomFrames.count / 2) {
    print("rendering frame:", frameID * 2)
    
    var pixelBuffer = [UInt16](repeating: 0, count: 4 * imageWidth * imageHeight)
    
    for offset in 0..<1 {
      let time = MRTime(absolute: frameID * 2 + offset, relative: 1, frameRate: 60)
      renderingEngine.setTime(time)
      renderingEngine.render { pixels in
        for pixelID in 0..<4 * imageWidth * imageHeight {
          pixelBuffer[pixelID] &+= UInt16(pixels[pixelID])
        }
        renderSemaphore.signal()
      }
      renderSemaphore.wait()
    }
    
    let image = try! CairoImage(width: imageWidth, height: imageHeight)
    for y in 0..<imageHeight {
      for x in 0..<imageWidth {
        let address = y * imageWidth + x
        let r = pixelBuffer[4 * address + 0]
        let g = pixelBuffer[4 * address + 1]
        let b = pixelBuffer[4 * address + 2]
        let a = pixelBuffer[4 * address + 3]
        
        let pixelVector16 = SIMD4(r, g, b, a)
        let pixelVector8 = SIMD4<UInt8>(truncatingIfNeeded: pixelVector16 / 1)
        let pixelScalar = unsafeBitCast(pixelVector8, to: UInt32.self)
        let color = Color(argb: pixelScalar)
        image[y, x] = color
      }
    }
    
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
  print(data.count)
  
  let checkpoint2 = Date()
  
  print("saving to file")
  let path = "/Users/philipturner/Desktop/Render.gif"
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
  
  exit(0)
}

#endif



#if false
// Example of animating a Bezier curve.
func createGeometry() -> [[Entity]] {
  let cacheFolder =
  "/Users/philipturner/Documents/OpenMM/cache/Silicon111Reaction"
  let folder = URL(filePath: cacheFolder)
  let fileName = "Reaction 3m (2024-07-20 03_17_37 +0000).data"
  let file = folder.appending(
    component: fileName, directoryHint: .notDirectory)

  let data = try! Data(contentsOf: file)
  var frames = Serialization.decode(frames: data)
  frames.removeLast()
  
  // Record the camera position and orientation at keyframes you want to film.
  //
  // First Keyframe:
  // position=SIMD3(1.173, 0.150, -0.571) | azimuth=-0.700, zenith=0.018
  // r=1.313 nm
  //
  // Interim Keyframe:
  // position=SIMD3(-0.993, -0.433, -1.243) | azimuth=-0.400, zenith=0.071
  // r=1.649 nm
  //
  // Last Keyframe:
  // position=SIMD3(-1.397, -0.283, -0.387) | azimuth=-0.283, zenith=0.071
  // r=1.477
  
  let keyframePositions: [SIMD3<Float>] = [
    SIMD3(1.173, 0.150, -0.571),
    SIMD3(-0.993, -0.433, -1.243),
    SIMD3(-1.397, -0.283, -0.387),
  ]
  
  // lane 0 = azimuth, lane 1 = zenith
  let keyframeOrientations: [SIMD2<Float>] = [
    SIMD2(-0.700, 0.018),
    SIMD2(-0.400, 0.071),
    SIMD2(-0.283, 0.071),
  ]
  
  for frameID in frames.indices {
    var frame = frames[frameID]
    let t = Float(frameID) / Float(frames.count)
    
    let P0 = keyframePositions[0]
    let P1 = keyframePositions[0]
    let P2 = keyframePositions[1]
    let P3 = keyframePositions[2]
    
    let O0 = keyframeOrientations[0]
    let O1 = keyframeOrientations[0]
    let O2 = keyframeOrientations[1]
    let O3 = keyframeOrientations[2]
    
    let bezierPosition =
    (1 - t) * (1 - t) * (1 - t) * P0 +
    3 * (1 - t) * (1 - t) * t * P1 +
    3 * (1 - t) * t * t * P2 +
    t * t * t * P3
    
    let bezierOrientation =
    (1 - t) * (1 - t) * (1 - t) * O0 +
    3 * (1 - t) * (1 - t) * t * O1 +
    3 * (1 - t) * t * t * O2 +
    t * t * t * O3
    
    let azimuth = bezierOrientation[0]
    let zenith = bezierOrientation[1]
    func rotation(azimuth: Float, zenith: Float) -> (
      SIMD3<Float>, SIMD3<Float>, SIMD3<Float>
    ) {
      guard zenith >= -0.25 && zenith <= 0.25 else {
        fatalError("Invalid zenith: \(zenith).")
      }
      let quaternionU = Quaternion<Float>(
        angle: zenith * 2 * .pi, axis: [1, 0, 0])
      let quaternionY = Quaternion<Float>(
        angle: azimuth * 2 * .pi, axis: [0, 1, 0])
      
      var basis1 = quaternionY.act(on: [1, 0, 0])
      var basis2 = quaternionY.act(on: [0, 1, 0])
      var basis3 = quaternionY.act(on: [0, 0, 1])
      basis1 = quaternionU.act(on: basis1)
      basis2 = quaternionU.act(on: basis2)
      basis3 = quaternionU.act(on: basis3)
      return (basis1, basis2, basis3)
    }
    let rotation = rotation(azimuth: -azimuth, zenith: -zenith)
    
    for atomID in frame.indices {
      var atom = frame[atomID]
      
      atom.position -= bezierPosition
      atom.position =
      rotation.0 * atom.position.x +
      rotation.1 * atom.position.y +
      rotation.2 * atom.position.z
      
      
      frame[atomID] = atom
    }
    frames[frameID] = frame
  }
  
  return frames
}

#endif
