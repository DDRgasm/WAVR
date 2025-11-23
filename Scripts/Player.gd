extends Node2D

# Signals for NPC interaction
signal catch_succeeded
signal catch_failed
signal level_ended

# References to the bone nodes
@onready var arm: Bone2D = $Skeleton2D/Arm
@onready var forearm: Bone2D = $Skeleton2D/Arm/Forearm
@onready var hand: Bone2D = $Skeleton2D/Arm/Forearm/Hand

# Wave gameplay references
@onready var hand_hitbox: Area2D = $Skeleton2D/Arm/Forearm/Hand/Area2D
@onready var critical_hitbox: Area2D = $"Skeleton2D/Arm/Forearm/Hand/Critical Hitbox"
@onready var big_target: Area2D = $"Target Zone/Big Target"
@onready var center_target: Area2D = $"Target Zone/Center Target"
@onready var tl_target: Area2D = $"Target Zone/TopLeft Target"
@onready var tr_target: Area2D = $"Target Zone/TopRight Target"
@onready var bl_target: Area2D = $"Target Zone/BottomLeft Target"
@onready var br_target: Area2D = $"Target Zone/BottomRight Target"
@onready var timer_pips_container: Node2D = $"Target Zone/Timer Pips"
@onready var wave_backs_label: Label = $"Stats/Clear Condition/Wave Backs"
@onready var clear_condition_label: Label = $"Stats/Clear Condition/Clear Condition"
@onready var timer_label: Label = $"Stats/Timer/Timer"
@onready var hider: Node2D = $Hider
@onready var fail_x_label: Label = $"Target Zone/Feedback/FailX"
@onready var success_plus_label: Label = $"Target Zone/Feedback/SuccessPlus"
@onready var angry_minus_label: Label = $"Target Zone/Feedback/AngryMinus"
@onready var level_result_node: Node2D = $"Level Result"
@onready var level_result_label: Label = $"Level Result/Label"
@onready var debug_text_label: Label = $"Debug Text"

# Quadrant lock HUDs
@onready var tl_quadrant_hud: Node2D = $"Target Zone/Feedback/TopLeftQuadrantHUD"
@onready var tr_quadrant_hud: Node2D = $"Target Zone/Feedback/TopRightQuadrantHUD4"
@onready var bl_quadrant_hud: Node2D = $"Target Zone/Feedback/BottomLeftQuadrantHUD3"
@onready var br_quadrant_hud: Node2D = $"Target Zone/Feedback/BottomRightQuadrantHUD2"

# Debug mode
var debug_mode: bool = false

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
var rotation_speed_hand: float = 10.0  # Rotation speed for hand (O and P keys) - faster and snappier
var return_speed: float = 2.0  # Speed at which angles return to base (radians per second)
var return_speed_arm: float = 1.8  # Shoulder returns slightly slower
var return_speed_forearm: float = 2.2  # Elbow returns slightly faster
var return_speed_hand: float = 10.0  # Hand returns fast

# Maximum rotation limits (to prevent unrealistic movements)
var max_arm_rotation: float = deg_to_rad(270)  # Can rotate up to 270 degrees (much larger arc)
var min_arm_rotation: float = deg_to_rad(-90)  # Can go down to -90 degrees

var max_forearm_rotation: float = deg_to_rad(150)
var min_forearm_rotation: float = deg_to_rad(-150)

var max_hand_rotation: float = deg_to_rad(75)
var min_hand_rotation: float = deg_to_rad(-75)

# Wave Gameplay variables
var input_enabled: bool = true  # Controls whether player can use input
var can_catch: bool = false  # Controlled by level manager based on NPC state
var catch_active: bool = false
var catch_value: float = 0.0  # Current catch progress (0-10)
var max_catch_value: float = 10.0
var time_in_target: float = 0.0  # Time hand has been in target
var base_catch_initiation_time: float = 1.0  # Base time needed to initiate catch
var catch_initiation_time: float = 1.0  # Actual time (modified by NPC archetype)
var catch_timer: float = 0.0  # Time elapsed during active catch
var base_catch_time_limit: float = 7.0  # Base time limit before auto-fail
var catch_time_limit: float = 7.0  # Actual time limit (modified by NPC archetype)
var wave_backs_count: int = 0
var current_npc: Node2D = null  # Reference to current NPC being waved at

# Level timer and win/lose conditions
var level_time_remaining: float = 180.0  # 3 minutes in seconds
var wave_backs_required: int = 5
var level_complete: bool = false
var level_active: bool = true
var current_level: int = 1  # Which level the player is currently in

# Catch value change rates (base values)
var base_catch_gain_rate: float = 1.5  # Base progress per second in big target
var catch_gain_rate: float = 1.5  # Actual progress (modified by NPC archetype)
var catch_center_bonus: float = 1.0  # Additional progress per second in center target
var catch_critical_bonus: float = 0.5  # Additional progress per second with critical hitbox in big target
var catch_critical_center_bonus: float = 1.0  # Additional progress per second with critical in center
var catch_loss_rate: float = 3.0  # Progress lost per second outside target

# Cooldown
var catch_cooldown: float = 0.0
var catch_cooldown_duration: float = 3.0

# Feedback display
var feedback_timer: float = 0.0
var feedback_duration: float = 2.0

# Timer pip references
var timer_pips: Array = []
var pip_color_green: Color = Color(0, 0.803922, 0, 0.501961)  # Standard catch color
var pip_color_yellow: Color = Color(0.803922, 0.803922, 0, 0.501961)  # Initiation color

# Wrist rotation tracking for catch mechanics
var previous_hand_rotation: float = 0.0
var hand_is_rotating: bool = false

# Staling mechanics tracking
var catch_value_from_ccw: float = 0.0  # Catch value earned while rotating counterclockwise
var catch_value_from_cw: float = 0.0  # Catch value earned while rotating clockwise
var catch_value_from_quadrant: Array = [0.0, 0.0, 0.0, 0.0]  # Catch value per quadrant (TL, TR, BL, BR)
var wrist_staling_active: bool = false
var quadrant_staling_active: int = -1  # -1 means no staling, 0-3 means quadrant index

# Quadrant disabling mechanic
var disabled_quadrants: Array = [false, false, false, false]  # TL, TR, BL, BR

# Level 6 specific
var target_catch_value_level6: float = 100.0  # Set by Level6.gd
var max_catch_buffer_level6: float = 120.0  # Set by Level6.gd
var traffic_phase_active: bool = false  # Pauses catch decay during traffic

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
	
	# Initialize quadrant lock HUDs as hidden
	if tl_quadrant_hud:
		tl_quadrant_hud.visible = false
		print("Player: TL quadrant HUD found")
	else:
		print("Player: WARNING - TL quadrant HUD NOT found")
	if tr_quadrant_hud:
		tr_quadrant_hud.visible = false
		print("Player: TR quadrant HUD found")
	else:
		print("Player: WARNING - TR quadrant HUD NOT found")
	if bl_quadrant_hud:
		bl_quadrant_hud.visible = false
		print("Player: BL quadrant HUD found")
	else:
		print("Player: WARNING - BL quadrant HUD NOT found")
	if br_quadrant_hud:
		br_quadrant_hud.visible = false
		print("Player: BR quadrant HUD found")
	else:
		print("Player: WARNING - BR quadrant HUD NOT found")
	
	# Get all timer pips
	for child in timer_pips_container.get_children():
		timer_pips.append(child)
		child.visible = false  # Hide all pips initially
	
	# Update wave backs display
	update_wave_backs_display()
	# Update timer display
	update_timer_display()
	
	# Check for debug mode from main menu
	if get_tree().root.has_meta("debug_mode"):
		debug_mode = get_tree().root.get_meta("debug_mode")
		if debug_text_label:
			debug_text_label.visible = debug_mode

func _process(delta: float):
	if level_active:
		handle_level_timer(delta)
	
	handle_input(delta)
	apply_rotations(delta)
	handle_wave_gameplay(delta)
	handle_feedback_display(delta)
	
	if debug_mode:
		update_debug_display()

func update_wave_backs_display():
	if wave_backs_label:
		wave_backs_label.text = str(wave_backs_count)
		# Turn green when pass condition is met
		if wave_backs_count >= wave_backs_required:
			wave_backs_label.modulate = Color(0, 1, 0)  # Green
		else:
			wave_backs_label.modulate = Color(1, 1, 1)  # White

func update_timer_display():
	if timer_label:
		var minutes = int(level_time_remaining) / 60
		var seconds = int(level_time_remaining) % 60
		timer_label.text = "%d:%02d" % [minutes, seconds]

func handle_level_timer(delta: float):
	if level_complete:
		return
	
	level_time_remaining -= delta
	update_timer_display()
	
	# Check for level end (time ran out)
	if level_time_remaining <= 0:
		level_time_remaining = 0
		update_timer_display()
		# Level 5 and 6 have special ending flows
		if current_level == 5 or current_level == 6:
			level_complete = true
			level_active = false
			can_catch = false
			# Emit signal - Level script handles the rest
			level_ended.emit()
		else:
			# Check if player met the wave backs requirement
			if wave_backs_count >= wave_backs_required:
				level_win()
			else:
				level_lose()

func level_win():
	level_complete = true
	level_active = false
	can_catch = false
	
	# Emit level ended signal for audio
	level_ended.emit()
	
	# Save high score and unlock next level
	save_level_completion()
	
	# Show level result
	if level_result_node:
		level_result_node.visible = true
	if level_result_label:
		level_result_label.text = "CLEAR"
	
	# Wait 5 seconds then return to level select with next level selected
	await get_tree().create_timer(5.0).timeout
	# Store next level for level select menu
	var next_level = min(current_level + 1, 6)  # Cap at level 6
	get_tree().root.set_meta("return_to_level_select", true)
	get_tree().root.set_meta("selected_level", next_level)
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func level_lose():
	level_complete = true
	level_active = false
	can_catch = false
	
	# Emit level ended signal for audio
	level_ended.emit()
	
	# Save high score even on loss (if it's still a new high)
	save_high_score_only()
	
	# Show level result
	if level_result_node:
		level_result_node.visible = true
	if level_result_label:
		level_result_label.text = "FAIL"
	
	# Wait 5 seconds then return to level select with same level selected
	await get_tree().create_timer(5.0).timeout
	# Store current level for level select menu
	get_tree().root.set_meta("return_to_level_select", true)
	get_tree().root.set_meta("selected_level", current_level)
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func save_level_completion():
	const SAVE_FILE_PATH = "user://wavr_save.dat"
	var unlocked_levels = [true, false, false, false, false, false]
	var high_scores = [0, 0, 0, 0, 0, 0]
	
	# Load existing save data
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var save_file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if save_file:
			var save_data = save_file.get_var()
			if save_data and save_data is Dictionary:
				if save_data.has("unlocked_levels"):
					unlocked_levels = save_data["unlocked_levels"]
				if save_data.has("high_scores"):
					high_scores = save_data["high_scores"]
			save_file.close()
	
	# Update high score if current score is better
	if current_level > 0 and current_level <= 6:
		if wave_backs_count > high_scores[current_level - 1]:
			high_scores[current_level - 1] = wave_backs_count
			print("Player: Updated high score for level ", current_level, " to ", wave_backs_count)
	
	# Unlock next level
	var next_level = current_level + 1
	if next_level <= 6:
		unlocked_levels[next_level - 1] = true
	
	# Save updated data
	var save_file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if save_file:
		var save_data = {
			"unlocked_levels": unlocked_levels,
			"high_scores": high_scores
		}
		save_file.store_var(save_data)
		save_file.close()
		print("Player: Saved data - high_scores: ", high_scores, ", unlocked_levels: ", unlocked_levels)

func save_high_score_only():
	const SAVE_FILE_PATH = "user://wavr_save.dat"
	var unlocked_levels = [true, false, false, false, false, false]
	var high_scores = [0, 0, 0, 0, 0, 0]
	
	# Load existing save data
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var save_file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if save_file:
			var save_data = save_file.get_var()
			if save_data and save_data is Dictionary:
				if save_data.has("unlocked_levels"):
					unlocked_levels = save_data["unlocked_levels"]
				if save_data.has("high_scores"):
					high_scores = save_data["high_scores"]
			save_file.close()
	
	# Update high score if current score is better
	if current_level > 0 and current_level <= 6:
		if wave_backs_count > high_scores[current_level - 1]:
			high_scores[current_level - 1] = wave_backs_count
			
			# Save updated data
			var save_file_write = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
			if save_file_write:
				var save_data = {
					"unlocked_levels": unlocked_levels,
					"high_scores": high_scores
				}
				save_file_write.store_var(save_data)
				save_file_write.close()

func handle_feedback_display(delta: float):
	if feedback_timer > 0:
		feedback_timer -= delta
		if feedback_timer <= 0:
			if fail_x_label:
				fail_x_label.visible = false
			if success_plus_label:
				success_plus_label.visible = false
			if angry_minus_label:
				angry_minus_label.visible = false

func show_fail_feedback():
	if fail_x_label:
		fail_x_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))  # Red
		fail_x_label.visible = true
		feedback_timer = feedback_duration

func show_fail_feedback_green():
	if fail_x_label:
		fail_x_label.add_theme_color_override("font_color", Color(0, 1, 0, 1))  # Green
		fail_x_label.visible = true
		feedback_timer = feedback_duration

func show_success_feedback():
	if success_plus_label:
		success_plus_label.visible = true
		feedback_timer = feedback_duration

func show_angry_feedback():
	if angry_minus_label:
		angry_minus_label.visible = true
		feedback_timer = feedback_duration

func update_debug_display():
	if not debug_text_label or not current_npc:
		return
	
	var npc_type = "Unknown"
	var wait_time = 0.0
	
	if current_npc.has_method("get_archetype"):
		var archetype = current_npc.get_archetype()
		match archetype:
			0: npc_type = "Basic"
			1: npc_type = "Busy"
			2: npc_type = "Oblivious"
			3: npc_type = "Angry"
	
	if current_npc.has_method("get_wait_timeout"):
		if current_npc.is_waiting_for_player:
			# Show remaining time when waiting
			var total_wait = current_npc.get_wait_timeout()
			var elapsed = current_npc.wait_timer
			wait_time = max(0.0, total_wait - elapsed)
		else:
			# Show full timeout value before reaching wait slot
			wait_time = current_npc.get_wait_timeout()
	
	debug_text_label.text = "NPC Type: %s\nWait Time Remaining: %.1fs" % [npc_type, wait_time]

func handle_input(delta: float):
	# If input is disabled, force arm to return to base position
	if not input_enabled:
		target_arm_rotation = move_toward(target_arm_rotation, base_arm_rotation, return_speed_arm * delta)
		target_forearm_rotation = move_toward(target_forearm_rotation, base_forearm_rotation, return_speed_forearm * delta)
		target_hand_rotation = move_toward(target_hand_rotation, base_hand_rotation, return_speed_hand * delta)
		return
	
	# Q - Increase arm rotation (shoulder joint)
	if Input.is_action_pressed("move_arm_up"):
		# When holding, increase rotation continuously
		target_arm_rotation -= rotation_speed_hold * delta
		target_arm_rotation = clamp(target_arm_rotation, min_arm_rotation, max_arm_rotation)
	else:
		# When not pressing, gradually return to base position (slightly slower)
		target_arm_rotation = move_toward(target_arm_rotation, base_arm_rotation, return_speed_arm * delta)
	
	# W - Increase forearm rotation (elbow joint)
	if Input.is_action_pressed("move_forearm_up"):
		target_forearm_rotation -= rotation_speed_hold * delta
		target_forearm_rotation = clamp(target_forearm_rotation, min_forearm_rotation, max_forearm_rotation)
	else:
		# When not pressing, return to base (slightly faster)
		target_forearm_rotation = move_toward(target_forearm_rotation, base_forearm_rotation, return_speed_forearm * delta)
	
	# O - Rotate hand counterclockwise
	if Input.is_action_pressed("rotate_hand_ccw"):
		target_hand_rotation -= rotation_speed_hand * delta
		target_hand_rotation = clamp(target_hand_rotation, min_hand_rotation, max_hand_rotation)
	else:
		# Return to base when not pressing (very fast)
		if target_hand_rotation < base_hand_rotation:
			target_hand_rotation = move_toward(target_hand_rotation, base_hand_rotation, return_speed_hand * delta)
	
	# P - Rotate hand clockwise
	if Input.is_action_pressed("rotate_hand_cw"):
		target_hand_rotation += rotation_speed_hand * delta
		target_hand_rotation = clamp(target_hand_rotation, min_hand_rotation, max_hand_rotation)
	else:
		# Return to base when not pressing (very fast)
		if target_hand_rotation > base_hand_rotation:
			target_hand_rotation = move_toward(target_hand_rotation, base_hand_rotation, return_speed_hand * delta)

func apply_rotations(delta: float):
	# Smoothly interpolate to target rotations
	if arm:
		arm.rotation = lerp_angle(arm.rotation, target_arm_rotation, 10.0 * delta)
	
	if forearm:
		forearm.rotation = lerp_angle(forearm.rotation, target_forearm_rotation, 10.0 * delta)
	
	if hand:
		# Track previous rotation before updating
		previous_hand_rotation = hand.rotation
		# Hand uses much snappier interpolation
		hand.rotation = lerp_angle(hand.rotation, target_hand_rotation, 25.0 * delta)
		
		# Detect if hand is actually rotating (change in rotation)
		var rotation_delta = abs(hand.rotation - previous_hand_rotation)
		hand_is_rotating = rotation_delta > 0.001  # Small threshold to avoid noise

func set_input_enabled(enabled: bool):
	input_enabled = enabled

func set_can_catch(enabled: bool):
	can_catch = enabled
	if not enabled and not catch_active:
		# Reset time in target when catching is disabled
		time_in_target = 0.0
		update_timer_pips()  # Clear yellow pips
	elif enabled and not catch_active:
		# Reset cooldown so player can immediately start initiating catch with new NPC
		catch_cooldown = 0.0
		# When enabling catch, check if hand is already in target
		# Use call_deferred to ensure physics is updated
		call_deferred("_check_hand_in_target_on_enable")

func _check_hand_in_target_on_enable():
	# Called deferred when catch is enabled to check if hand is already in position
	if can_catch and not catch_active:
		if is_overlapping(hand_hitbox, big_target):
			# Hand is already in target, give it a tiny starting value to begin immediately
			time_in_target = 0.001
			update_timer_pips()
		else:
			time_in_target = 0.0

func get_hand_quadrant() -> int:
	# Returns which quadrant (0-3) the hand is in using collision detection
	# 0 = Top-Left, 1 = Top-Right, 2 = Bottom-Left, 3 = Bottom-Right
	# Returns -1 if not in any quadrant
	if not hand_hitbox:
		return -1
	
	# Check collision with each quadrant target (check in order of priority)
	if is_overlapping(hand_hitbox, tl_target):
		return 0  # Top-Left
	elif is_overlapping(hand_hitbox, tr_target):
		return 1  # Top-Right
	elif is_overlapping(hand_hitbox, bl_target):
		return 2  # Bottom-Left
	elif is_overlapping(hand_hitbox, br_target):
		return 3  # Bottom-Right
	
	return -1  # Not in any quadrant

func is_hand_in_enabled_quadrant() -> bool:
	# If no quadrants are disabled, always return true
	var any_disabled = false
	for i in range(4):
		if disabled_quadrants[i]:
			any_disabled = true
			break
	
	if not any_disabled:
		return true
	
	if not hand_hitbox:
		return false
	
	# Check if hand is overlapping ANY enabled quadrant using collision detection
	var quadrant_targets = [tl_target, tr_target, bl_target, br_target]
	
	for i in range(4):
		# If this quadrant is enabled and hand is in it, return true
		if not disabled_quadrants[i] and is_overlapping(hand_hitbox, quadrant_targets[i]):
			return true
	
	# Hand is not in any enabled quadrant
	return false

func set_quadrant_disabled(quadrant: int, disabled: bool):
	# Set a quadrant as disabled (0=TL, 1=TR, 2=BL, 3=BR)
	if quadrant < 0 or quadrant > 3:
		print("Player: ERROR - Invalid quadrant index: ", quadrant)
		return
	
	disabled_quadrants[quadrant] = disabled
	var quadrant_names = ["Top-Left", "Top-Right", "Bottom-Left", "Bottom-Right"]
	print("Player: Setting ", quadrant_names[quadrant], " quadrant to ", "DISABLED" if disabled else "ENABLED")
	
	# Update HUD visibility
	match quadrant:
		0:  # Top-Left
			if tl_quadrant_hud:
				tl_quadrant_hud.visible = disabled
				print("Player: TL HUD visibility set to ", disabled)
			else:
				print("Player: ERROR - TL HUD is null")
		1:  # Top-Right
			if tr_quadrant_hud:
				tr_quadrant_hud.visible = disabled
				print("Player: TR HUD visibility set to ", disabled)
			else:
				print("Player: ERROR - TR HUD is null")
		2:  # Bottom-Left
			if bl_quadrant_hud:
				bl_quadrant_hud.visible = disabled
				print("Player: BL HUD visibility set to ", disabled)
			else:
				print("Player: ERROR - BL HUD is null")
		3:  # Bottom-Right
			if br_quadrant_hud:
				br_quadrant_hud.visible = disabled
				print("Player: BR HUD visibility set to ", disabled)
			else:
				print("Player: ERROR - BR HUD is null")

func get_hand_quadrants() -> Array:
	# Returns array of all quadrants (0-3) the hand is currently in
	# Used for more accurate staling detection with collision-based detection
	var quadrants_in = []
	if not hand_hitbox:
		return quadrants_in
	
	var quadrant_targets = [tl_target, tr_target, bl_target, br_target]
	for i in range(4):
		if is_overlapping(hand_hitbox, quadrant_targets[i]):
			quadrants_in.append(i)
	
	return quadrants_in

func set_current_npc(npc: Node2D):
	current_npc = npc
	
	# Update catch parameters based on NPC archetype
	if npc and npc.has_method("get_catch_initiation_multiplier"):
		catch_initiation_time = base_catch_initiation_time * npc.get_catch_initiation_multiplier()
		catch_time_limit = base_catch_time_limit * npc.get_catch_time_multiplier()
		catch_gain_rate = base_catch_gain_rate * npc.get_catch_value_multiplier()
	else:
		# Reset to base values
		catch_initiation_time = base_catch_initiation_time
		catch_time_limit = base_catch_time_limit
		catch_gain_rate = base_catch_gain_rate

func handle_wave_gameplay(delta: float):
	# Can't catch if not enabled
	if not can_catch:
		return
	
	# Handle cooldown
	if catch_cooldown > 0:
		catch_cooldown -= delta
		return
	
	# Check if hand is in big target
	var hand_in_big_target = is_overlapping(hand_hitbox, big_target)
	var hand_in_center_target = is_overlapping(hand_hitbox, center_target)
	var critical_in_big_target = is_overlapping(critical_hitbox, big_target)
	var critical_in_center_target = is_overlapping(critical_hitbox, center_target)
	
	# Check if hand is in an enabled quadrant
	var hand_in_enabled_quadrant = is_hand_in_enabled_quadrant()
	
	if not catch_active:
		# Hand must be in target AND in an enabled quadrant to initiate
		var hand_in_valid_target = hand_in_big_target and hand_in_enabled_quadrant
		
		# Try to initiate catch
		if hand_in_valid_target:
			time_in_target += delta
			update_timer_pips()  # Show yellow pips during initiation
			if time_in_target >= catch_initiation_time:
				initiate_catch()
		else:
			# More lenient: decay progress quickly instead of instant reset
			time_in_target -= delta * 3.0  # Lose progress 3x faster than gaining
			time_in_target = max(0.0, time_in_target)
			update_timer_pips()  # Update pips to show decay
	else:
		# Update catch timer
		catch_timer += delta
		
		# Check for time limit exceeded (not in Level 6)
		if current_level != 6 and catch_timer >= catch_time_limit:
			fail_catch()
			return
		
		# Update catch progress
		if hand_in_big_target:
			# Only gain progress if hand is rotating
			if hand_is_rotating:
				# Strict check: must be in at least one enabled quadrant to gain value
				if not hand_in_enabled_quadrant:
					# Hand is entirely in disabled quadrant(s) - no gain at all
					pass  # No gain, no loss (catch value stays same)
				else:
					# Hand is in at least one enabled quadrant - allow gain
					# Determine rotation direction
					var rotating_ccw = target_hand_rotation < base_hand_rotation
					var rotating_cw = target_hand_rotation > base_hand_rotation
					
					# Base gain rate
					var gain = catch_gain_rate * delta
					
					# Bonus for center target
					if hand_in_center_target:
						gain += catch_center_bonus * delta
					
					# Bonus for critical hitbox
					if critical_in_big_target:
						gain += catch_critical_bonus * delta
					
					# Extra bonus if critical is in center
					if critical_in_center_target:
						gain += catch_critical_center_bonus * delta
					
					# Apply wrist staling penalty
					var wrist_staling_penalty = 1.0
					if rotating_ccw and catch_value_from_ccw >= max_catch_value / 2.0:
						wrist_staling_penalty = 0.5
						wrist_staling_active = true
					elif rotating_cw and catch_value_from_cw >= max_catch_value / 2.0:
						wrist_staling_penalty = 0.5
						wrist_staling_active = true
					
					# Apply quadrant staling penalty using collision-based detection
					var hand_quadrants = get_hand_quadrants()
					var quadrant_staling_penalty = 1.0
					quadrant_staling_active = -1
					
					# Check if any quadrant the hand is in has staling
					for quadrant in hand_quadrants:
						if catch_value_from_quadrant[quadrant] >= max_catch_value / 2.0:
							quadrant_staling_penalty = 0.5
							quadrant_staling_active = quadrant
							break
					
					# Apply both staling penalties
					gain *= wrist_staling_penalty * quadrant_staling_penalty
					
					# Track catch value sources for staling
					if rotating_ccw:
						catch_value_from_ccw += gain
					elif rotating_cw:
						catch_value_from_cw += gain
					
					# Distribute gain across all quadrants hand is in
					for quadrant in hand_quadrants:
						catch_value_from_quadrant[quadrant] += gain / hand_quadrants.size()
					
					# For Level 6, allow catch value up to 120% of target with 1.2x gain rate
					if current_level == 6:
						catch_value = min(catch_value + (gain * 1.2), max_catch_buffer_level6)
					else:
						catch_value = min(catch_value + gain, max_catch_value)
			# If hand is in target but not rotating, catch value stays the same (no gain, no loss)
		else:
			# Lose progress when outside target
				catch_value -= catch_loss_rate * delta
				
				if catch_value <= 0:
					# In Level 6, catch doesn't fail - stays at 10% minimum
					if current_level == 6:
						catch_value = 12.0  # 10% of 120.0 buffer
					else:
						fail_catch()
						return
		
		# Check for success (not in Level 6 - that checks at level end)
		if current_level != 6 and catch_value >= max_catch_value:
			succeed_catch()
		
		# Update timer pips display
		update_timer_pips()

func is_overlapping(hitbox1: Area2D, hitbox2: Area2D) -> bool:
	if not hitbox1 or not hitbox2:
		return false
	var overlapping_areas = hitbox1.get_overlapping_areas()
	return hitbox2 in overlapping_areas

func initiate_catch():
	catch_active = true
	catch_value = 3.0  # Start at 3/10ths progress
	time_in_target = 0.0
	catch_timer = 0.0  # Reset catch timer
	update_timer_pips()
	
	# Reset staling tracking
	catch_value_from_ccw = 0.0
	catch_value_from_cw = 0.0
	catch_value_from_quadrant = [0.0, 0.0, 0.0, 0.0]
	wrist_staling_active = false
	quadrant_staling_active = -1
	
	# Stop NPC wait timer
	if current_npc and current_npc.has_method("stop_wait_timer"):
		current_npc.stop_wait_timer()
	
	# Show watching emote on NPC
	if current_npc and current_npc.has_method("show_emote_watching"):
		current_npc.show_emote_watching()

func initiate_catch_level6():
	# Level 6 specific: start catch at 10% (12.0 out of 120.0 buffer)
	catch_active = true
	catch_value = 12.0  # Start at 10% to show first pip
	time_in_target = 0.0
	catch_timer = 0.0
	update_timer_pips()
	
	# Reset staling tracking
	catch_value_from_ccw = 0.0
	catch_value_from_cw = 0.0
	catch_value_from_quadrant = [0.0, 0.0, 0.0, 0.0]
	wrist_staling_active = false
	quadrant_staling_active = -1

func fail_catch():
	catch_active = false
	catch_value = 0.0
	time_in_target = 0.0
	catch_timer = 0.0
	catch_cooldown = catch_cooldown_duration
	
	# Reset staling tracking
	catch_value_from_ccw = 0.0
	catch_value_from_cw = 0.0
	catch_value_from_quadrant = [0.0, 0.0, 0.0, 0.0]
	wrist_staling_active = false
	quadrant_staling_active = -1
	
	# Hide all pips
	for pip in timer_pips:
		pip.visible = false
	
	# Check if NPC is angry
	var is_angry_npc = current_npc and current_npc.has_method("is_angry") and current_npc.is_angry()
	
	# Show fail feedback (green X for angry NPCs, red X for normal)
	if is_angry_npc:
		show_fail_feedback_green()
	else:
		show_fail_feedback()
	
	# Show awkward emote on NPC
	if current_npc and current_npc.has_method("show_emote_awkward"):
		current_npc.show_emote_awkward()
	
	# Emit signal for level manager
	catch_failed.emit()

func succeed_catch():
	catch_active = false
	catch_value = 0.0
	time_in_target = 0.0
	catch_timer = 0.0
	catch_cooldown = catch_cooldown_duration
	
	# Reset staling tracking
	catch_value_from_ccw = 0.0
	catch_value_from_cw = 0.0
	catch_value_from_quadrant = [0.0, 0.0, 0.0, 0.0]
	wrist_staling_active = false
	quadrant_staling_active = -1
	
	# Hide all pips
	for pip in timer_pips:
		pip.visible = false
	
	# Check if NPC is angry
	var is_angry_npc = current_npc and current_npc.has_method("is_angry") and current_npc.is_angry()
	
	if is_angry_npc:
		# Angry NPC: decrease wave backs
		wave_backs_count = max(0, wave_backs_count - 1)
		update_wave_backs_display()
		
		# Show mad emote instead of happy
		if current_npc.has_method("show_emote_mad"):
			current_npc.show_emote_mad()
		
		# Show angry feedback (-1)
		show_angry_feedback()
	else:
		# Normal NPC: increase wave backs
		wave_backs_count += 1
		update_wave_backs_display()
		
		# Show happy emote
		if current_npc and current_npc.has_method("show_emote_happy"):
			current_npc.show_emote_happy()
		
		# Show success feedback (+1)
		show_success_feedback()
	
	# Emit signal for level manager to trigger NPC wave
	catch_succeeded.emit()

func update_timer_pips():
	if not catch_active and time_in_target > 0:
		# Show yellow pips during catch initiation
		var initiation_progress = time_in_target / catch_initiation_time
		var visible_pips = int(initiation_progress * timer_pips.size())
		for i in range(timer_pips.size()):
			if i < visible_pips:
				timer_pips[i].visible = true
				timer_pips[i].color = pip_color_yellow
			else:
				timer_pips[i].visible = false
	else:
		# Show green pips during active catch
		var visible_pips: int
		if current_level == 6:
			# Level 6: show progress against buffer value (all 12 pips)
			visible_pips = int((catch_value / max_catch_buffer_level6) * float(timer_pips.size()))
		else:
			visible_pips = int(catch_value)
		for i in range(timer_pips.size()):
			if i < visible_pips:
				timer_pips[i].visible = true
				timer_pips[i].color = pip_color_green
			else:
				timer_pips[i].visible = false
