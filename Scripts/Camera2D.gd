extends Camera2D


export var min_zoom := 0.5

export var max_zoom := 2.0

export var zoom_factor := .1

export var zoom_duration := 0.2

var _zoom_level := 400.0 setget _set_zoom_level

onready var tween: Tween = $Tween

func _set_zoom_level(value: float) -> void:
	_zoom_level = clamp(value, min_zoom, max_zoom)
	tween.interpolate_property(
		self,
		"zoom",
		zoom,
		Vector2(_zoom_level, _zoom_level),
		zoom_duration,
		tween.TRANS_SINE,
		tween.EASE_OUT
	)
	tween.start()
	
func _set_y_position(value: float) -> void:
	position.y += value
func _set_x_position(value: float) -> void:
	position.x += value
	
func _unhandled_input(event):
	
	if event.is_action_pressed("zoom_in"):
		_set_zoom_level(_zoom_level-zoom_factor)
	if event.is_action_pressed("zoom_out"):
		_set_zoom_level(_zoom_level+zoom_factor)
	if event.is_action("down"):
		_set_y_position(1*_zoom_level)
	if event.is_action("up"):
		_set_y_position(-1*_zoom_level)
	if event.is_action("left"):
		_set_x_position(-1*_zoom_level)
	if event.is_action("right"):
		_set_x_position(1*_zoom_level)
		
