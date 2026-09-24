class_name EditorValues
extends RefCounted
## JSON-friendly values for the scenery inspector. Never evaluates code.

static func encode(value: Variant) -> Variant:
	if value is Resource: return value.resource_path
	match typeof(value):
		TYPE_VECTOR2, TYPE_VECTOR2I: return [value.x, value.y]
		TYPE_RECT2, TYPE_RECT2I: return [value.position.x, value.position.y, value.size.x, value.size.y]
		TYPE_COLOR: return [value.r, value.g, value.b, value.a]
		TYPE_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			var result := []
			for v in value: result.append(encode(v))
			return result
	return value

static func decode(value: Variant, sample: Variant) -> Variant:
	if sample is Resource:
		return load(str(value)) if str(value) != "" and ResourceLoader.exists(str(value)) else null
	match typeof(sample):
		TYPE_VECTOR2: return Vector2(value[0], value[1])
		TYPE_VECTOR2I: return Vector2i(value[0], value[1])
		TYPE_RECT2: return Rect2(value[0], value[1], value[2], value[3])
		TYPE_RECT2I: return Rect2i(value[0], value[1], value[2], value[3])
		TYPE_COLOR: return Color(value[0], value[1], value[2], value[3])
		TYPE_PACKED_VECTOR2_ARRAY:
			var points := PackedVector2Array()
			for v in value: points.append(Vector2(v[0], v[1]))
			return points
		TYPE_ARRAY:
			var result: Array = sample.duplicate()
			result.clear()
			for v in value:
				match sample.get_typed_builtin():
					TYPE_RECT2: result.append(Rect2(v[0], v[1], v[2], v[3]))
					TYPE_COLOR: result.append(Color(v[0], v[1], v[2], v[3]))
					TYPE_OBJECT: result.append(load(v) if v is String and ResourceLoader.exists(v) else null)
					_: result.append(v)
			return result
		TYPE_INT: return int(value)
		TYPE_FLOAT: return float(value)
	return value

static func valid(value: Variant, sample: Variant) -> bool:
	if sample is Resource: return value is String and (value == "" or (ResourceLoader.exists(value) and load(value).is_class(sample.get_class())))
	match typeof(sample):
		TYPE_VECTOR2, TYPE_VECTOR2I: return numbers(value, 2)
		TYPE_RECT2, TYPE_RECT2I, TYPE_COLOR: return numbers(value, 4)
		TYPE_PACKED_VECTOR2_ARRAY:
			if not value is Array: return false
			for v in value:
				if not numbers(v, 2): return false
			return true
		TYPE_ARRAY:
			if not value is Array: return false
			for v in value:
				match sample.get_typed_builtin():
					TYPE_RECT2, TYPE_COLOR:
						if not numbers(v, 4): return false
					TYPE_OBJECT:
						if v != null and (not v is String or not ResourceLoader.exists(v) or not load(v) is Texture2D): return false
			return true
		TYPE_INT, TYPE_FLOAT: return value is float or value is int
		TYPE_BOOL: return value is bool
		TYPE_STRING, TYPE_STRING_NAME: return value is String
	return typeof(value) == typeof(sample)

static func numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for v in value:
		if not (v is float or v is int) or not is_finite(float(v)): return false
	return true
