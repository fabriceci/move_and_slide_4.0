extends CharacterBody2D
signal follow_platform(message)

@onready var raycast := $RayCast2D
var last_normal := Vector2.ZERO
var use_build_in := false
var auto := false

func _ready():
	$Camera2D.current = true

func _process(_delta):
	floor_snap_length = Global.SNAP_FORCE
	constant_speed_on_floor = Global.CONSTANT_SPEED_ON_FLOOR
	slide_on_ceiling = Global.SLIDE_ON_CEILING
	stop_on_floor_slope = Global.STOP_ON_SLOPE
	up_direction = Global.UP_DIRECTION
	move_on_floor_only = Global.MOVE_ON_FLOOR_ONLY
	floor_max_angle = Global.FLOOR_MAX_ANGLE
	update()

func _physics_process(delta):
	linear_velocity = linear_velocity + Global.GRAVITY_FORCE * delta
	if Global.APPLY_SNAP:
		floor_snap_length = Global.SNAP_FORCE
	else:
		floor_snap_length = 0
	if Input.is_action_just_pressed('ui_accept') and (Global.INFINITE_JUMP or util_on_floor()):
		linear_velocity.y = linear_velocity.y + Global.JUMP_FORCE
		floor_snap_length = 0
	
	var speed = Global.RUN_SPEED if Input.is_action_pressed('run') and util_on_floor() else Global.NORMAL_SPEED
	var direction = _get_direction()
	if direction.x:
		linear_velocity.x = direction.x * speed 
	elif util_on_floor():
		linear_velocity.x = move_toward(linear_velocity.x, 0, Global.GROUND_FRICTION)
	else:
		linear_velocity.x = move_toward(linear_velocity.x, 0, Global.AIR_FRICTION)
	
	if Input.is_action_just_pressed("ui_down"):
		auto = not auto
	if auto:
		linear_velocity.x = -speed
		
	if Global.SLOWDOWN_FALLING_WALL and util_on_wall() and linear_velocity.y > 0:
		linear_velocity.y = 70

	if use_build_in:
		var _collision = move_and_slide()
	else:
		gd_move_and_slide()


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

class CustomKinematicCollision2D:
	var position : Vector2
	var normal : Vector2
	var collider : Object
	var collider_velocity : Vector2
	var travel : Vector2
	var remainder : Vector2
	var collision_rid: RID
	
	func get_collider_rid():
		return collision_rid
	
func custom_move_and_collide(p_motion: Vector2, p_test_only: bool = false, p_cancel_sliding: bool = true, exlude = []):
	var gt := get_global_transform()
	
	var margin = get_safe_margin()
	
	var result := PhysicsTestMotionResult2D.new()
	var colliding := PhysicsServer2D.body_test_motion(get_rid(), gt, p_motion, margin, result, exlude)
	
	var result_motion := result.travel
	var result_remainder := result.remainder
	
	if p_cancel_sliding:

		var motion_length := p_motion.length()
		var precision := 0.001
		
		if colliding:
			# Can't just use margin as a threshold because collision depth is calculated on unsafe motion,
			# so even in normal resting cases the depth can be a bit more than the margin.
			precision = precision + motion_length * (result.collision_unsafe_fraction - result.collision_safe_fraction)

			if result.collision_depth > margin + precision:
				p_cancel_sliding = false

		if p_cancel_sliding:
			# When motion is null, recovery is the resulting motion.
			var motion_normal = Vector2.ZERO
			if motion_length > 0.00001:
				motion_normal = p_motion / motion_length
			
			# Check depth of recovery.
			var projected_length := result.travel.dot(motion_normal)
			var recovery := result.travel - motion_normal * projected_length
			var recovery_length := recovery.length()
			# Fixes cases where canceling slide causes the motion to go too deep into the ground,
			# Becauses we're only taking rest information into account and not general recovery.
			if recovery_length < margin + precision:
				# Apply adjustment to motion.
				result_motion = motion_normal * projected_length
				result_remainder = p_motion - result_motion
	
	if (not p_test_only):
		position = position + result_motion
	
	if colliding:
		var collision := CustomKinematicCollision2D.new()
		collision.position = result.collision_point
		collision.normal = result.collision_normal
		collision.collider = result.collider
		collision.collider_velocity = result.collider_velocity
		collision.travel = result_motion
		collision.remainder = result_remainder
		collision.collision_rid = result.collider_rid
		
		return collision
	else:
		return null

func gd_move_and_slide():
	var body_velocity_normal := linear_velocity.normalized()
	
	was_on_floor = on_floor
	
	var current_floor_velocity := floor_velocity
	if (on_floor or on_wall) and on_floor_body.get_id():
		var bs := PhysicsServer2D.body_get_direct_state(on_floor_body)
		if bs:
			current_floor_velocity = bs.linear_velocity
 
	on_floor = false
	on_ceiling = false
	on_wall = false
	floor_normal = Vector2()
	floor_velocity = Vector2()
	
	if current_floor_velocity != Vector2.ZERO: # apply platform movement first
		var platform_collision = custom_move_and_collide(current_floor_velocity * get_physics_process_delta_time(), false, false, [on_floor_body])
		if platform_collision:
			_set_collision_direction(platform_collision)

	on_floor_body = RID()
	var motion: Vector2 = linear_velocity * get_physics_process_delta_time()
 
	# No sliding on first attempt to keep motion stable when possible.
	var sliding_enabled := not stop_on_floor_slope
	for i in range(max_slides):
		
		var found_collision := false
		var collision = custom_move_and_collide(motion, false, not sliding_enabled)
		if not collision:
			motion = Vector2() #clear because no collision happened and motion completed
 
		if collision :
			last_normal = collision.normal # debug
			found_collision = true

			_set_collision_direction(collision)

			if on_floor and stop_on_floor_slope and collision.remainder.slide(up_direction).length() <= 0.01:
				if (body_velocity_normal.normalized() + up_direction).length() < 0.01 :
					if collision.travel.length() > get_safe_margin():
						position -= collision.travel.slide(up_direction)
					else:
						position -= collision.travel
					return Vector2()

			if sliding_enabled or not on_floor:
				motion = collision.remainder.slide(collision.normal)
				linear_velocity = linear_velocity.slide(collision.normal)
			else:
				motion = collision.remainder
		sliding_enabled = true
		if  not found_collision or motion == Vector2():
			break

	#custom_snap()
	return linear_velocity


func _set_collision_direction(collision):
	if acos(collision.normal.dot(up_direction)) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD:
		on_floor = true
		floor_normal = collision.normal
		floor_velocity = collision.collider_velocity
		if collision.collider.has_method("get_collision_layer"): # need a way to retrieve collision layer for tilemap
			on_floor_layer = collision.collider.get_collision_layer()
		on_floor_body = collision.get_collider_rid()

	elif acos(collision.normal.dot(-up_direction)) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD:
		on_ceiling = true
	else:
		floor_velocity = collision.collider_velocity
		if collision.collider.has_method("get_collision_layer"): # need a way to retrieve collision layer for tilemap
			on_floor_layer = collision.collider.get_collision_layer()
		on_floor_body = collision.get_collider_rid()
		on_wall = true
		
func custom_snap():
	if is_equal_approx(floor_snap_length, 0) or on_floor or not was_on_floor: return
	var collision = move_and_collide(up_direction * -floor_snap_length, true)
	
	if collision:
		var apply := true
		var travelled = collision.travel
		if up_direction != Vector2.ZERO:
			if acos(collision.normal.dot(up_direction)) <= floor_max_angle + FLOOR_ANGLE_THRESHOLD:
				on_floor = true
				floor_normal = collision.normal
				floor_velocity = collision.collider_velocity
				on_floor_body = collision.get_collider_rid()
				
				if stop_on_floor_slope:
					# move and collide may stray the object a bit because of pre un-stucking,
					# so only ensure that motion happens on floor direction in this case.
					#if travelled.length() > get_safe_margin() :
					travelled = up_direction * up_direction.dot(travelled);
			else:
				apply = false
		if apply:
			global_position = global_position + travelled

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
	var state = []
	if on_ceiling or is_on_ceiling():
		state.append("ceil")
	if on_floor or is_on_floor():
		state.append("floor")
	if on_wall or is_on_wall():
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
	return "Velocity " + str(linear_velocity)
	
static func _get_direction() -> Vector2:
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return direction
