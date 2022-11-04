extends Node2D

@onready var n_pause_label = $CanvasLayer/Control/PauseLabel
@onready var n_pause_label_help = $CanvasLayer/Control/PauseLabelHelp
const Player: PackedScene = preload("res://Player/Current/Player.tscn")
var player_position := Vector2.ZERO
var current_index := -1
var tmp_air_friction = Global.AIR_FRICTION
var slow_mo := [1.0, 0.05, 0.005]
var slow_mo_idx := 0

func _ready():
	get_tree().debug_collisions_hint = true
	$CanvasLayer/Control/FloorMaxAngleLabel.text = "Floor max angle: %.0f°" % round(rad_to_deg(Global.FLOOR_MAX_ANGLE)) 
	$CanvasLayer/Control/StopButton.button_pressed = Global.FLOOR_STOP_ON_SLOPE
	$CanvasLayer/Control/SnapLengthSlider.value = Global.FLOOR_SNAP_LENGTH
	$CanvasLayer/Control/FloorMaxAngleSlider.value = rad_to_deg(Global.FLOOR_MAX_ANGLE)
	$CanvasLayer/Control/ConstantButton.button_pressed = Global.FLOOR_CONSTANT_SPEED
	$CanvasLayer/Control/SlideCeilingButton.button_pressed = Global.SLIDE_ON_CEILING
	$CanvasLayer/Control/BlockOnWallButton.button_pressed = Global.FLOOR_BLOCK_ON_WALL
	$CanvasLayer/Control/TDMinSlideAngleSlider.value = rad_to_deg(Global.WALL_MIN_SLIDE_ANGLE)
	
	$CanvasLayer/Control/SlowdownButton.button_pressed = Global.SLOWDOWN_FALLING_WALL
	$CanvasLayer/Control/InfiniteJumpButton.button_pressed = Global.INFINITE_JUMP
	$CanvasLayer/Control/AirFrictionButton.button_pressed = Global.AIR_FRICTION
	
func _process(_delta):
	if Input.is_action_just_pressed('slow'):
		slow_mo_idx += 1
		Engine.time_scale = slow_mo[slow_mo_idx % slow_mo.size()]
	
func _physics_process(_delta):
	if not $Player: return
	var linear_vel : Vector2 = (player_position - $Player.global_position) / get_physics_process_delta_time()
	player_position = $Player.global_position

	$CanvasLayer/Control/HUDLabel.text = "FPS " + str(Engine.get_frames_per_second()) + '\n'
	$CanvasLayer/Control/HUDLabel.text += "Position " + str($Player.global_position) + '\n'
	$CanvasLayer/Control/HUDLabel.text += "Real Vel " + str(linear_vel) + ' Length %.0f \n' % round(linear_vel.length())
	$CanvasLayer/Control/HUDLabel.text += $Player.get_velocity_str() + '\n'
	$CanvasLayer/Control/HUDLabel.text += "State: " + $Player.get_state_str()
	if $Player.raycast.is_colliding():
		$CanvasLayer/Control/HUDLabel.text += "\nSlope angle: %.3f°" % rad_to_deg(acos($Player.raycast.get_collision_normal().dot(Vector2.UP)))
	if Engine.time_scale != 1.0:
		$CanvasLayer/Control/HUDLabel.text += "\nTime scale : %.3f" % Engine.time_scale
	if current_index == 0:
		if $Player.on_floor:
			$CanvasLayer/Control/HUDLabel.text += "\nFloor normal: " + str($Player.floor_normal)
	$CanvasLayer/Control/HUDLabel.text += "\nPlatform: " + str($Player.get_platform_velocity())
	if $Player.motion_mode == 1:
		$CanvasLayer/Control/HUDLabel.text += "\nTop Down angle: %.1f °" % rad_to_deg($Player.debug_top_down_angle)

func _on_StopButton_toggled(button_pressed):
	Global.FLOOR_STOP_ON_SLOPE = button_pressed

func _on_SnapButton_toggled(button_pressed):
	Global.APPLY_SNAP = button_pressed

func _on_ConstantButton_toggled(button_pressed):
	Global.FLOOR_CONSTANT_SPEED = button_pressed

func _on_SlideCeilingButton_toggled(button_pressed):
	Global.SLIDE_ON_CEILING = button_pressed

func _on_InfiniteJumpButton_toggled(button_pressed):
	Global.INFINITE_JUMP = button_pressed

func _on_SlowdownButton_toggled(button_pressed):
	Global.SLOWDOWN_FALLING_WALL = button_pressed
	
func _on_block_on_wall_button_toggled(button_pressed: bool) -> void:
	Global.FLOOR_BLOCK_ON_WALL = button_pressed


func _on_AirFrictionButton_toggled(button_pressed):
	if button_pressed:
		Global.AIR_FRICTION = tmp_air_friction
	else:
		Global.AIR_FRICTION = 0
	
func ui_options(p_visible: bool):
	$CanvasLayer/Control/StopButton.visible = p_visible
	$CanvasLayer/Control/SnapLengthLabel.visible = p_visible
	$CanvasLayer/Control/SnapLengthSlider.visible = p_visible
	$CanvasLayer/Control/BlockOnWallButton.visible = p_visible
	$CanvasLayer/Control/InfiniteJumpButton.visible = p_visible
	$CanvasLayer/Control/AirFrictionButton.visible = p_visible
	$CanvasLayer/Control/SlowdownButton.visible = p_visible
	$CanvasLayer/Control/ConstantButton.visible = p_visible
	$CanvasLayer/Control/SlideCeilingButton.visible = p_visible
	$CanvasLayer/Control/FloorMaxAngleLabel.visible = p_visible
	$CanvasLayer/Control/FloorMaxAngleSlider.visible = p_visible
	$CanvasLayer/Control/TDMinSlideAngleLabel.visible = not p_visible
	$CanvasLayer/Control/TDMinSlideAngleSlider.visible = not p_visible

func _on_FloorMaxAngleSlider_value_changed(value):
	$CanvasLayer/Control/FloorMaxAngleLabel.text = "Floor max angle: %.0f°" % round(value) 
	Global.FLOOR_MAX_ANGLE = deg_to_rad(value)

func _on_BlockOnWall_toggled(button_pressed):
	Global.FLOOR_BLOCK_ON_WALL = button_pressed

func _on_ModeTDButton_toggled(button_pressed):
	Global.MODE_FREE = button_pressed
	
	ui_options(not button_pressed)

func _on_TDMinSlideAngleSlider_value_changed(value):
	$CanvasLayer/Control/TDMinSlideAngleLabel.text = "Min slide angle: %.0f°" % round(value) 
	Global.WALL_MIN_SLIDE_ANGLE = deg_to_rad(value)

func _on_snap_length_slider_value_changed(value: float) -> void:
	$CanvasLayer/Control/SnapLengthLabel.text = "Snap Length: %.0f°" % round(value) 
	Global.FLOOR_SNAP_LENGTH = value
