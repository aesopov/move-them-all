class_name WallArt
extends RefCounted
## Pair existing solid wall cells visually; terrain remains the collision authority.
## No pairing across board edges, special skins, transport cells, or other terrain.

static func eligible(board: Board, terrain: PackedByteArray, c: int) -> bool:
	return c >= 0 and terrain[c] == Board.T.WALL and board.wall_skin[c] == Board.WallSkin.NONE and board.pipe_mouth[c] == -1 and board.teleport_to[c] == -2


static func layout(board: Board, terrain: PackedByteArray) -> Dictionary:
	var result := {}
	var used := {}
	for c in Board.N:
		if used.has(c) or not eligible(board, terrain, c):
			continue
		var size := Vector2i.ONE
		# Alternate preferred orientation to avoid long repetitive masonry bands.
		var directions := [Board.RIGHT, Board.DOWN] if (c % Board.W + c / Board.W) % 2 == 0 else [Board.DOWN, Board.RIGHT]
		for direction in directions:
			var neighbor := board.step(c, direction)
			if not used.has(neighbor) and eligible(board, terrain, neighbor):
				size = Vector2i(2, 1) if direction == Board.RIGHT else Vector2i(1, 2)
				used[neighbor] = true
				break
		used[c] = true
		result[c] = size
	return result


static var _textures := {}

static func texture(theme: String, name: String) -> Texture2D:
	var key := theme + "/" + name
	if not _textures.has(key):
		var source := AssetLib.tile(theme, name)
		if source == null:
			return null
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		# Ignore near-transparent generation haze when finding the visible silhouette.
		var image := source.get_image()
		var original_size := Vector2(image.get_size())
		image.resize(256, 256)
		var minimum := Vector2i(256, 256)
		var maximum := Vector2i.ZERO
		for y in 256:
			for x in 256:
				if image.get_pixel(x, y).a > 0.5:
					minimum = minimum.min(Vector2i(x, y))
					maximum = maximum.max(Vector2i(x, y))
		atlas.region = Rect2(Vector2(minimum) / 256.0 * original_size, Vector2(maximum - minimum + Vector2i.ONE) / 256.0 * original_size)
		_textures[key] = atlas
	return _textures[key]
