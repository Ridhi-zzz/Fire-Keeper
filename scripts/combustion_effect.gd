extends Node2D

var age: float = 0.0
var duration: float = 0.48
var misfire_style: bool = false

func _ready() -> void:
	z_index = 500

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := clampf(age / duration, 0.0, 1.0)
	var alpha := 1.0 - progress
	var radius := lerpf(12.0, 112.0, progress)
	var main_color := Color("#FF5638") if misfire_style else Color("#FF9A32")
	draw_circle(Vector2.ZERO, radius, Color(main_color.r, main_color.g, main_color.b, 0.12 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(main_color.r, main_color.g, main_color.b, 0.95 * alpha), 7.0 * (1.0 - progress) + 1.0, true)
	var highlight_color := Color("#FFE49A") if not misfire_style else Color("#FFB0A0")
	highlight_color.a = 0.8 * alpha
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 48, highlight_color, 3.0, true)
	for i in range(10):
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / 10.0 + 0.2)
		var inner := direction * radius * 0.55
		var outer := direction * radius * 0.95
		draw_line(inner, outer, Color(main_color.r, main_color.g, main_color.b, alpha), 3.0, true)
