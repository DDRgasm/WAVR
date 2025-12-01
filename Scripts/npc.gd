extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var emote_texture: TextureRect = $"Feedback Box/TextureRect"
@onready var head_texture: TextureRect = $Head/TextureRect
@onready var torso_color_rect: ColorRect = $Torso/ColorRect
@onready var right_arm_color_rect: ColorRect = $"Right Arm/ColorRect"
@onready var right_hand_color_rect: ColorRect = $"Right Hand/ColorRect"
@onready var left_arm_color_rect: ColorRect = $"Left Arm/ColorRect"
@onready var left_hand_color_rect: ColorRect = $"Left Hand/ColorRect"
@onready var right_leg_color_rect: ColorRect = $"Right Leg/ColorRect"
@onready var right_foot_color_rect: ColorRect = $"Right Foot/ColorRect"
@onready var left_leg_color_rect: ColorRect = $"Left Leg/ColorRect"
@onready var left_foot_color_rect: ColorRect = $"Left Foot/ColorRect"

enum State {
	MOVING_TO_WAIT,
	WAITING,
	WAVING,
	MOVING_TO_EXIT
}

enum Archetype {
	BASIC,
	BUSY,
	OBLIVIOUS,
	ANGRY
}

var current_state: State = State.MOVING_TO_WAIT
var target_position: Vector2 = Vector2.ZERO
var move_duration: float = 0.0
var move_timer: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var archetype: Archetype = Archetype.BASIC
var current_level: int = 1  # Track which level this NPC is in

# Wait timeout
var base_wait_time: float = 8.0
var wait_timer: float = 0.0
var is_waiting_for_player: bool = false

# Emote textures
var emote_watching: Texture2D
var emote_awkward: Texture2D
var emote_happy: Texture2D
var emote_angry_watching: Texture2D
var emote_mad: Texture2D

signal reached_wait_slot
signal reached_exit_slot
signal wave_complete
signal wait_timeout

func _ready():
	start_position = global_position
	
	# Load emote textures
	emote_watching = load("res://Assets/NPC Watching.png")
	emote_awkward = load("res://Assets/NPC Awkward.png")
	emote_happy = load("res://Assets/NPC Happy.png")
	emote_angry_watching = load("res://Assets/NPC Angry Watching.png")
	emote_mad = load("res://Assets/NPC Mad.png")
	
	# Hide emote by default
	if emote_texture:
		emote_texture.visible = false
	
	# Randomize appearance
	randomize_appearance()

func _process(delta: float):
	if current_state == State.MOVING_TO_WAIT or current_state == State.MOVING_TO_EXIT:
		move_timer += delta
		var t = clamp(move_timer / move_duration, 0.0, 1.0)
		global_position = start_position.lerp(target_position, t)
		
		if t >= 1.0:
			if current_state == State.MOVING_TO_WAIT:
				arrive_at_wait_slot()
			elif current_state == State.MOVING_TO_EXIT:
				arrive_at_exit()
	
	# Handle wait timeout
	if is_waiting_for_player and current_state == State.WAITING:
		wait_timer += delta
		if wait_timer >= get_wait_timeout():
			timeout_from_wait()

func move_to_wait_slot(target_pos: Vector2, duration: float):
	current_state = State.MOVING_TO_WAIT
	start_position = global_position
	target_position = target_pos
	move_duration = duration
	move_timer = 0.0
	
	if animation_player:
		if current_level == 5:
			animation_player.play("BusinessWalk")
		else:
			animation_player.play("Walk")

func arrive_at_wait_slot():
	current_state = State.WAITING
	if animation_player:
		animation_player.stop()
	
	# Start wait timeout timer
	is_waiting_for_player = true
	wait_timer = 0.0
	
	reached_wait_slot.emit()

func play_wave():
	current_state = State.WAVING
	stop_wait_timer()  # Stop waiting timer when catch succeeds
	
	# Angry NPCs play Rude animations instead of waving
	if archetype == Archetype.ANGRY:
		if animation_player:
			# 75% chance for Rude, 25% chance for Rude2
			var rand = randf()
			if rand < 0.75:
				animation_player.play("Rude")
			else:
				animation_player.play("Rude2")
			# Wait for animation to finish
			await animation_player.animation_finished
			wave_complete.emit()
		else:
			await get_tree().create_timer(3.0).timeout
			wave_complete.emit()
	else:
		if animation_player:
			# Randomly select from Wave, Wave2, or Wave3 (1/3 chance each)
			var rand = randf()
			var wave_anim = "Wave"
			if rand < 0.333:
				wave_anim = "Wave"
			elif rand < 0.666:
				wave_anim = "Wave2"
			else:
				wave_anim = "Wave3"
			
			animation_player.play(wave_anim)
			# Wait for animation to finish
			await animation_player.animation_finished
			wave_complete.emit()

func move_to_exit(exit_pos: Vector2, duration: float):
	current_state = State.MOVING_TO_EXIT
	start_position = global_position
	target_position = exit_pos
	move_duration = duration
	move_timer = 0.0
	
	if animation_player:
		if current_level == 5:
			animation_player.play("BusinessWalk")
		else:
			animation_player.play("Walk")

func arrive_at_exit():
	if animation_player:
		animation_player.stop()
	reached_exit_slot.emit()

func is_waiting() -> bool:
	return current_state == State.WAITING

func set_archetype(new_archetype: Archetype):
	archetype = new_archetype

func get_archetype() -> Archetype:
	return archetype

func get_catch_initiation_multiplier() -> float:
	if archetype == Archetype.OBLIVIOUS:
		return 3.0
	return 1.0

func get_wait_time_multiplier() -> float:
	if archetype == Archetype.OBLIVIOUS:
		return 3.0
	elif archetype == Archetype.BUSY:
		return 0.5
	return 1.0

func get_wait_timeout() -> float:
	return base_wait_time * get_wait_time_multiplier()

func stop_wait_timer():
	is_waiting_for_player = false
	wait_timer = 0.0

func timeout_from_wait():
	is_waiting_for_player = false
	wait_timeout.emit()

func get_catch_value_multiplier() -> float:
	if archetype == Archetype.BUSY or archetype == Archetype.ANGRY:
		return 2.0  # Progress fills 2x faster (lower catch value needed)
	return 1.0

func get_catch_time_multiplier() -> float:
	if archetype == Archetype.BUSY:
		return 0.5  # Half the time
	return 1.0

func is_angry() -> bool:
	return archetype == Archetype.ANGRY

func show_emote_watching():
	if emote_texture:
		if archetype == Archetype.ANGRY:
			emote_texture.texture = emote_angry_watching
		else:
			emote_texture.texture = emote_watching
		emote_texture.visible = true

func show_emote_awkward():
	if emote_texture:
		emote_texture.texture = emote_awkward
		emote_texture.visible = true

func show_emote_happy():
	if emote_texture:
		emote_texture.texture = emote_happy
		emote_texture.visible = true

func show_emote_mad():
	if emote_texture:
		emote_texture.texture = emote_mad
		emote_texture.visible = true

func hide_emote():
	if emote_texture:
		emote_texture.visible = false

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
	
	# Randomize legs (same color for all leg parts)
	var leg_color = get_random_rainbow_color()
	if right_leg_color_rect:
		right_leg_color_rect.color = leg_color
	if right_foot_color_rect:
		right_foot_color_rect.color = leg_color
	if left_leg_color_rect:
		left_leg_color_rect.color = leg_color
	if left_foot_color_rect:
		left_foot_color_rect.color = leg_color

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
