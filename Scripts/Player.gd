
extends KinematicBody2D

const LEFT = 0
const RIGHT = 1
const UP_LEFT = Vector2(-1 / sqrt(1 + 1.5*1.5), -1.5 / sqrt(1 + 1.5*1.5))
const UP_RIGHT = Vector2(1 / sqrt(1 + 1.5*1.5), -1.5 / sqrt(1 + 1.5*1.5))

class State:
	var velocity = Vector2(0, 0)
	var states = {}
	
	func _init(class_dict):
		states = class_dict
	
	func tick(obj, delta):
		return _tick(obj, delta)
	
	func _tick(obj, delta):
		var state = self
		if Input.is_action_pressed("player_jump"):
			state = state._jump_held(obj, delta)
		return state._movement(obj, delta)
	
	func _movement(obj, delta):
		return self
	
	func _jump_held(obj, delta):
		return self
	
	func _jump_pressed(obj):
		return self
	
	func jump(obj):
		return _jump_pressed(obj)
	
	func _get_name():
		return "Base"
	
	func get_name():
		return _get_name()
	
	func target_x_vel(obj):
		var target = 0
		if Input.is_action_pressed("player_left"):
			target -= obj.speed
		if Input.is_action_pressed("player_right"):
			target += obj.speed
		return target

class GroundedState extends State:
	func _init(states, init_velocity).(states):
		velocity = init_velocity
	
	func _movement(obj, delta):
		var target_x_vel = target_x_vel(obj)
		var x_diff = target_x_vel - velocity.x
		velocity.x += x_diff * delta * obj.acc_factor
		if abs(velocity.x) < 0.0001:
			velocity.x = 0
		
		# Initial movement
		var vel_start = obj.get_pos()
		# Ground motion only uses x velocity
		var remainder = obj.move(delta * Vector2(velocity.x, 0))
		if obj.is_colliding():
			var normal = obj.get_collision_normal()
			var deflected = remainder.length() * normal.slide(remainder).normalized()
			obj.move(deflected)
			if abs(normal.x) > 0.999:
				velocity.x = 0
		
		# Falling test / Hug slopes
		var hug_vector = Vector2(0, obj.slope_hug_factor * obj.speed * delta)
		if obj.test_move(hug_vector):
			var remainder = obj.move(hug_vector)
			# Don't hug too closely or movement will be breaky
			if abs(remainder.y - hug_vector.y) < 0.001:
				obj.revert_motion()
			var vel_end = obj.get_pos()
			var effective_vel = (vel_end - vel_start).normalized() * abs(velocity.x)
			velocity.y = effective_vel.y
			return self
		else:
			return states["air"].new(states, velocity)
	
	func _jump_held(obj, delta):
		velocity.y = max(velocity.y - obj.jump_impulse, -obj.jump_impulse)
		return states["air"].new(states, velocity)
	
	func _get_name():
		return "Ground"

class AirState extends State:
	var elapsed = 0
	
	func _init(states, init_velocity).(states):
		velocity = init_velocity
	
	func _movement(obj, delta):
		elapsed += delta
		
		var target_x_vel = target_x_vel(obj)
		var x_diff = target_x_vel - velocity.x
		velocity.y += delta * obj.gravity
		velocity.x += x_diff * delta * obj.acc_factor * 0.2
		if abs(velocity.x) < 0.0001:
			velocity.x = 0
		
		# Fall
		var remainder = obj.move(delta * velocity)
		if obj.is_colliding():
			var normal = obj.get_collision_normal()
			if normal.y < 0: # Touched ground
				obj.move(normal.slide(remainder))
				velocity = normal.slide(velocity)
				velocity.y = 0
				return states["ground"].new(states, velocity)
			elif (velocity.y > 0 or abs(obj.get_travel().x) > delta * 10) and normal.y < 0.1:
				# Wall touch
				if normal.x < 0 and Input.is_action_pressed("player_right"):
					velocity = Vector2(0,0)
					return states["wall"].new(states, RIGHT)
				elif normal.x > 0 and Input.is_action_pressed("player_left"):
					velocity = Vector2(0,0)
					return states["wall"].new(states, LEFT)
				else:
					obj.move(normal.slide(remainder))
					velocity = normal.slide(velocity)
					return self
			else:
				obj.move(normal.slide(remainder))
				velocity = normal.slide(velocity)
				return self
		else:
			return self
	
	func _get_name():
		return "Air"

class WallState extends State:
	var dir
	
	func _init(states, init_dir).(states):
		dir = init_dir
	
	func movement_shared(obj, delta):
		velocity.y += delta * obj.gravity * 0.5
		var remainder = obj.move(velocity * delta)
		if obj.is_colliding():
			var normal = obj.get_collision_normal()
			if normal.y < 0:
				obj.move(normal.slide(remainder))
				velocity = normal.slide(velocity)
				return states["ground"].new(states, velocity)
			else:
				return self
		else:
			return self
	
	func _movement(obj, delta):
		if dir == LEFT:
			var contact = obj.test_move(Vector2(-0.1, 0))
			if !(Input.is_action_pressed("player_left") and contact):
				return states["air"].new(states, velocity)
			else:
				return movement_shared(obj, delta)
		else:
			var contact = obj.test_move(Vector2(0.1, 0))
			if !(Input.is_action_pressed("player_right") and contact):
				return states["air"].new(states, velocity)
			else:
				return movement_shared(obj, delta)
	func _jump_pressed(obj):
		if dir == LEFT:
			velocity = UP_RIGHT * obj.jump_impulse * 1.2
		else:
			velocity = UP_LEFT * obj.jump_impulse * 1.2
		return states["air"].new(states, velocity)
	
	func _get_name():
		if dir == LEFT:
			return "Wall Left"
		else:
			return "Wall Right"

class Movement:
	var state
	func _init(init_state):
		state = init_state
	
	func tick(obj, delta):
		var res = state.tick(obj, delta)
		if res == null:
			print("Error: null state from " + state.get_name())
			breakpoint
		state = res
	
	func jump(obj):
		state = state.jump(obj)
	
	func get_state_name():
		return state.get_name()

var states = {
	"ground" : GroundedState,
	"air"    : AirState,
	"wall"   : WallState,
	}

export var gravity = 1000
export var speed = 300
export var acc_factor = 5.0
export var jump_impulse = 500
export var slope_hug_factor = 1.5
var movement = Movement.new(GroundedState.new(states, Vector2(0,0)))

func _ready():
	set_process(true)
	set_fixed_process(true)
	set_process_unhandled_key_input(true)

func _unhandled_key_input(key_event):
	if key_event.is_action_pressed("player_jump"):
		movement.jump(self)

func _process():
	pass

func _fixed_process(delta):
	movement.tick(self, delta)


