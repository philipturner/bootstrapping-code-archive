//
//  AnimationProvider+MRCamera.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/2/24.
//

import MolecularRenderer

extension AnimationProvider {
  func camera(time: MRTime) -> MRCamera {
    var playerPosition: SIMD3<Float> = .zero
    var azimuth: Float = .zero
    var zenith: Float = .zero
    let fov: Float = 60
    
    // Switch on the scene ID.
    let timestamp = getTimestamp(time: time.absolute.seconds)
    switch timestamp.sceneID {
      // Build sequence title
    case 0:
      let origin = SurfaceScene.origin(reactionID: 0)
      playerPosition = origin
      
      let absoluteTime = timestamp.absoluteTime - 0
      var t = Float(absoluteTime / Double(8 - 0))
      t = max(0, min(1, t))
      t = t * t * (3 - 2 * t)
      azimuth = Float(0.00) * (1 - t) + Float(-0.15) * t
      
      // Build sequence scene
    case 1:
      var chosenSceneID: Int?
      for sceneID in reactionSceneTimeRanges.indices {
        let timeRange = reactionSceneTimeRanges[sceneID]
        guard timestamp.absoluteTime >= timeRange.lowerBound,
              timestamp.absoluteTime < timeRange.upperBound else {
          continue
        }
        chosenSceneID = sceneID
      }
      guard let chosenSceneID else {
        fatalError(
          "Time \(timestamp.absoluteTime) was outside the bounds 0 <= t < 75.")
      }
      
      // Retrieve the type of scene.
      let timeRange = reactionSceneTimeRanges[chosenSceneID]
      let sceneType = reactionSceneTypes[chosenSceneID]
      var progress = (timestamp.absoluteTime - timeRange.lowerBound)
      progress /= (timeRange.upperBound - timeRange.lowerBound)
      
      // Switch over the type of scene.
      switch sceneType {
      case .reaction(let reactionID):
        let offset = SurfaceScene.origin(reactionID: reactionID)
        playerPosition = offset
        azimuth = createAzimuth(
          reactionID: reactionID, progress: Float(progress))
        
      case .transition(let startID, let endID):
        // Identify the keyframes of the animation, in 3D space.
        let startOffset = SurfaceScene.origin(reactionID: startID)
        let endOffset = SurfaceScene.origin(reactionID: min(endID, 47))
       
        // Interpolate between the keyframes.
        var t = Float(progress)
        t = t * t * (3 - 2 * t)
        let offset = (1 - t) * startOffset + t * endOffset
        playerPosition = offset
        
        // Repeat an analogous process for the rotation.
        let startAzimuth = createAzimuth(reactionID: startID, progress: 1)
        var endAzimuth = createAzimuth(reactionID: endID, progress: 0)
        do {
          var counter = 0
          while (endAzimuth - startAzimuth).magnitude > 0.5 {
            if endAzimuth > startAzimuth {
              endAzimuth -= 1.00
            } else {
              endAzimuth += 1.00
            }
            counter += 1
            if counter > 100 {
              fatalError("Failed to converge angle adjustment.")
            }
          }
        }
        azimuth = (1 - t) * startAzimuth + t * endAzimuth
      }
      
      // Being still + summary title + summary scene
    case 2, 3, 4:
      let startOffset = SurfaceScene.origin(reactionID: 47)
      let endOffset: SIMD3<Float> = SIMD3(0.00, -0.80, 0.00)
      
      let startAzimuth: Float = 0.35
      let endAzimuth: Float = 0.00
      
      let startZenith: Float = 0.00
      let endZenith: Float = -0.20
      
      // Interpolate between the keyframes.
      var t = Float(timestamp.progress)
      if timestamp.sceneID == 2 {
        t = 0
      } else if timestamp.sceneID == 4 {
        t = 1
      }
      t = t * t * (3 - 2 * t)
      playerPosition = startOffset * (1 - t) + endOffset * t
      azimuth = startAzimuth * (1 - t) + endAzimuth * t
      zenith = startZenith * (1 - t) + endZenith * t
      
      // Rotating around
    case 5:
      playerPosition = SIMD3(0.00, -0.80, 0.00)
      
      do {
        let startAzimuth: Float = 0.00
        let endAzimuth: Float = 0.5
        
        var t = Float(min(timestamp.absoluteTime, 7.5)) / 5
        if t < 0.5 {
          t = t * t * (3 - 2 * t)
        } else {
          // The slope of the curve is 1.5 at the middle.
          t = 1.5 * (t - 0.5) + 0.5
        }
        azimuth = startAzimuth + t * (endAzimuth - startAzimuth)
      }
      
      do {
        let startZenith: Float = -0.20
        let endZenith: Float = -0.10
        
        var t = Float(min(timestamp.absoluteTime, 7.5)) / 5
        t = max(0, min(1, t))
        t = t * t * (3 - 2 * t)
        zenith = startZenith + t * (endZenith - startZenith)
      }
      
    default:
      break
    }
    
    let rotation = PlayerState.rotation(azimuth: azimuth, zenith: zenith)
    playerPosition += 3.50 * rotation.2
    
    return MRCamera(
      position: playerPosition,
      rotation: rotation,
      fovDegrees: fov)
  }
  
  // Find the camera azimuth for the probe's X/Z offset.
  func createAzimuth(
    reactionID: Int, progress: Float
  ) -> Float {
    let reactionName = reactionID + 1
    if reactionName <= 2 {
      // Start viewpoint.
      return -0.15
    } else if reactionName == 9 || reactionName == 10 {
      // HAbst (causes a rearrangement)
      return 0.18
    } else if reactionName == 11 {
      // SiH:
      return 0.18
    } else if reactionName == 13 {
      // Rearr.
      return 0.40
    } else if reactionName == 15 {
      // SiH3
      return -0.10
    } else if reactionName == 24 {
      // Rearr.
      return 0.35
    } else if reactionName == 30 {
      // Rearr.
      return -0.38
    } else if reactionName == 37 {
      // Rearr.
      return -0.45
    } else if reactionName == 43 || reactionName == 44 {
      // HAbst (causes a rearrangement)
      return 0.00
    } else if reactionName == 45 {
      // GeH:
      if progress < 0.55 {
        return 0.00
      } else {
        var altProgress = (progress - 0.55) / (0.75 - 0.55)
        altProgress = max(0, min(1, altProgress))
        altProgress = altProgress * altProgress * (3 - 2 * altProgress)
        return Float(0.00) * (1 - altProgress) + Float(0.35) * altProgress
      }
    } else if reactionName >= 46 {
      // End viewpoint.
      return 0.35
    }
    
    let reaction = buildSequence.reactions[reactionID]
    var probeOffset = reaction.farOffset
    if probeOffset.x.magnitude < 0.005,
       probeOffset.z.magnitude < 0.005 {
      fatalError("Invalid probe offset: \(probeOffset), reactionID: \(reactionID)")
    }
    probeOffset.y = .zero
    probeOffset /= (probeOffset * probeOffset).sum().squareRoot()
    
    let angleRadians = Float.atan2(y: -probeOffset.x, x: -probeOffset.z)
    let angleDegrees = angleRadians * 180 / Float.pi
    return angleDegrees * 0.25 / 90
  }
}
