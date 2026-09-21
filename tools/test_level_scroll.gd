extends SceneTree
var failures := 0
var taps := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scroll = load("res://scripts/ui/level_scroll.gd").new()
	scroll.size = Vector2(300, 300)
	scroll.scale = Vector2(2, 2)
	root.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for i in 20:
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 70)
		button.pressed.connect(func(): taps += 1)
		rows.add_child(button)
	for i in 5: await process_frame
	scroll.set_process(false)
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	bar.value = 100
	scroll._begin(0, Vector2(150, 300))
	scroll._move(Vector2(150, 200))
	check(is_equal_approx(bar.value, 150), "100 screen pixels equals 50 local pixels at 2x scale")
	var mouse := InputEventMouseMotion.new()
	mouse.device = -1
	mouse.position = Vector2(150, 200)
	mouse.relative = Vector2(0, -100)
	scroll._input(mouse)
	check(is_equal_approx(bar.value, 150), "Emulated mouse cannot double touch scrolling")
	scroll._end(Vector2(150, 200), false)
	check(taps == 0, "Drag across level button never opens level")
	var speed: float = absf(scroll.velocity)
	scroll._process(0.05)
	check(bar.value > 150 and absf(scroll.velocity) < speed, "Inertia continues and decays")
	scroll._begin(0, Vector2(150, 200))
	check(scroll.velocity == 0, "Touch stops inertia")
	scroll._end(Vector2(150, 200), false)
	check(taps == 0, "Stopping inertia cannot activate a level")
	scroll._begin(0, Vector2(150, 200))
	scroll._end(Vector2(150, 200), false)
	check(taps == 1, "Stationary tap still opens a level")
	bar.value = bar.max_value - bar.page
	scroll.velocity = 1000
	scroll._process(0.1)
	check(scroll.velocity == 0, "Momentum stops at list edge")
	print("LEVEL SCROLL FAILURES: ", failures)
	quit(failures)
