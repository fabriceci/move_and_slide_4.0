extends CharacterBody2D
signal follow_platform(message)

@onready var raycast := $RayCast2D
var last_normal = Vector2.ZERO
var last_motion = Vector2.ZERO

# Move and slide
var move_on_floor_only: bool = false
var constant_speed_on_floor: bool = false
var slide_on_ceiling: bool = true
var exclude_body_layer := []

func _process(delta):
	snap = Global.SNAP_FORCE
	constant_speed_on_floor = Global.CONSTANT_SPEED_ON_FLOOR
	slide_on_ceiling = Global.SLIDE_ON_CEILING
	move_on_floor_only = Global.MOVE_ON_FLOOR_ONLY
	stop_on_slope = Global.STOP_ON_SLOPE
	up_direction = Global.UP_DIRECTION
	floor_max_angle = Global.FLOOR_MAX_ANGLE
	update()

var UP_DIRECTION := Vector2.UP

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
	
	if Global.SLOWDOWN_FALLING_WALL and on_wall and linear_velocity.y > 0:
		var velX = linear_velocity.slide(Global.UP_DIRECTION).normalized()
		var dot = wall_normal.normalized().dot(velX)
		if is_equal_approx(dot, -1):
			linear_velocity.y = 70
	custom_move_and_slide()
	
	if util_on_floor():
		linear_velocity.y = 0	

var on_floor := false
var on_floor_body:=  RID()
var on_floor_layer:int
var on_ceiling := false
var on_wall = false
var on_air = false
var floor_normal := Vector2()
var floor_velocity := Vector2()
var FLOOR_ANGLE_THRESHOLD := 0.01
var was_on_floor = false
var wall_normal := Vector2()
var ceilling_normal := Vector2()

func custom_move_and_slide():
	var current_floor_velocity = Vector2.ZERO
	if on_floor:
		var excluded = false
		for layer in exclude_body_layer:
			if on_floor_layer & (1 << layer) != 0:
				excluded = true
		if not excluded:
			current_floor_velocity = floor_velocity
			if on_floor_body:

				var bs := PhysicsServer2D.body_get_direct_state(on_floor_body)
				if bs:
					current_floor_velocity = bs.linear_velocity

	if current_floor_velocity != Vector2.ZERO: # apply platform movement first
		move_and_collide(current_floor_velocity * get_physics_process_delta_time(), infinite_inertia, true, false)
		emit_signal("follow_platform", str(current_floor_velocity * get_physics_process_delta_time()))
	else:
		emit_signal("follow_platform", "/")
			
	var original_motion = linear_velocity * get_physics_process_delta_time()
	var motion = original_motion
	
	var prev_floor_velocity = floor_velocity
	var prev_floor_body = on_floor_body
	var prev_floor_normal = floor_normal
	was_on_floor = on_floor
	on_floor = false
	on_floor_body = RID()
	on_ceiling = false
	on_wall = false
	on_air = false

	floor_velocity = Vector2()
	floor_normal = Vector2()
	wall_normal = Vector2()
	ceilling_normal = Vector2()
	
	# No sliding on first attempt to keep floor motion stable when possible.
	var sliding_enabled := not stop_on_slope
	var first_slide := true
	var can_apply_constant_speed := false
	var prev_travel := Vector2()
	
	for _i in range(max_slides):
		var continue_loop = false
		var previous_pos = position
		var collision = move_and_collide(motion, infinite_inertia, true, false)

		if collision:
			last_normal = collision.normal # for debug

			if up_direction == Vector2():
				on_wall = true;
			else :
				if acos(collision.normal.dot(up_direction)) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD:
					on_floor = true
					floor_normal = collision.normal
					floor_velocity = collision.collider_velocity
					if collision.collider.has_method("get_collision_layer"): # need a way to retrieve collision layer for tilemap
						on_floor_layer = collision.collider.get_collision_layer()
					on_floor_body = collision.get_collider_rid()
					
					if stop_on_slope and collision.remainder.slide(up_direction).length() <= 0.01:
						if (original_motion.normalized() + up_direction).length() < 0.01 :
							if collision.travel.length() > get_safe_margin():
								position -= collision.travel.slide(up_direction)
							else:
								position -= collision.travel
							return Vector2()

				elif acos(collision.normal.dot(-up_direction)) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD:
					ceilling_normal = collision.normal
					on_ceiling = true
				else:
					floor_velocity = collision.collider_velocity
					if collision.collider.has_method("get_collision_layer"): # need a way to retrieve collision layer for tilemap
						on_floor_layer = collision.collider.get_collision_layer()
					on_floor_body = collision.get_collider_rid()
					wall_normal = collision.normal
					on_wall = true
			
			if not on_floor:
				sliding_enabled = true
			
			# compute motion
			# constant speed
			if on_floor and constant_speed_on_floor and can_apply_constant_speed:
					var slide: Vector2 = collision.remainder.slide(collision.normal).normalized()
					if not slide.is_equal_approx(Vector2.ZERO):
						motion = slide * (original_motion.slide(up_direction).length() - collision.travel.slide(up_direction).length() - prev_travel.slide(up_direction).length())  # alternative use original_motion.length() to also take account of the y value
			# prevent to move against wall
			elif on_wall and move_on_floor_only and original_motion.normalized().dot(collision.normal) < 0:
				if collision.travel.dot(up_direction) > 0 and was_on_floor and linear_velocity.dot(up_direction) <= 0 : # prevent the move against wall
					position -= up_direction * up_direction.dot(collision.travel) # remove the x from the vector when up direction is Vector2.UP
					on_wall = false
					wall_normal = Vector2.ZERO
					on_floor = true
					on_floor_body = prev_floor_body	
					floor_velocity = prev_floor_velocity
					if collision.collider.has_method("get_collision_layer"): # need a way to retrieve collision layer for tilemap
						on_floor_layer = collision.collider.get_collision_layer()
					floor_normal = prev_floor_normal
					#custom_snap(snap, up_direction, stop_on_slope, floor_max_angle, infinite_inertia) # need to test if really needed
					return Vector2.ZERO
				elif move_on_floor_only and sliding_enabled: # prevent to move against the wall in the air
					motion = up_direction * up_direction.dot(collision.remainder)
					motion = motion.slide(collision.normal)
				else:
					motion = collision.remainder
			elif sliding_enabled and not (on_ceiling and not slide_on_ceiling and linear_velocity.dot(up_direction) > 0):
				motion = collision.remainder.slide(collision.normal)
				if slide_on_ceiling and on_ceiling and linear_velocity.dot(up_direction) > 0:
					linear_velocity = linear_velocity.slide(collision.normal)
				elif slide_on_ceiling and on_ceiling: # remove x when fall to avoid acceleration
					linear_velocity = up_direction * up_direction.dot(linear_velocity) 
			else:
				motion = collision.remainder
				if on_ceiling and not slide_on_ceiling and linear_velocity.dot(up_direction) > 0:
					linear_velocity = linear_velocity.slide(up_direction)
					motion = motion.slide(up_direction)
					
		else:
			can_apply_constant_speed = first_slide
			if snap != Vector2.ZERO and was_on_floor:
				var apply_constant_speed : bool = constant_speed_on_floor and prev_floor_normal != Vector2.ZERO and can_apply_constant_speed
				var tmp_position = position
				if apply_constant_speed:
					position = previous_pos
				custom_snap()
				if apply_constant_speed and on_floor and motion != Vector2.ZERO:
					var slide: Vector2 = motion.slide(prev_floor_normal).normalized()
					if not slide.is_equal_approx(Vector2.ZERO):
						motion = slide * (original_motion.slide(up_direction).length())  # alternative use original_motion.length() to also take account of the y value
						continue_loop = true
				elif apply_constant_speed:
					position = tmp_position
		
		sliding_enabled = true
		can_apply_constant_speed = not can_apply_constant_speed and sliding_enabled
		first_slide = false
		
		if collision:
			prev_travel = collision.travel

		if not collision and not on_floor: 
			on_air = true

		# debug
		if not motion.is_equal_approx(Vector2()): last_motion = motion.normalized() 
			
		if not continue_loop and (not collision or motion.is_equal_approx(Vector2())):
			break
		
	if not on_floor and not on_wall:
		linear_velocity += current_floor_velocity # Add last floor velocity when just left a moving platform

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
			position += travelled

func _draw():
	var icon_pos : Vector2 = $icon.position
	icon_pos.y = icon_pos.y - 50
	draw_line(icon_pos, icon_pos + linear_velocity.normalized() * 50, Color.GREEN, 1.5)
	draw_line(icon_pos, icon_pos + last_normal * 50, Color.RED, 1.5)
	if last_motion != linear_velocity.normalized():
		draw_line(icon_pos, icon_pos + last_motion * 50, Color.ORANGE, 1.5)
	
func util_on_floor():
	return is_on_floor() or on_floor

func get_state_str():
	if on_ceiling: return "ceil"
	if on_wall: return "wall"
	if on_floor: return "floor"
	if on_air: return "air"
	return "unknow"

func get_velocity_str():
	return "Velocity " + str(linear_velocity)
	
static func _get_direction() -> Vector2:
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return direction
