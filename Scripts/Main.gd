extends Node2D

var paused = false

#Gravitational Constant
export(float) var G:float = 6.674e-11
export var speedFactor = 1000
#Theta to control accuracy of simulation lower is more accurate
export var theta = 1.0
#Size of spawn area and quadtree area * 4
export var areaSize = 100000
#Deviation from spawn area
export var spawnRandomness = 500
export var numParticles = 1000
#Velocity tangent to center point
export var startingVel = 1.0
#Mass of spawned particles in exponent notation 1eX
export var massRange = Vector2(18, 19)
#Draw the quadtree grid
export var drawGrid = false
#Allow particle Collsion
export var collisions = true

onready var mass_scene = load("res://Scenes/MassObject.tscn")
#Array of all particles
var n_array = []
#split array for threading
var tn_arrays = []
var currentTn_Array


var d_array = []


var deltaTime = 0

#Threading variables
export var useThreading = true
var threads = []
export var numThreads = 1
var semaphore

#QuadTree Stuff
var _rootQuadTree = null
var _bodies = []

# Called when the node enters the scene tree for the first time.
func _ready():

	VisualServer.set_default_clear_color(Color(0, 0, 0, 1.0))
	#Setup Threads for physics
	for i in range(numThreads):
		threads.append(Thread.new())
		tn_arrays.append([])
	semaphore = Semaphore.new()
	
	set_process(true)
	set_process_input(true)

	#Translate from scientfic notation
	massRange.x = pow(10, massRange.x)
	massRange.y = pow(10, massRange.y)
	
	#QuadTree setup
	var bounds = Rect2(Vector2(-areaSize, -areaSize), Vector2(areaSize*2, areaSize*2))
	_rootQuadTree = get_node("QuadTree").create_quadtree(bounds, 1, 10, 0, theta, G, collisions)
	
	seed(OS.get_time().second)
	#Add the Earth sized object to array
	n_array.append(get_node("Node2D"))
	
	for i in range(numParticles):
		var n = mass_scene.instance()
		n.set_name(str(i))
		n.position = Vector2((areaSize/4+rand_range(-spawnRandomness, spawnRandomness))*cos(i+rand_range(0, 1)), 
		(areaSize/4+rand_range(-spawnRandomness, spawnRandomness))*sin(i+rand_range(0, 1)))

		n.mass = rand_range(massRange.x, massRange.y)
		n.density = 6000
		n.setScale()
		n.velocity = Vector2(startingVel*cos(i+1.570796), startingVel*sin(i+1.570796))
		n_array.append(n)
		add_child(n)
		_bodies.append(n)
		_rootQuadTree.add_body(n)
	_rootQuadTree.compute_mass_distribution()

	#Split up the particles based on number of threads
	rebuild_tnArray()
# Called every frame. 'delta' is the elapsed time since the previous frame.
	
func _process(delta):
	if !paused:
			
		var i = 0
		if useThreading:
			for t in threads:
				currentTn_Array = tn_arrays[i]
				#Calculate force for each particle
				t.start(self, "calcForce", currentTn_Array)
				#This print command is absolutely vital to the function of the threads
				#print("thread " + str(i) + " created")
				i+=1
			for t in threads:
				t.wait_to_finish()
		else:
			calcForce(n_array)
			
		#Delete Collided particles and update positions
		for j in n_array:
			#Update position
			j.updatePosVel(delta, speedFactor)
			
			if j.del == true:
				n_array.erase(j)
				remove_child(j)
		
		rebuild_tnArray()

		calc_tree(delta)
		
		#rebuild mass tree for Barnes-Hut Equation
		_rootQuadTree.compute_mass_distribution()


	
func _draw():
	if drawGrid:
		var points = _rootQuadTree.get_rect_lines()
		_draw_root(points)

func calc_tree(delta):
	deltaTime += delta
	#don't recalc every frame
	if deltaTime >= .1:
		_rootQuadTree.clear()
		for body in n_array:
			#add bodies to the quadtree
			_rootQuadTree.add_body(body)
		deltaTime = 0
		update()

func calcForce(array):
	for i in array:
		if i.del:
			continue
		_rootQuadTree.calculate_force(i)
	
func _draw_root(points):
	#Draw the quad tree
	var i = 0
	while(i<points.size()):
		draw_line(points[i], points[i+1], Color(0, 1, 0), 500)
		draw_line(points[i+1], points[i+2], Color(0, 1, 0), 500)
		draw_line(points[i+2], points[i+3], Color(0, 1, 0), 500)
		draw_line(points[i+3], points[i], Color(0, 1, 0), 500)
		i+= 4


func rebuild_tnArray():
	#Resplit the array 
	var begin = 0
	var end = n_array.size()/threads.size()
	var iterAmount = end
	for i in threads.size():
		var a = n_array.slice(begin, end)
		tn_arrays[i] = a
		begin = end
		end += iterAmount
		# to handle arrays that aren't evenly divisable
		if i == threads.size()-2:
			end = n_array.size()-1

func _exit_tree():
	for t in threads:
		t.wait_to_finish()
		

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		paused = !paused
	
