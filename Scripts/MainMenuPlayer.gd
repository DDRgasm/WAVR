extends Node2D

# References to the bone nodes
@onready var arm: Bone2D = $Skeleton2D/Arm
@onready var forearm: Bone2D = $Skeleton2D/Arm/Forearm
@onready var hand: Bone2D = $Skeleton2D/Arm/Forearm/Hand

# Hide all non-skeleton nodes
@onready var target_zone: Node2D = $"Target Zone"
@onready var stats: Control = $"Stats"
@onready var level_result: Node2D = $"Level Result"
@onready var debug_text: Label = $"Debug Text"
@onready var stats_background: ColorRect = $"Stats Background"
@onready var hider: Node2D = $Hider
@onready var hider_colorect: ColorRect = $Hider/ColorRect
@onready var pause_menu: Node2D = $Hider/PauseMenu
@onready var loading_screen: Node2D = $Hider/LoadingScreen
@onready var credits_screen: Node2D = $Hider/Credits
@onready var pause_node: Node2D = $Pause

# Base rotation values (in radians) - the resting position
var base_arm_rotation: float = 1.5708  # 90 degrees (pointing down)
var base_forearm_rotation: float = 0.0
var base_hand_rotation: float = 0.0

# Current target rotations
var target_arm_rotation: float = 1.5708
var target_forearm_rotation: float = 0.0
var target_hand_rotation: float = 0.0

# Input parameters
var rotation_speed_tap: float = 0.15  # Angle increase per tap
var rotation_speed_hold: float = 3.0  # Angle increase per second when holding
var rotation_speed_hand: float = 10.0  # Rotation speed for hand
var return_speed: float = 2.0  # Speed at which angles return to base
var return_speed_arm: float = 1.8  # Shoulder returns slightly slower
var return_speed_forearm: float = 2.2  # Elbow returns slightly faster
var return_speed_hand: float = 10.0  # Hand returns fast

# Maximum rotation limits
var max_arm_rotation: float = deg_to_rad(270)
var min_arm_rotation: float = deg_to_rad(-90)
var max_forearm_rotation: float = deg_to_rad(150)
var min_forearm_rotation: float = deg_to_rad(-150)
var max_hand_rotation: float = deg_to_rad(75)
var min_hand_rotation: float = deg_to_rad(-75)

# Button hover state
var is_hovering_button: bool = false
var hover_arm_rotation: float = 0.0
var hover_forearm_rotation: float = 0.0
var hover_hand_rotation: float = 0.0

func _ready():
	# Initialize current rotations from the scene
	if arm:
		target_arm_rotation = arm.rotation
		base_arm_rotation = arm.rotation
	if forearm:
		target_forearm_rotation = forearm.rotation
		base_forearm_rotation = forearm.rotation
	if hand:
		target_hand_rotation = hand.rotation
		base_hand_rotation = hand.rotation
	
	# Hide UI elements
	if target_zone:
		target_zone.visible = false
	if stats:
		stats.visible = false
		# Also hide all children of Stats
		for child in stats.get_children():
			child.visible = false
	if stats_background:
		stats_background.visible = false
	if level_result:
		level_result.visible = false
	if debug_text:
		debug_text.visible = false
	
	# Hide pause node (button and background) in main menu
	if pause_node:
		pause_node.visible = false

func _process(delta: float):
	if is_hovering_button:
		# Snap to hover position
		target_arm_rotation = hover_arm_rotation
		target_forearm_rotation = hover_forearm_rotation
		target_hand_rotation = hover_hand_rotation
	else:
		# Normal input handling
		handle_input(delta)
	
	apply_rotations(delta)

func handle_input(delta: float):
	# Q - Increase arm rotation (shoulder joint)
	if Input.is_action_pressed("move_arm_up"):
		target_arm_rotation -= rotation_speed_hold * delta
		target_arm_rotation = clamp(target_arm_rotation, min_arm_rotation, max_arm_rotation)
	else:
		target_arm_rotation = move_toward(target_arm_rotation, base_arm_rotation, return_speed_arm * delta)
	
	# W - Increase forearm rotation (elbow joint)
	if Input.is_action_pressed("move_forearm_up"):
		target_forearm_rotation -= rotation_speed_hold * delta
		target_forearm_rotation = clamp(target_forearm_rotation, min_forearm_rotation, max_forearm_rotation)
	else:
		target_forearm_rotation = move_toward(target_forearm_rotation, base_forearm_rotation, return_speed_forearm * delta)
	
	# O - Rotate hand counterclockwise
	if Input.is_action_pressed("rotate_hand_ccw"):
		target_hand_rotation -= rotation_speed_hand * delta
		target_hand_rotation = clamp(target_hand_rotation, min_hand_rotation, max_hand_rotation)
	else:
		if target_hand_rotation < base_hand_rotation:
			target_hand_rotation = move_toward(target_hand_rotation, base_hand_rotation, return_speed_hand * delta)
	
	# P - Rotate hand clockwise
	if Input.is_action_pressed("rotate_hand_cw"):
		target_hand_rotation += rotation_speed_hand * delta
		target_hand_rotation = clamp(target_hand_rotation, min_hand_rotation, max_hand_rotation)
	else:
		if target_hand_rotation > base_hand_rotation:
			target_hand_rotation = move_toward(target_hand_rotation, base_hand_rotation, return_speed_hand * delta)

func apply_rotations(delta: float):
	# Smoothly interpolate to target rotations
	if arm:
		arm.rotation = lerp_angle(arm.rotation, target_arm_rotation, 10.0 * delta)
	
	if forearm:
		forearm.rotation = lerp_angle(forearm.rotation, target_forearm_rotation, 10.0 * delta)
	
	if hand:
		hand.rotation = lerp_angle(hand.rotation, target_hand_rotation, 25.0 * delta)

func set_hover_pose(arm_deg: float, forearm_deg: float, hand_deg: float):
	is_hovering_button = true
	hover_arm_rotation = deg_to_rad(arm_deg)
	hover_forearm_rotation = deg_to_rad(forearm_deg)
	hover_hand_rotation = deg_to_rad(hand_deg)

func clear_hover_pose():
	is_hovering_button = false

# Hider system for credits
enum HiderMode {
	NONE,
	PAUSE,
	LOADING,
	CREDITS
}

var current_hider_mode: HiderMode = HiderMode.NONE

func show_hider(mode: int):
	print("MainMenuPlayer: show_hider called with mode: ", mode)
	current_hider_mode = mode as HiderMode
	
	if not hider:
		print("MainMenuPlayer: ERROR - hider not found")
		return
	
	# Show hider background
	hider.visible = true
	if hider_colorect:
		hider_colorect.visible = true
	
	# Hide all mode screens first
	if pause_menu:
		pause_menu.visible = false
	if loading_screen:
		loading_screen.visible = false
	if credits_screen:
		credits_screen.visible = false
	
	# Show the appropriate screen based on mode
	match current_hider_mode:
		HiderMode.PAUSE:
			if pause_menu:
				pause_menu.visible = true
		HiderMode.LOADING:
			if loading_screen:
				loading_screen.visible = true
		HiderMode.CREDITS:
			if credits_screen:
				credits_screen.visible = true
				print("MainMenuPlayer: Credits screen shown")

func hide_hider():
	print("MainMenuPlayer: hide_hider called")
	current_hider_mode = HiderMode.NONE
	if hider:
		hider.visible = false
