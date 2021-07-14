extends Node2D

#Barnes-Hut information https://beltoforion.de/en/barnes-hut-galaxy-simulator/
#GDscript quadtree code heavily modified from https://github.com/AggressiveGaming/Godot-QuadTree

  
#Copyright (c) 2017 Jake E.
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

func create_quadtree(bounds, splitThreshold, splitLimit, currentSplit = 0, theta = 1, G = 6.674e-11, collisions = true):
	return _QuadTreeClass.new(self, bounds, splitThreshold, splitLimit, currentSplit, theta, G, collisions)

class _QuadTreeClass:
	
	var _bounds = Rect2(Vector2(), Vector2())
	var _splitThreshold = 10
	var _maxSplits = 5
	var _curSplit = 0
	var _bodies = []
	var _quadrants = []
	var _drawMat = null
	var _node = null
	var mass = 0
	var center_of_mass = Vector2(0, 0)
	var _theta = .5
	var G:float
	var collision
	
	func _init(node, bounds, splitThreshold, maxSplits, currentSplit = 0, theta = 1.0, G = 6.674e-11, collisions = true):
		_node = node
		_bounds = bounds
		_splitThreshold = splitThreshold
		_maxSplits = maxSplits
		_curSplit = currentSplit
		_theta = theta
		self.G = G
		collision = collisions
		
		
	func clear():
		for quadrant in _quadrants:
			quadrant.clear()
		_bodies.clear()
		_quadrants.clear()
		
	func add_body(body):
		if(_quadrants.size() != 0):
			var quadrant = _get_quadrant(body.position)
			quadrant.add_body(body)

		else:
			_bodies.append(body)
			if(_bodies.size() > _splitThreshold && _curSplit < _maxSplits):
				_split()
					
	func _contains_circle(center, radius):
		var bc = (_bounds.pos + _bounds.end)/2
		var dx = abs(center.x - bc.x)
		var dy = abs(center.y - bc.y)
		if(dx>(_bounds.size.x/2+radius)):return false
		if(dy>(_bounds.size.y/2+radius)):return false
		if(dx <= (_bounds.size.x / 2)): return true
		if(dy <= (_bounds.size.y / 2)): return true
		var cornerDist = pow((dx - _bounds.size.x / 2), 2) + pow((dy - _bounds.size.y / 2), 2);
		return cornerDist <= (radius * radius);


	func _split():
		""" Splits the QuadTree into 4 quadrants and disperses its bodies amongst them. """
		var hx = _bounds.size.x / 2
		var hy = _bounds.size.y / 2
		var sz = Vector2(hx, hy)

		var aBounds = Rect2(_bounds.position, sz)
		var bBounds = Rect2(Vector2(_bounds.position.x + hx, _bounds.position.y), sz)
		var cBounds = Rect2(Vector2(_bounds.position.x + hx, _bounds.position.y + hy), sz)
		var dBounds = Rect2(Vector2(_bounds.position.x, _bounds.position.y + hy), sz)
		
		var splitNum = _curSplit + 1
		
		_quadrants.append(_node.create_quadtree(aBounds, _splitThreshold, _maxSplits, splitNum, _theta, G, collision))
		_quadrants.append(_node.create_quadtree(bBounds, _splitThreshold, _maxSplits, splitNum, _theta, G, collision))
		_quadrants.append(_node.create_quadtree(cBounds, _splitThreshold, _maxSplits, splitNum, _theta, G, collision))
		_quadrants.append(_node.create_quadtree(dBounds, _splitThreshold, _maxSplits, splitNum, _theta, G, collision))

		for body in _bodies:
			var quadrant = _get_quadrant(body.position)
			quadrant.add_body(body)
		_bodies.clear()


	func _get_quadrant(location):
		""" Gets the quadrant a Vector2 location lies in. """
		if(location.x > _bounds.position.x + _bounds.size.x / 2):
			if(location.y > _bounds.position.y + _bounds.size.y / 2):
				return _quadrants[2]
			else:
				return _quadrants[1]
		else:
			if(location.y > _bounds.position.y + _bounds.size.y / 2): 
				return _quadrants[3]
			return _quadrants[0]
		pass
	
	
	func get_rect_lines():
		""" Gets all rect line points of this quadrant and its children. """
		var points = []
		_get_rect_lines(points)
		return points


	func _get_rect_lines(points):
		for quadrant in _quadrants:
			quadrant._get_rect_lines(points)
			
		var p1 = Vector2(_bounds.position.x, _bounds.position.y)
		var p2 = Vector2(p1.x + _bounds.size.x, p1.y)
		var p3 = Vector2(p1.x + _bounds.size.x, p1.y + _bounds.size.y)
		var p4 = Vector2(p1.x, p1.y + _bounds.size.y)
		points.append(p1)
		points.append(p2)
		points.append(p3)
		points.append(p4)
		
	func compute_mass_distribution():
		center_of_mass = Vector2(0, 0)
		mass = 0
		if _bodies.size() == 1:
			center_of_mass = _bodies[0].position
			mass = _bodies[0].mass
		else:
			for q in _quadrants:
				q.compute_mass_distribution()
				mass += q.mass
				center_of_mass += q.mass * q.center_of_mass
			center_of_mass = center_of_mass / (mass+1)
			
	func calculate_force(particle):
		var force = Vector2()

		if particle.del == true:
			return force
		
		if mass == 0:
			return force

		if _bodies.size() > 0:
			for body in _bodies:
				if body == particle:
					continue
				

				var dist = body.position.distance_to(particle.position)
				collisionCheck(dist, particle, body)
		
				var f = ((G*body.mass)/((dist*dist)*particle.vScale))
				var angle = (particle.position-body.position).angle()
				force += Vector2(f*-cos(angle), f*-sin(angle))
			
		else:
			var r = center_of_mass.distance_to(particle.position)
			var s = _bounds.size.x
			if(s/(r+1) < _theta):
				var f = ((G*mass)/((r*r)*particle.vScale))
				var angle = (particle.position-center_of_mass).angle()
				force = Vector2(f*-cos(angle), f*-sin(angle))
			else:
				force += searchTree(particle)
			
		particle.force = force
		return force

	func searchTree(particle):
		var f = Vector2()
		for quadrant in _quadrants:
			if quadrant.mass == 0 && quadrant._quadrants.size() == 0:
				continue
			f += quadrant.calculate_force(particle)
		return f
	

	func collisionCheck(dist, particle, body):
		if !collision:
			return
		#			if (dist < i.scaleAmount || dist < j.scaleAmount) && (abs(i.velocity.x - j.velocity.x)>1 || abs(i.velocity.y - j.velocity.y)>1):
		if(dist < particle.scaleAmount || dist < body.scaleAmount) && (abs(particle.velocity.x - body.velocity.x)>1 || abs(particle.velocity.y - body.velocity.y)>1):
			var m = particle.mass + body.mass
			var density = particle.density
			if body.density > density:
				density = body.density
			
			
			var n = particle
			var d = body
			if n.mass < d.mass:
				n = body
				d = particle

			n.mass = m
			n.density = density
			n.setScale()
			d.del = true
