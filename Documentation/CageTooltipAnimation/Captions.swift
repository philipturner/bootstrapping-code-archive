//
//  Workspace+Captions.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/21/24.
//

import CairoGraphics
import GIF

struct CaptionsDescriptor {
  var structure: (text: String, opacity: Float)?
  var simulation: (text: String, opacity: Float)?
  var title: (lines: [String], opacity: Float)?
}

extension Monocraft {
  static func drawCaptions(
    image: CairoImage,
    descriptor: CaptionsDescriptor
  ) {
    if let structureCaption = descriptor.structure {
      // Determine the color of each character.
      var characters: [Character] = []
      var colors: [MonocraftColor] = []
      var inParentheses: Bool = false
      for character in structureCaption.text {
        characters.append(character)
        
        if character == ")" {
          inParentheses = false
        }
        if inParentheses {
          colors.append(.gold)
        } else {
          colors.append(.white)
        }
        if character == "(" {
          inParentheses = true
        }
      }
      
      // Create the temporary mask image.
      let maskImage = try! CairoImage(
        width: image.width, height: image.height)
      
      // Render the text.
      var textDesc = MonocraftTextDescriptor()
      textDesc.characters = characters
      textDesc.colors = colors
      textDesc.position = SIMD2(33, image.height - 120)
      textDesc.size = 4
      Monocraft.drawText(image: maskImage, descriptor: textDesc)
      
      // Render the mask.
      var maskDesc = MonocraftMaskDescriptor()
      maskDesc.image = maskImage
      maskDesc.opacity = structureCaption.opacity
      Monocraft.drawMask(image: image, descriptor: maskDesc)
    }
    
    if let simulationCaption = descriptor.simulation {
      // Determine the color of each character.
      var characters: [Character] = []
      var colors: [MonocraftColor] = []
      for character in simulationCaption.text {
        characters.append(character)
        if character.isWholeNumber {
          colors.append(.gold)
        } else {
          colors.append(.white)
        }
      }
      
      // Create the temporary mask image.
      let maskImage = try! CairoImage(
        width: image.width, height: image.height)
      
      // Render the text.
      var textDesc = MonocraftTextDescriptor()
      textDesc.characters = characters
      textDesc.colors = colors
      textDesc.position = SIMD2(33, image.height - 64)
      textDesc.size = 4
      Monocraft.drawText(image: maskImage, descriptor: textDesc)
      
      // Render the mask.
      var maskDesc = MonocraftMaskDescriptor()
      maskDesc.image = maskImage
      maskDesc.opacity = simulationCaption.opacity
      Monocraft.drawMask(image: image, descriptor: maskDesc)
    }
    
    if let titleCaption = descriptor.title {
      let maskImage = try! CairoImage(
        width: image.width, height: image.height)
      let fontSize: Int = 8
      
      var boundingBoxY: Int = .zero
      for _ in titleCaption.lines {
        boundingBoxY += 14 * fontSize
      }
      boundingBoxY -= 6 * fontSize
      
      // Iterate over the lines.
      for captionID in titleCaption.lines.indices {
        let text = titleCaption.lines[captionID]
        
        // Determine the bounding box of the text.
        var boundingBoxX: Int = .zero
        for character in text {
          let (_, _, spacing) = Monocraft
            .createBitmap(character: character)
          boundingBoxX += spacing * fontSize
        }
        boundingBoxX -= 1 * fontSize
        
        // Determine the position of the text.
        var position = SIMD2(image.width / 2, image.height / 2)
        position.x -= boundingBoxX / 2
        position.y -= boundingBoxY / 2
        position.y += (captionID * 14) * fontSize
        
        // Determine the color of each character.
        var characters: [Character] = []
        var colors: [MonocraftColor] = []
        for character in text {
          characters.append(character)
          if character.isWholeNumber ||
              character.isPunctuation {
            colors.append(.gold)
          } else {
            colors.append(.white)
          }
        }
        
        // Render the text.
        var textDesc = MonocraftTextDescriptor()
        textDesc.characters = characters
        textDesc.colors = colors
        textDesc.position = position
        textDesc.size = fontSize
        Monocraft.drawText(image: maskImage, descriptor: textDesc)
      }
      
      // Render the mask.
      var maskDesc = MonocraftMaskDescriptor()
      maskDesc.image = maskImage
      maskDesc.opacity = titleCaption.opacity
      Monocraft.drawMask(image: image, descriptor: maskDesc)
    }
  }
}
