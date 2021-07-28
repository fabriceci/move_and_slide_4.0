extends Node

var paused = false
var step_once = false

func _physics_process(_delta):
	if Input.is_action_just_pressed('pause'):
		paused = !paused
		get_tree().paused = paused
		step_once = false
		if paused:
			owner.n_pause_label.text = "PAUSE MODE"
		else:
			owner.n_pause_label.text = ""
	
	if paused:
		if step_once:
			get_tree().paused = true
			step_once = false
		elif Input.is_action_just_pressed('step'):
			# step once
			get_tree().paused = false
			step_once = true
