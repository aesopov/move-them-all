extends ScrollContainer
## One input owner for list dragging, including gestures that begin on buttons.
const FRICTION := 7.0
const STOP_SPEED := 12.0
var pointer := -2
var start := Vector2.ZERO
var previous := Vector2.ZERO
var dragging := false
var velocity := 0.0
var last_motion := 0
var tap_button: BaseButton

func _ready() -> void:
	get_v_scroll_bar().step = 0.0

func _local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _inside(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_local(point))

func _button_at(node: Node, point: Vector2) -> BaseButton:
	for child in node.get_children():
		if child is Control and not child.is_visible_in_tree(): continue
		var found := _button_at(child, point)
		if found != null: return found
	if node is BaseButton and not node.disabled:
		var local: Vector2 = node.get_global_transform_with_canvas().affine_inverse() * point
		if Rect2(Vector2.ZERO, node.size).has_point(local): return node
	return null

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	# A button callback may remove this screen from the tree during _end().
	var viewport := get_viewport()
	if event is InputEventScreenTouch:
		if event.pressed and pointer == -2 and _inside(event.position):
			_begin(event.index, event.position)
		elif event.index == pointer:
			_end(event.position, event.canceled)
		else: return
	elif event is InputEventScreenDrag:
		if event.index != pointer: return
		_move(event.position)
	elif event is InputEventMouse and event.device == -1:
		# Touch is handled above; never also scroll or activate through emulated mouse.
		if pointer == -2 and not _inside(event.position): return
	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			velocity = 0.0
			return # Native wheel/trackpad scrolling, with no extra momentum.
		if event.pressed and pointer == -2 and _inside(event.position):
			if get_v_scroll_bar().get_global_rect().has_point(event.position): return
			_begin(-1, event.position)
		elif pointer == -1: _end(event.position, event.canceled)
		else: return
	elif event is InputEventMouseMotion and pointer == -1:
		_move(event.position)
	else: return
	if is_instance_valid(viewport): viewport.set_input_as_handled()

func _begin(id: int, point: Vector2) -> void:
	var was_gliding := absf(velocity) > STOP_SPEED
	velocity = 0.0
	pointer = id
	start = _local(point)
	previous = start
	dragging = false
	last_motion = Time.get_ticks_usec()
	tap_button = null if was_gliding else _button_at(self, point)

func _move(point: Vector2) -> void:
	var position := _local(point)
	if not dragging and position.distance_to(start) < 8.0: return
	dragging = true
	tap_button = null
	var now := Time.get_ticks_usec()
	var dt := clampf((now - last_motion) / 1000000.0, 1.0 / 240.0, 0.1)
	var bar := get_v_scroll_bar()
	var before := bar.value
	bar.value -= position.y - previous.y
	velocity = clampf((bar.value - before) / dt, -3000.0, 3000.0)
	previous = position
	last_motion = now

func _end(point: Vector2, cancelled: bool) -> void:
	var button := tap_button
	var activate := not dragging and not cancelled and is_instance_valid(button) and _inside(point) and _button_at(self, point) == button
	if cancelled or not dragging or Time.get_ticks_usec() - last_motion > 100000: velocity = 0.0
	pointer = -2
	tap_button = null
	dragging = false
	if activate: button.pressed.emit()

func _process(delta: float) -> void:
	if pointer != -2 or absf(velocity) < STOP_SPEED: return
	var bar := get_v_scroll_bar()
	var before := bar.value
	var decay := exp(-FRICTION * delta)
	bar.value += velocity * (1.0 - decay) / FRICTION
	velocity *= decay
	if is_equal_approx(bar.value, before) or bar.value <= bar.min_value or bar.value >= bar.max_value - bar.page:
		velocity = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pointer = -2
		tap_button = null
		velocity = 0.0
		dragging = false
