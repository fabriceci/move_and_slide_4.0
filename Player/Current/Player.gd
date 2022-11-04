extends CharacterBody2D

@onready var raycast := $RayCast2D
var debug_top_down_angle:= 0.0
var debug_last_normal = Vector2.ZERO
var debug_last_motion = Vector2.ZERO
var debug_auto_move := false

func _ready():
	$Camera2D.current = true

func _process(_delta):
	floor_snap_length = Global.FLOOR_SNAP_LENGTH
	floor_constant_speed = Global.FLOOR_CONSTANT_SPEED
	slide_on_ceiling = Global.SLIDE_ON_CEILING
	floor_stop_on_slope = Global.FLOOR_STOP_ON_SLOPE
	up_direction = Global.UP_DIRECTION
	floor_block_on_wall = Global.FLOOR_BLOCK_ON_WALL
	floor_max_angle = Global.FLOOR_MAX_ANGLE
	wall_min_slide_angle = Global.WALL_MIN_SLIDE_ANGLE
	motion_mode = 1 if Global.MODE_FREE else 0

	queue_redraw()

var UP_DIRECTION := Vector2.UP

func _physics_process(delta):
	if motion_mode == 0: # side mode
		velocity = velocity + Global.GRAVITY_FORCE * delta
		if Global.APPLY_SNAP:
			floor_snap_length = Global.FLOOR_SNAP_LENGTH
		else:
			floor_snap_length = 0
		if Input.is_action_just_pressed('ui_accept') and (Global.INFINITE_JUMP or is_on_floor()):
			velocity.y = velocity.y + Global.JUMP_FORCE
		var speed = Global.RUN_SPEED if Input.is_action_pressed('run') and is_on_floor() else Global.NORMAL_SPEED
		var direction = _get_direction()
		if direction.x:
			velocity.x = direction.x * speed
		elif is_on_floor():
			velocity.x = move_toward(velocity.x, 0, Global.GROUND_FRICTION)
		else:
			velocity.x = move_toward(velocity.x, 0, Global.AIR_FRICTION)

		if Input.is_action_just_pressed("ui_down"):
			debug_auto_move = not debug_auto_move
		if debug_auto_move:
			velocity.x = -Global.RUN_SPEED

		if Global.SLOWDOWN_FALLING_WALL and on_wall and velocity.y > 0:
			var vel_x = velocity.slide(Global.UP_DIRECTION).normalized()
			var dot = get_slide_collision(0).normalized().dot(vel_x)
			if is_equal_approx(dot, -1):
				velocity.y = 70
	else:
		var speed = Global.RUN_SPEED if Input.is_action_pressed('run')  else Global.NORMAL_SPEED
		var direction = _get_direction()
		direction = direction.normalized()

		if direction.x:
			velocity.x = direction.x * speed
		if direction.y:
			velocity.y = direction.y * speed

		if direction.x == 0:
			velocity.x = move_toward(velocity.x, 0, Global.GROUND_FRICTION)
		if direction.y == 0:
			velocity.y = move_toward(velocity.y, 0, Global.GROUND_FRICTION)

	var _collided = move_and_slide()


var on_floor := false
var platform_rid :=  RID()
var platform_layer:int
var on_ceiling := false
var on_wall = false
var floor_normal := Vector2.ZERO
var platform_velocity := Vector2.ZERO
var FLOOR_ANGLE_THRESHOLD := 0.01
var was_on_floor = false

func _draw():
	var icon_pos : Vector2 = $icon.position
	icon_pos.y = icon_pos.y - 50
	draw_line(icon_pos, icon_pos + velocity.normalized() * 50, Color.GREEN, 1.5)
	draw_line(icon_pos, icon_pos + debug_last_normal * 50, Color.RED, 1.5)
	if debug_last_motion != velocity.normalized():
		draw_line(icon_pos, icon_pos + debug_last_motion * 50, Color.ORANGE, 1.5)
	
func get_state_str():
	var state = []
	if is_on_ceiling():
		state.append("ceil")
	if is_on_floor():
		state.append("floor")
	if is_on_wall():
		state.append("wall")

	if state.size() == 0:
		state.append("air")
	return array_join(state, " & ")

func array_join(arr : Array, glue : String = '') -> String:
	var string : String = ''
	for index in range(0, arr.size()):
		string += str(arr[index])
		if index < arr.size() - 1:
			string += glue
	return string

func get_velocity_str():
	return "Velocity " + str(velocity)

func _get_direction() -> Vector2:
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return direction
