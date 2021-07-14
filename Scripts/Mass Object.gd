extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
export var vScale:float = 1000000000
export(float) var mass:float = 5.9736e24
export var density:float = 6000
export var velocity = Vector2(0, 0)
export var can_move:bool = true

onready var scaleAmount : float = (mass/(density))


var center
var rad
var col
var del = false
var force = Vector2()

# Called when the node enters the scene tree for the first time.
func _ready():
	setScale()
	center = Vector2(0,0)
	col = Color(1, 1, 1)	
	
func updatePosVel(delta, speedFactor):
	if can_move:
		position+=velocity*delta*speedFactor
		velocity += (force*delta*speedFactor)
	
func _draw():
	setScale()
	draw_circle(center, scaleAmount, col)
		
		
func setScale():
	scaleAmount = (mass/(density*vScale))
	scaleAmount = pow(((.75)*scaleAmount/PI), 1.0/3.0)
	rad = scaleAmount
	update()
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
