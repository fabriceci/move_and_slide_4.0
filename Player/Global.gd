extends Node

var use_default_move := true

# player
var GRAVITY_FORCE := Vector2(0, 2000)
var NORMAL_SPEED := 800
var RUN_SPEED := 1300
var GROUND_FRICTION := 1000
var AIR_FRICTION := 1000
var JUMP_FORCE := -1000
var INFINITE_JUMP := true
var SLOWDOWN_FALLING_WALL := false

# move and slide
var APPLY_SNAP := true
var SNAP_FORCE := 50.0
var CONSTANT_SPEED_ON_FLOOR := true
var STOP_ON_SLOPE := true
var MOVE_MAX_ANGLE :=  deg2rad(45.0)
var FLOOR_MAX_ANGLE := deg2rad(45.0)
var UP_DIRECTION := Vector2.UP
var SLIDE_ON_CEILING := true
