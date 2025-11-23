extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var head_texture: TextureRect = $Head/TextureRect
@onready var torso_color_rect: ColorRect = $Torso/ColorRect
@onready var right_arm_color_rect: ColorRect = $"Right Arm/ColorRect"
@onready var right_hand_color_rect: ColorRect = $"Right Hand/ColorRect"
@onready var left_arm_color_rect: ColorRect = $"Left Arm/ColorRect"
@onready var left_hand_color_rect: ColorRect = $"Left Hand/ColorRect"

func _ready():
	# Randomize appearance
	randomize_appearance()
	
	# Add random delay (0-1 second) before starting wave animation to desync NPCs
	var random_delay = randf_range(0.0, 1.0)
	await get_tree().create_timer(random_delay).timeout
	
	# Start playing Wave animation on loop
	if animation_player:
		animation_player.play("Wave")
		# Connect to animation_finished to loop the animation
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(_anim_name: String):
	# Loop the Wave animation
	if animation_player:
		animation_player.play("Wave")

func randomize_appearance():
	# Randomize head (load random head texture)
	if head_texture:
		var head_count = 64  # Update this number as you add more head images
		var random_head_num = randi() % head_count + 1  # Random number from 1 to head_count
		var head_path = "res://Assets/Heads/Head" + str(random_head_num) + ".png"
		var head_image = load(head_path)
		if head_image:
			head_texture.texture = head_image
	
	# Randomize body (torso)
	if torso_color_rect:
		torso_color_rect.color = get_random_rainbow_color()
	
	# Randomize arms (same color for all arm parts)
	var arm_color = get_random_rainbow_color()
	if right_arm_color_rect:
		right_arm_color_rect.color = arm_color
	if right_hand_color_rect:
		right_hand_color_rect.color = arm_color
	if left_arm_color_rect:
		left_arm_color_rect.color = arm_color
	if left_hand_color_rect:
		left_hand_color_rect.color = arm_color
	
	# Legs and feet are optional (CarNPCs don't have them)
	# Only randomize if they exist in the scene
	if has_node("Right Leg/ColorRect") or has_node("Left Leg/ColorRect"):
		var leg_color = get_random_rainbow_color()
		if has_node("Right Leg/ColorRect"):
			get_node("Right Leg/ColorRect").color = leg_color
		if has_node("Right Foot/ColorRect"):
			get_node("Right Foot/ColorRect").color = leg_color
		if has_node("Left Leg/ColorRect"):
			get_node("Left Leg/ColorRect").color = leg_color
		if has_node("Left Foot/ColorRect"):
			get_node("Left Foot/ColorRect").color = leg_color

func get_random_rainbow_color() -> Color:
	var colors = [
		Color(1.0, 0.0, 0.0),    # Red
		Color(1.0, 0.5, 0.0),    # Orange
		Color(1.0, 1.0, 0.0),    # Yellow
		Color(0.0, 1.0, 0.0),    # Green
		Color(0.0, 0.0, 1.0),    # Blue
		Color(0.29, 0.0, 0.51),  # Indigo
		Color(0.58, 0.0, 0.83)   # Violet
	]
	return colors[randi() % colors.size()]
