extends Node2D

@onready var n_pol2D = $Level/Base/Polygon2D
@onready var n_collisionPol2D = $Level/Base/CollisionPolygon2D
const PlayerClassic: PackedScene = preload("res://Player/Current/Player.tscn")
const PlayerCustom: PackedScene = preload("res://Player/New/NewPlayer.tscn")
var player_position := Vector2.ZERO
var current_index := -1
var tmp_air_friction = Global.AIR_FRICTION
var slow_mo := [1.0, 0.05, 0.005]
var slow_mo_idx := 0
var platform_velocity = ""

func _ready():
#	$Level/Base/CollisionPolygon2D.polygon = $Level/Base/Polygon2D.polygon
	$CanvasLayer/Control/ModeItemList.select(0)
	set_mode(0)
	
func _process(_delta):
	if Input.is_action_just_pressed('slow'):
		slow_mo_idx += 1
		Engine.time_scale = slow_mo[slow_mo_idx % slow_mo.size()]
	
func _physics_process(delta):
	if not $Player: return
	var linear_vel : Vector2 = (player_position - $Player.global_position) / get_physics_process_delta_time()
	player_position = $Player.global_position
	
	$CanvasLayer/Control/HUDLabel.text = "FPS " + str(Engine.get_frames_per_second()) + '\n'
	$CanvasLayer/Control/HUDLabel.text += "Position " + str($Player.global_position) + '\n'
	$CanvasLayer/Control/HUDLabel.text += "Linear Vel " + str(linear_vel) + ' Length %.3f \n' % linear_vel.length()
	$CanvasLayer/Control/HUDLabel.text += $Player.get_velocity_str() + '\n'
	$CanvasLayer/Control/HUDLabel.text += "State: " + $Player.get_state_str()
	if $Player.raycast.is_colliding():
		$CanvasLayer/Control/HUDLabel.text += "\nSlope angle: %.3f°" % rad2deg(acos($Player.raycast.get_collision_normal().dot(Vector2.UP)))
	if Engine.time_scale != 1.0:
		$CanvasLayer/Control/HUDLabel.text += "\nTime scale : %.3f" % Engine.time_scale
	if current_index == 0:
		if $Player.on_wall:
			$CanvasLayer/Control/HUDLabel.text += "\nWall normal: " + str($Player.wall_normal)
		elif $Player.on_floor:
			$CanvasLayer/Control/HUDLabel.text += "\nFloor normal: " + str($Player.floor_normal)
	$CanvasLayer/Control/HUDLabel.text += "\nPlatform: " + platform_velocity
	

func _on_StopButton_toggled(button_pressed):
	Global.STOP_ON_SLOPE = button_pressed

func _on_SnapButton_toggled(button_pressed):
	Global.APPLY_SNAP = button_pressed

func _on_ConstantButton_toggled(button_pressed):
	Global.CONSTANT_SPEED_ON_FLOOR = button_pressed

func _on_MoveOnFloorButton_toggled(button_pressed):
	Global.MOVE_ON_FLOOR_ONLY = button_pressed

func _on_SlideCeilingButton_toggled(button_pressed):
	Global.SLIDE_ON_CEILING = button_pressed

func _on_InfiniteJumpButton_toggled(button_pressed):
	Global.INFINITE_JUMP = button_pressed

func _on_SlowdownButton_toggled(button_pressed):
	Global.SLOWDOWN_FALLING_WALL = button_pressed

func _on_AirFrictionButton_toggled(button_pressed):
	if button_pressed:
		Global.AIR_FRICTION = tmp_air_friction
	else:
		Global.AIR_FRICTION = 0

func _on_ModeItemList_item_selected(index):
	set_mode(index)

func set_mode(index: int):
	if current_index != index:
		current_index = index
		var _instance: CharacterBody2D
		if index == 0 or index == 2:
			_instance = PlayerCustom.instantiate()
			ui_options(true)
		else:
			ui_options(false)
		if index == 1 or index == 2:
			_instance = PlayerClassic.instantiate()
		if index == 2:
			_instance.use_build_in = true
		if has_node("Player"):
			remove_child(get_node("Player"))
		if index == 0:
			var _silent = _instance.connect("follow_platform", on_platform_signal)
		add_child(_instance)
		
		_instance.position = player_position

func on_platform_signal(message):
	platform_velocity = message
	
func ui_options(p_visible: bool):
	$CanvasLayer/Control/ConstantButton.visible = p_visible
	$CanvasLayer/Control/MoveOnFloorButton.visible = p_visible
	$CanvasLayer/Control/SlideCeilingButton.visible = p_visible
