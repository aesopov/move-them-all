extends Control
## Optional camera gestures. Coordinates stay in this unscaled, clipped viewport.
var view: BoardView
var enabled := false
var zoom := 1.0
var pan := Vector2.ZERO
var fingers := {}
var press := Vector2.ZERO
var moved := false
var mouse_down := false
var old_size := Vector2.ZERO
var pan_velocity := Vector2.ZERO
var _last_pan_usec := 0
const PAN_FRICTION := 7.0
const MIN_GLIDE_SPEED := 12.0
const MAX_GLIDE_SPEED := 2400.0

func _stop_glide() -> void:
	pan_velocity = Vector2.ZERO
	_last_pan_usec = Time.get_ticks_usec()

func _pan_by(offset: Vector2) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf((now - _last_pan_usec) / 1000000.0, 1.0 / 120.0, 0.1)
	var before := pan
	pan += offset
	_apply_camera()
	var sample := ((pan - before) / dt).limit_length(MAX_GLIDE_SPEED)
	pan_velocity = pan_velocity.lerp(sample, 1.0 - exp(-20.0 * dt))
	_last_pan_usec = now

func _release_pan(canceled := false) -> void:
	if canceled or zoom <= 1.0 or Time.get_ticks_usec() - _last_pan_usec > 100000:
		_stop_glide()

func _advance_glide(delta: float) -> void:
	if not enabled or zoom <= 1.0 or not fingers.is_empty() or mouse_down: return
	if pan_velocity.length() < MIN_GLIDE_SPEED:
		pan_velocity = Vector2.ZERO
		return
	var decay := exp(-PAN_FRICTION * delta)
	pan += pan_velocity * (1.0 - decay) / PAN_FRICTION
	pan_velocity *= decay
	_apply_camera()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_enabled(value: bool) -> void:
	enabled = value
	view.tap_mode = value
	view.end_drag()
	view.tap_item = -1
	view.selected_cell = -1
	fingers.clear()
	mouse_down = false
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	reset_camera()

func reset_camera() -> void:
	_stop_glide()
	zoom = 1.0
	pan = Vector2.ZERO
	_apply_camera()

func _process(delta: float) -> void:
	if size != old_size:
		old_size = size
		reset_camera()
	_advance_glide(delta)
	_apply_camera()

func _apply_camera() -> void:
	if not is_instance_valid(view): return
	var extent := (view.size * zoom - size).max(Vector2.ZERO) * 0.5
	var bounded := pan.clamp(-extent, extent)
	if bounded.x != pan.x: pan_velocity.x = 0.0
	if bounded.y != pan.y: pan_velocity.y = 0.0
	pan = bounded
	view.scale = Vector2.ONE * zoom
	view.position = (size - view.size * zoom) * 0.5 + pan

func _zoom_at(point: Vector2, factor: float) -> void:
	_stop_glide()
	var next := clampf(zoom * factor, 1.0, 4.0)
	pan = point - size * 0.5 - (point - size * 0.5 - pan) * next / zoom
	zoom = next
	_apply_camera()

func _tap(point: Vector2) -> void:
	view.tap_cell(view.cell_at((point - view.position) / zoom))

func _gui_input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventScreenTouch:
		if event.pressed:
			var was_gliding := pan_velocity.length() >= MIN_GLIDE_SPEED and fingers.is_empty()
			_stop_glide()
			fingers[event.index] = event.position
			press = event.position
			moved = fingers.size() > 1 or was_gliding
			view.end_drag()
		else:
			if fingers.has(event.index) and fingers.size() == 1 and not moved and not event.canceled:
				_tap(event.position)
			_release_pan(event.canceled or fingers.size() > 1)
			fingers.erase(event.index)
			moved = true # releasing the second finger must never select a piece
	elif event is InputEventScreenDrag:
		if not fingers.has(event.index): return
		var previous: Vector2 = fingers[event.index]
		if fingers.size() == 2:
			var other: Vector2 = fingers.values()[0] if fingers.keys()[1] == event.index else fingers.values()[1]
			var before := previous.distance_to(other)
			if before > 1:
				_zoom_at((previous + other) * 0.5, event.position.distance_to(other) / before)
			pan += (event.position - previous) * 0.5
			moved = true
		else:
			if event.position.distance_to(press) > 8: moved = true
			if moved: _pan_by(event.position - previous)
		fingers[event.index] = event.position
		_apply_camera()
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		_stop_glide() # Trackpads already provide momentum events.
		pan -= event.delta * 12
		_apply_camera()
	elif event is InputEventMouse and event.device != -1:
		if event is InputEventMouseButton:
			if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				_zoom_at(event.position, 1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				mouse_down = event.pressed
				if event.pressed:
					press = event.position
					moved = pan_velocity.length() >= MIN_GLIDE_SPEED
					_stop_glide()
					view.end_drag()
				else:
					_release_pan()
					if not moved: _tap(event.position)
		elif event is InputEventMouseMotion and mouse_down:
			if event.position.distance_to(press) > 8: moved = true
			if moved:
				_pan_by(event.relative)
	accept_event()
