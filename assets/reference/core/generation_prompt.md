# Core item generation

Generated with the built-in image_gen tool. Based on prompts/01_items.md, with assets/reference/master_style.png as the style reference. Requested true transparency in place of chroma green.

## Exact prompt

Use case: stylized-concept. Asset type: production sprite sheet for Merge Them All. The attached image is STYLE REFERENCE ONLY. Match its polished hand-painted soft cel shading, clean dark outlines, saturated colours, top-left lighting, friendly chunky silhouettes. Generate a NEW square sprite sheet of exactly NINE items in an evenly spaced 3x3 grid, each centered in its own invisible equal square cell, each item filling at most 78% of cell width and height. Genuinely transparent background, including empty spaces. No cast shadows, no ground plane, no text, no grid lines. Row 1 left to right: faceted sapphire blue (#4DA8FF) crystal, elongated hexagon pointed top and bottom with bright facets; bushy green (#4CC74C) plant with six pointed glossy leaves in tiny terracotta pot; plump golden yellow (#FFD133) five-point star with lighter inner bevel. Row 2: peach pink (#FF9E8C) scallop shell with seven radial ridges and wavy edge; warm wooden (#D9853D) crate with dark planks, clearly visible diagonal X brace and metal corner rivets; chunky cool grey (#94949E) boulder, flat bottom, lighter upper face and a hairline crack. Row 3: glossy translucent sky blue (#59BFFF) soap bubble, circular dark rim and curved white top-left highlight; glossy magenta purple (#D959D9) oval party balloon with knot and SHORT curly white string fully contained within its cell; round black cartoon bomb with grey cap, short curved fuse and small yellow-orange spark. Consistent visual scale and outline weight, front view with slight top-down angle, silhouettes readable at 54 pixels. Exactly one of each, no duplicates, no locks, no keys, no tiles. Canvas square, equal thirds in both axes for clean slicing.

## Preparation

Run `bash tools/prepare_core_assets.sh` to slice the preserved source sheet, calculate visible bounds from alpha, and create the nine 128x128 game sprites. The crop divisions follow the generated sheet spacing rather than assuming a perfect grid. Runtime output: assets/items/{crystal,plant,star,shell,crate,rock,bubble,balloon,bomb}.png.

