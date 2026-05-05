extends Control

@export var float_speed: float = 1.5
@export var float_amplitude: float = 15.0
@export var rotate_speed: float = 0.5
@export var rotate_amplitude: float = 5.0

var start_pos: Vector2
var time: float = 0.0
var offset_time: float = 0.0

func _ready():
	start_pos = position
	offset_time = randf() * 10.0 # Randomize start phase

func _process(delta):
	time += delta
	var current_time = time + offset_time
	
	# Floating motion
	var y_offset = sin(current_time * float_speed) * float_amplitude
	var x_offset = cos(current_time * float_speed * 0.7) * (float_amplitude * 0.5)
	position = start_pos + Vector2(x_offset, y_offset)
	
	# Rotation motion
	rotation_degrees = sin(current_time * rotate_speed) * rotate_amplitude
