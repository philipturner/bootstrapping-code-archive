//
//  Captions.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/2/24.
//

import CairoGraphics

struct CaptionsDescriptor {
  // Center.
  var title: (text: String, opacity: Float)?
  
  // Center, slightly below the title.
  var subtitle1: (text: String, opacity: Float)?
  var subtitle2: (text: String, opacity: Float)?
  
  // Upper left.
  var reactionName: (text: String, opacity: Float)?
  
  // Upper left. Might span multiple lines.
  var reactionType: (text: String, opacity: Float)?
  
  // Lower left. Omitted from summary.
  var tooltip: (text: String, opacity: Float)?
}

extension Monocraft {
  static func drawCaptions(
    image: CairoImage,
    descriptor: CaptionsDescriptor
  ) {
    func drawTitle(
      text: String,
      opacity: Float, 
      fontSize: Int,
      position: SIMD2<Int>
    ) {
      let maskImage = try! CairoImage(
        width: image.width, height: image.height)
      
      // Iterate over the lines.
      do {
        // Determine the bounding box of the text.
        var boundingBoxX: Int = .zero
        for character in text {
          let (_, _, spacing) = Monocraft
            .createBitmap(character: character)
          boundingBoxX += spacing * fontSize
        }
        boundingBoxX -= 1 * fontSize
        
        // Determine the position of the text.
        var positionDelta: SIMD2<Int> = .zero
        positionDelta.x -= boundingBoxX / 2
        positionDelta.y -= (fontSize * 8) / 2
        
        // Determine the color of each character.
        var characters: [Character] = []
        var colors: [MonocraftColor] = []
        for character in text {
          characters.append(character)
          colors.append(.white)
        }
        
        // Render the text.
        var textDesc = MonocraftTextDescriptor()
        textDesc.characters = characters
        textDesc.colors = colors
        textDesc.position = position &+ positionDelta
        textDesc.size = fontSize
        Monocraft.drawText(image: maskImage, descriptor: textDesc)
      }
      
      // Render the mask.
      var maskDesc = MonocraftMaskDescriptor()
      maskDesc.image = maskImage
      maskDesc.opacity = opacity
      Monocraft.drawMask(image: image, descriptor: maskDesc)
    }
    
    if let title = descriptor.title {
      drawTitle(
        text: title.text,
        opacity: title.opacity, 
        fontSize: 8,
        position: SIMD2(image.width / 2, image.height / 2))
    }
    
    if let subtitle1 = descriptor.subtitle1 {
      drawTitle(
        text: subtitle1.text,
        opacity: subtitle1.opacity,
        fontSize: 4,
        position: SIMD2(image.width / 2, image.height / 2 + 96))
    }
    
    if let subtitle2 = descriptor.subtitle2 {
      drawTitle(
        text: subtitle2.text,
        opacity: subtitle2.opacity,
        fontSize: 4,
        position: SIMD2(image.width / 2, image.height / 2 + 160))
    }
    
    if let reactionName = descriptor.reactionName {
      // Determine the color of each character.
      var characters: [Character] = []
      var colors: [MonocraftColor] = []
      for character in reactionName.text {
        characters.append(character)
        if colors.count >= 8 {
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
      textDesc.position = SIMD2(32, image.height - 192)
      textDesc.size = 4
      Monocraft.drawText(image: maskImage, descriptor: textDesc)
      
      // Render the mask.
      var maskDesc = MonocraftMaskDescriptor()
      maskDesc.image = maskImage
      maskDesc.opacity = reactionName.opacity
      Monocraft.drawMask(image: image, descriptor: maskDesc)
    }
    
    if let reactionType = descriptor.reactionType {
      // Determine the color of each character.
      var characters: [Character] = []
      var colors: [MonocraftColor] = []
      var inParentheses: Bool = false
      for character in reactionType.text {
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
      textDesc.position = SIMD2(32, image.height - 128)
      textDesc.size = 4
      Monocraft.drawText(image: maskImage, descriptor: textDesc)
      
      // Render the mask.
      var maskDesc = MonocraftMaskDescriptor()
      maskDesc.image = maskImage
      maskDesc.opacity = reactionType.opacity
      Monocraft.drawMask(image: image, descriptor: maskDesc)
    }
    
    if let tooltip = descriptor.tooltip {
      // Determine the color of each character.
      var characters: [Character] = []
      var colors: [MonocraftColor] = []
      var inParentheses: Bool = false
      for character in tooltip.text {
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
      textDesc.position = SIMD2(32, image.height - 64)
      textDesc.size = 4
      Monocraft.drawText(image: maskImage, descriptor: textDesc)
      
      // Render the mask.
      var maskDesc = MonocraftMaskDescriptor()
      maskDesc.image = maskImage
      maskDesc.opacity = tooltip.opacity
      Monocraft.drawMask(image: image, descriptor: maskDesc)
    }
  }
}
