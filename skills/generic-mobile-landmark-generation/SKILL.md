---
name: generic-mobile-landmark-generation
description: Remove white backgrounds from generated landmark images and prepare them as transparent PNGs with consistent padding for use on the Waonder map
type: generic
---

# generic-mobile-landmark-generation

## Context
Waonder generates landmark icons using AI image tools (Midjourney v6.0 or equivalent). The generated images come with a white background that must be removed before the icons can be used on the fog-of-war map. This skill covers the cleanup process: removing the white background, trimming to content, and adding consistent padding to produce map-ready transparent PNGs.

## Instructions
When the user has generated landmark images and needs to prepare them for the app, follow the steps below to remove the white background and produce clean transparent PNGs.

## Steps

### Option A: AI Assistant Approach

Use this prompt with an image-editing-capable AI:

```
Take the @[IMAGE_NAME] and convert it to a PNG with a transparent background by removing the white color. Trim the image to its content and add consistent padding around it.
```

### Option B: Command Line (ImageMagick)

**Single image:**
```bash
magick INPUT.png \
  -fuzz 5% \
  -transparent white \
  -trim \
  -bordercolor none -border 15x15 \
  OUTPUT_transparent.png
```

**Batch processing (all PNGs in current directory):**
```bash
for img in *.png; do
  magick "$img" -fuzz 5% -transparent white -trim -bordercolor none -border 15x15 "${img%.png}_transparent.png"
done
```

### Adjustable Parameters

| Parameter | Description | Recommended |
|-----------|-------------|-------------|
| `-fuzz 5%` | Tolerance for white detection. Increase if background remains, decrease if it eats into the image | `3%`–`10%` |
| `-border 15x15` | Padding in pixels around trimmed content | `10x10`–`20x20` |

## Constraints
- The CLI approach requires ImageMagick to be installed
- Fuzz tolerance may need adjusting per image — start at `5%` and increase only if white remains
- Output files should use the `_transparent.png` suffix to distinguish from originals
