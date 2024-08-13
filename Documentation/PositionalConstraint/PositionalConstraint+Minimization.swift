//
//  PositionalConstraint+Minimization.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/25/24.
//

import Foundation
import HDL
import Numerics
import xTB

// A configuration for a positional constraint minimization.
struct MinimizationDescriptor {
  // The orientation to constrain the C-Si bond to. This pertains to the
  // first carbon atom.
  var bondOrientationDegrees: Float?
  
  // The number of carbon atoms on the silicon surface.
  var methylCount: Int?
  
  // Whether the second carbon atom is a methylene.
  var methylenePresent: Bool?
  
  // If GFN-FF is used, you must specify a pre-conditioned surface structure.
  var preconditionedStructure: [Entity]?
  
  // Whether to include van der Waals forces from GFN-FF.
  var useONIOM: Bool = false
}

// A positional constraint minimization.
struct Minimization {
  // The key to use in a cache.
  var key: String
  
  var bondVector2D: SIMD3<Float>
  var tooltip: Silicon111Tooltip
  
  var innerHighCalculator: xTB_Calculator
  var innerLowCalculator: xTB_Calculator!
  var outerLowCalculator: xTB_Calculator!
  
  init(descriptor: MinimizationDescriptor) {
    guard let bondOrientationDegrees = descriptor.bondOrientationDegrees,
          let methylCount = descriptor.methylCount,
          let methylenePresent = descriptor.methylenePresent else {
      fatalError("Descriptor was incomplete.")
    }
    key = Minimization.createKey(descriptor: descriptor)
    
    // Set up the tooltip.
    tooltip = Silicon111Tooltip(type: .modelS)
    if descriptor.useONIOM {
      guard let surface = descriptor.preconditionedStructure else {
        fatalError("Did not specify preconditioned structure for GFN-FF.")
      }
      tooltip.surface = surface
    } else {
      tooltip.surface = Minimization.createSurface(
        from: tooltip.surface, descriptor: descriptor)
    }
    
    // Define the bond vector in the XZ plane.
    do {
      let angle = bondOrientationDegrees * .pi / 180
      let rotation = Quaternion<Float>(
        angle: angle, axis: SIMD3(0.00, -1.00, 0.00))
      bondVector2D = SIMD3(1.00, 0.00, 0.00)
      bondVector2D = rotation.act(on: bondVector2D)
    }
    
    // Set up the calculator.
    let initialLinkAtoms = Silicon111Tooltip.createLinkAtoms(
      inner: tooltip.surface,
      outer: tooltip.anchors,
      boundary: tooltip.boundary)
    let initialAtoms = tooltip.surface + initialLinkAtoms
    
    
    var calculatorDesc = xTB_CalculatorDescriptor()
    calculatorDesc.atomicNumbers = initialAtoms.map(\.atomicNumber)
    calculatorDesc.hamiltonian = .tightBinding
    calculatorDesc.positions = initialAtoms.map(\.position)
    innerHighCalculator = xTB_Calculator(descriptor: calculatorDesc)
    
    if descriptor.useONIOM {
      calculatorDesc.hamiltonian = .forceField
      innerLowCalculator = xTB_Calculator(descriptor: calculatorDesc)
      
      let allAtoms = tooltip.surface + tooltip.anchors
      calculatorDesc = xTB_CalculatorDescriptor()
      calculatorDesc.atomicNumbers = allAtoms.map(\.atomicNumber)
      calculatorDesc.hamiltonian = .forceField
      calculatorDesc.positions = allAtoms.map(\.position)
      outerLowCalculator = xTB_Calculator(descriptor: calculatorDesc)
    }
  }
  
  // Creates a decorated surface from an H-passivated model S surface.
  static func createSurface(
    from cleanSurface: [Entity],
    descriptor: MinimizationDescriptor
  ) -> [Entity] {
    var output = cleanSurface
    
    // Declare the functional groups to decorate the surface with.
    let carbonChain = [
      // R-CH2-SiH3
      Entity(position: SIMD3(-0.05, -0.18, 0.00), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.10, -0.22, -0.10), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.10, -0.22, 0.10), type: .atom(.hydrogen)),
      
      Entity(position: SIMD3(0.10, -0.30, 0.00), type: .atom(.silicon)),
      Entity(position: SIMD3(-0.02, -0.40, 0.00), type: .atom(.hydrogen)),
      Entity(position: SIMD3(0.17, -0.40, 0.12), type: .atom(.hydrogen)),
      Entity(position: SIMD3(0.17, -0.40, -0.12), type: .atom(.hydrogen)),
    ]
    let methyl: [Entity] = [
      // R-CH3
      Entity(position: SIMD3(-0.00, -0.18, 0.00), type: .atom(.carbon)),
      Entity(position: SIMD3(-0.05, -0.22, -0.10), type: .atom(.hydrogen)),
      Entity(position: SIMD3(-0.05, -0.22, 0.10), type: .atom(.hydrogen)),
      Entity(position: SIMD3(0.10, -0.22, 0.00), type: .atom(.hydrogen)),
    ]
    let methylene: [Entity] = [
      // R-CH2*
      Entity(position: SIMD3(0.00, -0.18, 0.00), type: .atom(.carbon)),
      Entity(position: SIMD3(0.00, -0.25, -0.10), type: .atom(.hydrogen)),
      Entity(position: SIMD3(0.00, -0.25, 0.10), type: .atom(.hydrogen)),
    ]
    
    
    // Hydrogens passivating the methyl sites:
    //   center site
    //     19 1 SIMD3<Float>(-0.001953125, -0.14550781, 0.0)
    //   right site
    //     14 1 SIMD3<Float>(0.390625, -0.15234375, 0.005859375)
    //   top site (included in 3-methyl model)
    //     16 1 SIMD3<Float>(0.19921875, -0.15136719, 0.3359375)
    //   bottom site (included in 4-methyl model)
    //     13 1 SIMD3<Float>(0.19140625, -0.15039062, -0.34277344)
    output.remove(at: 19)
    output.remove(at: 16)
    output.remove(at: 14)
    output.remove(at: 13)
    
    // Inject the atom IDs for the carbon and silicon.
    //   carbon atom
    //     16 6 SIMD3<Float>(-0.05, -0.18, 0.0)
    //   silicon atom
    //     19 14 SIMD3<Float>(0.1, -0.3, 0.0)
    do {
      let angle = descriptor.bondOrientationDegrees! * .pi / 180
      let rotation = Quaternion<Float>(
        angle: angle, axis: SIMD3(0.00, -1.00, 0.00))
      output += carbonChain.map {
        var copy = $0
        copy.position = rotation.act(on: copy.position)
        return copy
      }
    }
    
    // Add hydrogen, methylene, or methyl to the remaining sites.
    guard descriptor.methylCount! >= 2,
          descriptor.methylCount! <= 4 else {
      fatalError("Invalid methyl count.")
    }
    
    // Pick the second functional group.
    let secondGroup = descriptor.methylenePresent! ? methylene : methyl
    output += secondGroup.map {
      var copy = $0
      copy.position += SIMD3(0.39, 0.00, 0.00)
      return copy
    }
    
    // Assign the third and fourth methyls.
    for methylID in [3, 4] {
      var offset: SIMD3<Float>
      if methylID == 3 {
        offset = SIMD3(0.20, 0.00, 0.34)
      } else {
        offset = SIMD3(0.20, 0.00, -0.34)
      }
      
      if descriptor.methylCount! >= methylID {
        output += methyl.map {
          var copy = $0
          copy.position += offset
          return copy
        }
      } else {
        let hydrogen = Entity(
          position: offset + SIMD3(0.00, -0.15, 0.00), type: .atom(.hydrogen))
        output.append(hydrogen)
      }
    }
    
    return output
  }
  
  // Creates a key for use in a cache.
  static func createKey(descriptor: MinimizationDescriptor) -> String {
    var output = ""
    
    // Add the methyl count.
    switch descriptor.methylCount! {
    case 2:
      output += "2Methyls"
    case 3:
      output += "3Methyls"
    case 4:
      output += "4Methyls"
    default:
      fatalError("Unexpected methyl count.")
    }
    output += "_"
    
    // Add the moiety type.
    if descriptor.methylenePresent! {
      output += "SiH3CH2"
    } else {
      output += "SiH3CH3"
    }
    output += "_"
    
    // Add the bond rotation.
    let degreesInt = Int(descriptor.bondOrientationDegrees!)
    output += "\(degreesInt)Degrees"
    output += "_"
    
    // Add the level of theory.
    if descriptor.useONIOM {
      output += "ONIOM"
    } else {
      output += "xTB"
    }
    
    return output
  }
}

extension Minimization {
  // Runs an energy minimization and returns the frames.
  //
  // Does not modify the state of the tooltip.
  func runMinimization() -> [[Entity]] {
    let initialLinkAtoms = Silicon111Tooltip.createLinkAtoms(
      inner: tooltip.surface,
      outer: tooltip.anchors,
      boundary: tooltip.boundary)
    let initialAtoms = tooltip.surface + initialLinkAtoms
    
    // Set up an energy minimization.
    var minimizationDesc = FIREMinimizationDescriptor()
    minimizationDesc.anchors = Set(
      Array(tooltip.surface.count..<initialAtoms.count).map(UInt32.init))
    
    // Fix an issue with the surface separating from the bulk in GFN-FF.
    for link in tooltip.boundary {
      minimizationDesc.anchors!.insert(link[0])
    }
    
    minimizationDesc.masses = initialAtoms.map {
      if $0.atomicNumber == 1 {
        return Float(4.0 * 1.660539)
      } else {
        return Float(12.011 * 1.660539)
      }
    }
    minimizationDesc.positions = initialAtoms.map(\.position)
    var minimization = FIREMinimization(descriptor: minimizationDesc)
    
    // Iterate through the timesteps.
    var frames: [[Entity]] = [tooltip.surface]
    
    for _ in 0..<500 {
      // Enforce the constraints on link atoms.
      do {
        var inner = tooltip.surface
        for atomID in inner.indices {
          var atom = inner[atomID]
          atom.position = minimization.positions[atomID]
          inner[atomID] = atom
        }
        let linkAtoms = Silicon111Tooltip.createLinkAtoms(
          inner: inner,
          outer: tooltip.anchors,
          boundary: tooltip.boundary)
        
        for atomID in linkAtoms.indices {
          let linkAtom = linkAtoms[atomID]
          let position = linkAtom.position
          
          let projectedAtomID = tooltip.surface.count + atomID
          minimization.positions[projectedAtomID] = position
        }
      }
      
      // Enter the atom coordinates into the calculators.
      innerHighCalculator.molecule.positions = minimization.positions
      if innerLowCalculator != nil,
         outerLowCalculator != nil {
        innerLowCalculator.molecule.positions = minimization.positions
        
        let surfaceAtomCount = tooltip.surface.count
        let surfacePositions = Array(
          minimization.positions[0..<surfaceAtomCount])
        let anchorPositions = tooltip.anchors.map(\.position)
        let allPositions = surfacePositions + anchorPositions
        outerLowCalculator.molecule.positions = allPositions
      }
      
      // Fetch the forces.
      var forces = innerHighCalculator.molecule.forces
      if innerLowCalculator != nil,
         outerLowCalculator != nil {
        let innerLowForces = innerLowCalculator.molecule.forces
        let outerLowForces = outerLowCalculator.molecule.forces
        
        let surfaceAtomCount = tooltip.surface.count
        for atomID in 0..<surfaceAtomCount {
          forces[atomID] -= innerLowForces[atomID]
          forces[atomID] += outerLowForces[atomID]
        }
      }
      
      // Clamp the magnitude of the forces.
      for forceID in forces.indices {
        var force = forces[forceID]
        let forceMagnitude = (force * force).sum().squareRoot()
        if forceMagnitude > 20000 {
          force *= 20000 / forceMagnitude
        }
        forces[forceID] = force
      }
      
      // Removes the component that would make the atom deviate from the
      // desired bond vector.
      func removeDeviation(
        of vector: inout SIMD3<Float>,
        from bondVector2D: SIMD3<Float>
      ) {
        let inPlanePart = SIMD3(vector.x, .zero, vector.z)
        
        let dotProduct = (inPlanePart * bondVector2D).sum()
        let parallelPart = dotProduct * bondVector2D
        let perpendicularPart = inPlanePart - parallelPart
        vector -= perpendicularPart
      }
      
      // Enforce the constraint on the C-Si bond.
      removeDeviation(of: &forces[16], from: bondVector2D)
      removeDeviation(of: &forces[19], from: bondVector2D)
      removeDeviation(of: &minimization.velocities[16], from: bondVector2D)
      removeDeviation(of: &minimization.velocities[19], from: bondVector2D)
      
      var maximumForce: Float = .zero
      for atomID in initialAtoms.indices {
        if minimization.anchors.contains(UInt32(atomID)) {
          continue
        }
        let force = forces[atomID]
        let forceMagnitude = (force * force).sum().squareRoot()
        maximumForce = max(maximumForce, forceMagnitude)
      }
      
      // Find the energy from ONIOM.
      var energy = innerHighCalculator.energy
      if innerLowCalculator != nil,
         outerLowCalculator != nil {
        energy -= innerLowCalculator.energy
        energy += outerLowCalculator.energy
      }
      
      print("time: \(Format.time(minimization.time))", terminator: " | ")
      print("energy: \(Format.energy(energy))", terminator: " | ")
      print("max force: \(Format.force(maximumForce))", terminator: " | ")
      
      let converged = minimization.step(forces: forces)
      if !converged {
        print("Δt: \(Format.time(minimization.Δt))", terminator: " | ")
      }
      print()
      
      if converged {
        break
      }
      
      // Enforce the constraint on the C-Si bond.
      do {
        let carbonPosition = minimization.positions[16]
        let siliconPosition = minimization.positions[19]
        let midPoint = (carbonPosition + siliconPosition) / 2
        
        func fix(position: inout SIMD3<Float>) {
          var delta2D = position - midPoint
          delta2D.y = .zero
          removeDeviation(of: &delta2D, from: bondVector2D)
          
          var delta3D = position - midPoint
          delta3D.x = delta2D.x
          delta3D.z = delta3D.z
          position = midPoint + delta3D
        }
        fix(position: &minimization.positions[16])
        fix(position: &minimization.positions[19])
      }
      
      // Save the frame.
      var frame: [Entity] = []
      for atomID in tooltip.surface.indices {
        var atom = tooltip.surface[atomID]
        atom.position = minimization.positions[atomID]
        frame.append(atom)
      }
      frames.append(frame)
    }
    
    return frames
  }
  
  // Minimizes the surface, sending the frames through a cache.
  mutating func minimizeSurface() {
    // Choose a file name for the trajectory.
    let cacheFolder =
    "/Users/philipturner/Documents/OpenMM/cache/PositionalConstraint"
    let folder = URL(filePath: cacheFolder)
    let file = folder.appending(
      component: "\(key).data", directoryHint: .notDirectory)
    
    // Create the frames in one of two ways.
    var frames: [[Entity]]
    do {
      let data = try Data(contentsOf: file)
      frames = Serialization.decode(frames: data)
    } catch {
      frames = runMinimization()
      
      let data = Serialization.encode(frames: frames)
      try! data.write(to: file, options: .atomic)
    }
    
    // Choose the last frame as the optimized structure.
    let structure = frames.last!
    guard structure.count == tooltip.surface.count else {
      fatalError("Optimized structure had incorrect atom count.")
    }
    tooltip.surface = structure
  }
  
  // Returns the energy of the tooltip's surface.
  func singlepointEnergy() -> Double {
    let initialLinkAtoms = Silicon111Tooltip.createLinkAtoms(
      inner: tooltip.surface,
      outer: tooltip.anchors,
      boundary: tooltip.boundary)
    let initialAtoms = tooltip.surface + initialLinkAtoms
    
    // Enter the atom coordinates into the calculators.
    innerHighCalculator.molecule.positions = initialAtoms.map(\.position)
    if innerLowCalculator != nil,
       outerLowCalculator != nil {
      innerLowCalculator.molecule.positions = initialAtoms.map(\.position)
      
      let surfacePositions = tooltip.surface.map(\.position)
      let anchorPositions = tooltip.anchors.map(\.position)
      let allPositions = surfacePositions + anchorPositions
      outerLowCalculator.molecule.positions = allPositions
    }
    
    // Find the energy from ONIOM.
    var energy = innerHighCalculator.energy
    if innerLowCalculator != nil,
       outerLowCalculator != nil {
      energy -= innerLowCalculator.energy
      energy += outerLowCalculator.energy
    }
    return energy
  }
}
