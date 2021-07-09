extends CharacterBody2D
signal follow_platform(message)

@onready var raycast := $RayCast2D
var last_normal = Vector2.ZERO
var use_build_in = false

# Move and slide
var move_on_floor_only: bool = false
var constant_speed_on_floor: bool = false
var slide_on_ceiling: bool = true
var exclude_body_layer := []

func _process(_delta):
	snap = Global.SNAP_FORCE
	constant_speed_on_floor = Global.CONSTANT_SPEED_ON_FLOOR
	slide_on_ceiling = Global.SLIDE_ON_CEILING
	move_on_floor_only = Global.MOVE_ON_FLOOR_ONLY
	stop_on_slope = Global.STOP_ON_SLOPE
	up_direction = Global.UP_DIRECTION
	floor_max_angle = Global.FLOOR_MAX_ANGLE
	update()

func _physics_process(delta):
	linear_velocity += Global.GRAVITY_FORCE * delta
	if Global.APPLY_SNAP:
		snap = Global.SNAP_FORCE
	else:
		snap = Vector2.ZERO
	if Input.is_action_just_pressed('ui_accept') and (Global.INFINITE_JUMP or util_on_floor()):
		linear_velocity.y += Global.JUMP_FORCE
		snap = Vector2.ZERO
	
	var speed = Global.RUN_SPEED if Input.is_action_pressed('run') and util_on_floor() else Global.NORMAL_SPEED
	var direction = _get_direction()
	if direction.x:
		linear_velocity.x = direction.x * speed 
	elif util_on_floor():
		linear_velocity.x = move_toward(linear_velocity.x, 0, Global.GROUND_FRICTION)
	else:
		linear_velocity.x = move_toward(linear_velocity.x, 0, Global.AIR_FRICTION)
	
	if Global.SLOWDOWN_FALLING_WALL and util_on_wall() and linear_velocity.y > 0:
		linear_velocity.y = 70

	if use_build_in:
		move_and_slide()
	else:
		gd_move_and_slide()
	
	if util_on_floor():
		linear_velocity.y = 0	

var on_floor := false
var on_floor_body:= RID()
var on_floor_layer:int
var on_ceiling := false
var on_wall = false
var on_air = false
var floor_normal := Vector2()
var floor_velocity := Vector2()
var FLOOR_ANGLE_THRESHOLD := 0.01
var was_on_floor = false

func gd_move_and_slide():
	var body_velocity_normal := linear_velocity.normalized()
	
	was_on_floor = on_floor
	
	var current_floor_velocity := floor_velocity
	if on_floor and on_floor_body.get_id():
		var bs := PhysicsServer2D.body_get_direct_state(on_floor_body)
		if bs:
			current_floor_velocity = bs.linear_velocity
 
	var motion: Vector2 = (current_floor_velocity + linear_velocity) * get_physics_process_delta_time()
 
	on_floor = false
	on_floor_body = RID()
	on_ceiling = false
	on_wall = false
	floor_normal = Vector2()
	floor_velocity = Vector2()
 
	# No sliding on first attempt to keep motion stable when possible.
	var sliding_enabled := false
	for i in range(max_slides):
		
		var found_collision := false
		var collision = move_and_collide(motion, infinite_inertia, true, false, not sliding_enabled)
		if not collision:
			motion = Vector2() #clear because no collision happened and motion completed
 
		if collision :
			last_normal = collision.normal # debug
			found_collision = true

			if up_direction == Vector2():
				# all is a wall
				on_wall = true;
			else :
				if (acos(collision.normal.dot(up_direction)) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD): # floor
 
					on_floor = true
					floor_normal = collision.normal
					var collision_object := collision.collider as CollisionObject2D
					on_floor_body = collision_object.get_rid()
					floor_velocity = collision.collider_velocity
				
					if stop_on_slope:
						if (body_velocity_normal + up_direction).length() < 0.01:
							#if collision.travel.length() > get_safe_margin():
							#	position -= collision.travel.slide(up_direction)
							#else:
							position -= collision.travel

				elif (acos(collision.normal.dot(-up_direction)) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD) : #ceiling
					on_ceiling = true;
				else:
					on_wall = true;
			if sliding_enabled or not on_floor:
				motion = collision.remainder.slide(collision.normal)
				linear_velocity = linear_velocity.slide(collision.normal)
			else:
				motion = collision.remainder
		sliding_enabled = true
		if  not found_collision or motion == Vector2():
			break

	custom_snap()
	return linear_velocity

func custom_snap():
	if snap == Vector2.ZERO or on_floor or not was_on_floor: return
	var collision = move_and_collide(snap, infinite_inertia, false, true)
	
	if collision:
		var apply := true
		var travelled = collision.travel
		if up_direction != Vector2.ZERO:
			if acos(collision.normal.dot(up_direction)) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD:
				on_floor = true
				floor_normal = collision.normal
				floor_velocity = collision.collider_velocity
				on_floor_body = collision.get_collider_rid()
				
				if stop_on_slope:
					# move and collide may stray the object a bit because of pre un-stucking,
					# so only ensure that motion happens on floor direction in this case.
					#if travelled.length() > get_safe_margin() :
					travelled = up_direction * up_direction.dot(travelled);
			else:
				apply = false
		if apply:
			print(apply)
			global_position += travelled

func _draw():
	var icon_pos = $icon.position
	icon_pos.y -= 50
	draw_line(icon_pos, icon_pos + linear_velocity.normalized() * 50, Color.GREEN, 1.5)
	draw_line(icon_pos, icon_pos + last_normal * 50, Color.RED, 1.5)
	
func util_on_floor():
	return is_on_floor() or on_floor

func util_on_wall():
	return is_on_wall() or on_wall

func get_state_str():
	if on_ceiling or is_on_ceiling(): return "ceil"
	if on_wall or is_on_wall(): return "wall"
	if on_floor or is_on_floor(): return "floor"
	return "air"
	
func get_velocity_str():
	return "Velocity " + str(linear_velocity)
	
static func _get_direction() -> Vector2:
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return direction
