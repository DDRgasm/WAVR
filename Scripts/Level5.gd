extends Node2D

@onready var npc_slots: Node2D = $"NPC Slots"
@onready var spawn_slot: Node2D = $"NPC Slots/Spawn"
@onready var exit_slot: Node2D = $"NPC Slots/Exit"
@onready var player: Node2D = $WAVR
@onready var office_door: Node2D = $OfficeDoor
@onready var boardroom_event: Node2D = $BoardroomBuffoonery

# Audio
@onready var music_player: AudioStreamPlayer = $Music
@onready var ambience_player: AudioStreamPlayer = $Ambience
@onready var sfx_player: AudioStreamPlayer = $SFX

# Wait slots
var wait_slots: Array[Node2D] = []
var npc_scene = preload("res://Scenes/npc.tscn")

# Audio resources
var music_quirky_shop = preload("res://Assets/Music/Quircky Shop.wav")
var sfx_announcement = preload("res://Assets/SFX/Announcement 2.wav")
var sfx_entrance_chime = preload("res://Assets/SFX/Entrance Chime.wav")
var sfx_store_ambience = preload("res://Assets/SFX/Store Ambience 2.wav")

# NPC management
var current_npc: Node2D = null
var exiting_npcs: Array = []  # Track NPCs that are exiting
var spawn_timer: float = 0.0
var initial_spawn_delay: float = 5.0
var next_spawn_delay: float = 1.0  # Delay after catch before spawning next NPC
var ready_to_spawn: bool = false

# Quadrant disabling schedule
var quadrant_schedule_active: bool = true
var time_elapsed: float = 0.0
var quadrant_phase: int = 0  # Track which phase we're in (0-6)
var level_ending_triggered: bool = false  # Track special ending at 180s

# Animation tracking
var animation_phase: int = 0  # Track which animation to play (0-5)

func _ready():
	# Get all wait slots
	wait_slots = [
		$"NPC Slots/Wait 1",
		$"NPC Slots/Wait 2",
		$"NPC Slots/Wait 3",
		$"NPC Slots/Wait 4"
	]
	
	# Start initial spawn timer
	spawn_timer = initial_spawn_delay
	ready_to_spawn = false
	
	# Connect to player signals
	if player:
		player.current_level = 5
		player.catch_succeeded.connect(_on_catch_succeeded)
		player.catch_failed.connect(_on_catch_failed)
		player.level_ended.connect(_on_level_ended)
	
	# Start boardroom animation
	if boardroom_event and boardroom_event.has_node("AnimationPlayer"):
		var anim_player = boardroom_event.get_node("AnimationPlayer")
		anim_player.play("level5act1")
		animation_phase = 1
	
	# Start audio
	start_level_audio()

func start_level_audio():
	# Play level start announcement
	if sfx_player:
		sfx_player.stream = sfx_announcement
		sfx_player.play()
	
	# Start background music (looping)
	if music_player:
		music_player.stream = music_quirky_shop
		if not music_player.finished.is_connected(_on_music_finished):
			music_player.finished.connect(_on_music_finished)
		music_player.play()
	
	# Start store ambience (looping)
	if ambience_player:
		ambience_player.stream = sfx_store_ambience
		if not ambience_player.finished.is_connected(_on_ambience_finished):
			ambience_player.finished.connect(_on_ambience_finished)
		ambience_player.play()

func _on_music_finished():
	if music_player and player and player.level_active:
		music_player.play()

func _on_ambience_finished():
	if ambience_player and player and player.level_active:
		ambience_player.play()

func _process(delta: float):
	# Don't spawn if level is not active
	if player and not player.level_active:
		return
	
	# Handle quadrant disabling schedule
	if quadrant_schedule_active:
		handle_quadrant_schedule(delta)
	
	# Handle spawn timer
	if spawn_timer > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_npc()
	
	# Handle background NPCs
	handle_bg_shopper_left(delta)
	handle_bg_shopper_right(delta)

func handle_quadrant_schedule(delta: float):
	if not player:
		return
	
	time_elapsed += delta
	
	# Phase 0: 0-30s - No blocked quadrants (initial state)
	
	# Phase 0 -> 1: 30 seconds - Block top right quadrant only
	if quadrant_phase == 0 and time_elapsed >= 30.0:
		player.set_quadrant_disabled(1, true)   # Top-Right
		print("Level5: Blocked top right quadrant at ", time_elapsed, "s")
		quadrant_phase = 1
		# Play animation act 2
		if boardroom_event and boardroom_event.has_node("AnimationPlayer") and animation_phase == 1:
			var anim_player = boardroom_event.get_node("AnimationPlayer")
			anim_player.play("level5act2")
			animation_phase = 2
	
	# Phase 1 -> 2: 60 seconds - Clear all blocks
	elif quadrant_phase == 1 and time_elapsed >= 60.0:
		player.set_quadrant_disabled(1, false)  # Top-Right
		print("Level5: Cleared all quadrants at ", time_elapsed, "s")
		quadrant_phase = 2
		# Play animation act 3
		if boardroom_event and boardroom_event.has_node("AnimationPlayer") and animation_phase == 2:
			var anim_player = boardroom_event.get_node("AnimationPlayer")
			anim_player.play("level5act3")
			animation_phase = 3
	
	# Phase 2 -> 3: 90 seconds - Block top left, bottom left, and top right
	elif quadrant_phase == 2 and time_elapsed >= 90.0:
		player.set_quadrant_disabled(0, true)   # Top-Left
		player.set_quadrant_disabled(2, true)   # Bottom-Left
		player.set_quadrant_disabled(1, true)   # Top-Right
		print("Level5: Blocked TL, BL, TR at ", time_elapsed, "s")
		quadrant_phase = 3
		# Play animation act 4
		if boardroom_event and boardroom_event.has_node("AnimationPlayer") and animation_phase == 3:
			var anim_player = boardroom_event.get_node("AnimationPlayer")
			anim_player.play("level5act4")
			animation_phase = 4
	
	# Phase 3 -> 4: 120 seconds - Block top right only
	elif quadrant_phase == 3 and time_elapsed >= 120.0:
		player.set_quadrant_disabled(0, false)  # Top-Left
		player.set_quadrant_disabled(2, false)  # Bottom-Left
		player.set_quadrant_disabled(1, true)   # Top-Right (keep blocked)
		print("Level5: Blocked top right only at ", time_elapsed, "s")
		quadrant_phase = 4
		# Play animation act 5
		if boardroom_event and boardroom_event.has_node("AnimationPlayer") and animation_phase == 4:
			var anim_player = boardroom_event.get_node("AnimationPlayer")
			anim_player.play("level5act5")
			animation_phase = 5
	
	# Phase 4 -> 5: 150 seconds - Block bottom left only
	elif quadrant_phase == 4 and time_elapsed >= 150.0:
		player.set_quadrant_disabled(1, false)  # Top-Right
		player.set_quadrant_disabled(2, true)   # Bottom-Left
		print("Level5: Blocked bottom left only at ", time_elapsed, "s")
		quadrant_phase = 5
		# Play animation act 6
		if boardroom_event and boardroom_event.has_node("AnimationPlayer") and animation_phase == 5:
			var anim_player = boardroom_event.get_node("AnimationPlayer")
			anim_player.play("level5act6")
			animation_phase = 6
	
	# Phase 5 -> 6: 180 seconds - Special ending flow
	elif quadrant_phase == 5 and time_elapsed >= 180.0:
		if not level_ending_triggered:
			level_ending_triggered = true
			trigger_special_ending()
		quadrant_phase = 6
		quadrant_schedule_active = false

func get_archetype_for_time() -> int:
	# Level 5: Only BUSY or ANGRY archetypes
	# Get time remaining from player
	var time_remaining = 180.0  # Default
	if player:
		time_remaining = player.level_time_remaining
	
	var archetype_roll = randi() % 100
	
	# First minute (3 min - 2 min): 75% Busy, 25% Angry
	if time_remaining > 120.0:
		if archetype_roll < 75:
			return 1  # BUSY
		else:
			return 3  # ANGRY
	
	# Last minute (< 1 min): 75% Busy, 25% Angry
	elif time_remaining < 60.0:
		if archetype_roll < 75:
			return 1  # BUSY
		else:
			return 3  # ANGRY
	
	# Second minute (2 min - 1 min): 50% Busy, 50% Angry
	else:
		if archetype_roll < 50:
			return 1  # BUSY
		else:
			return 3  # ANGRY

func spawn_npc():
	# Don't spawn if level is not active
	if player and not player.level_active:
		return
	
	if current_npc:
		return  # Already have an active NPC at wait slot
	
	# Instantiate NPC
	current_npc = npc_scene.instantiate()
	add_child(current_npc)
	
	# Set NPC to spawn position
	current_npc.global_position = spawn_slot.global_position
	
	# Set level BEFORE archetype so appearance customization works correctly
	current_npc.current_level = 5
	
	# Assign random archetype based on time remaining
	var archetype = get_archetype_for_time()
	current_npc.set_archetype(archetype)
	
	# Customize appearance for Level 5
	customize_level5_npc_appearance(current_npc)
	
	# Choose random wait slot
	var random_wait_slot = wait_slots[randi() % wait_slots.size()]
	
	# Connect signals
	current_npc.reached_wait_slot.connect(_on_npc_reached_wait_slot)
	current_npc.wave_complete.connect(_on_npc_wave_complete)
	current_npc.reached_exit_slot.connect(_on_npc_reached_exit)
	current_npc.wait_timeout.connect(_on_npc_wait_timeout)
	
	# Set current NPC for player immediately (for debug display)
	if player:
		player.set_current_npc(current_npc)
		player.set_can_catch(false)
		player.set_input_enabled(false)  # Disable input while NPC is entering
	
	# Move to wait slot (4 seconds)
	current_npc.move_to_wait_slot(random_wait_slot.global_position, 4.0)
	
	# Play door open animation immediately as NPC starts moving
	if office_door and office_door.has_node("AnimationPlayer"):
		var door_anim = office_door.get_node("AnimationPlayer")
		door_anim.play("Door Open")

func _on_npc_reached_wait_slot():
	# NPC has arrived at wait slot, enable catching and input
	if player:
		player.set_input_enabled(true)  # Re-enable input now that NPC is in position
		player.set_can_catch(true)

func _on_catch_succeeded():
	if not current_npc:
		return
	
	# Disable catching
	if player:
		player.set_can_catch(false)
	
	# NPC waves back
	await current_npc.play_wave()
	# Wave animation finished, handled by _on_npc_wave_complete

func _on_npc_wave_complete():
	if not current_npc:
		return
	
	# Move NPC to exiting list
	var exiting_npc = current_npc
	exiting_npcs.append(exiting_npc)
	current_npc = null
	
	# Move to exit (10 seconds after successful wave)
	exiting_npc.move_to_exit(exit_slot.global_position, 10.0)
	
	# Schedule next NPC spawn shortly after
	spawn_timer = next_spawn_delay

func _on_catch_failed():
	if not current_npc:
		return
	
	# Disable catching
	if player:
		player.set_can_catch(false)
	
	# Move NPC to exiting list
	var exiting_npc = current_npc
	exiting_npcs.append(exiting_npc)
	current_npc = null
	
	# Move to exit quickly (6 seconds)
	exiting_npc.move_to_exit(exit_slot.global_position, 6.0)
	
	# Schedule next NPC spawn shortly after
	spawn_timer = next_spawn_delay

func _on_npc_wait_timeout():
	if not current_npc:
		return
	
	# Disable catching
	if player:
		player.set_can_catch(false)
	
	# Move NPC to exiting list
	var exiting_npc = current_npc
	exiting_npcs.append(exiting_npc)
	current_npc = null
	
	# Move to exit (6 seconds, no emote)
	exiting_npc.move_to_exit(exit_slot.global_position, 6.0)
	
	# Schedule next NPC spawn shortly after
	spawn_timer = next_spawn_delay

func _on_npc_reached_exit():
	# Find and despawn the NPC that reached exit
	for npc in exiting_npcs:
		if npc and is_instance_valid(npc):
			# Check if this is the NPC that reached exit by checking its signal connection
			if npc.reached_exit_slot.is_connected(_on_npc_reached_exit):
				exiting_npcs.erase(npc)
				npc.queue_free()
				break

func trigger_special_ending():
	# Clear all quadrant blocks
	if player:
		player.set_quadrant_disabled(0, false)
		player.set_quadrant_disabled(1, false)
		player.set_quadrant_disabled(2, false)
		player.set_quadrant_disabled(3, false)
		print("Level5: Special ending - cleared all quadrants")
	
	# Stop spawning new NPCs
	spawn_timer = -999.0
	
	# End any active wave immediately and rush current NPC to exit
	if current_npc and is_instance_valid(current_npc):
		if player:
			player.set_can_catch(false)
			player.set_input_enabled(false)
		current_npc.stop_wait_timer()
		current_npc.hide_emote()
		exiting_npcs.append(current_npc)
		current_npc = null
	
	# Rush ALL exiting NPCs to exit at double speed
	for npc in exiting_npcs:
		if is_instance_valid(npc):
			# Re-trigger move to exit at double speed (2 seconds instead of 4)
			npc.move_to_exit(exit_slot.global_position, 2.0)
	
	# Disable player input and catching during cleanup
	if player:
		player.level_active = false
		player.can_catch = false
		player.set_input_enabled(false)
	
	# Wait for all NPCs to exit
	if exiting_npcs.size() > 0:
		await wait_for_all_npcs_to_exit()
	
	# Play outro animation before showing results
	if boardroom_event and boardroom_event.has_node("AnimationPlayer"):
		var anim_player = boardroom_event.get_node("AnimationPlayer")
		anim_player.play("level5outro")
		# Wait for outro animation to finish
		await anim_player.animation_finished
	
	# Now show level result and trigger normal level end flow
	if player:
		print("Level5: All NPCs cleared, showing result")
		# Determine win or lose
		if player.wave_backs_count >= player.wave_backs_required:
			# Save high score and unlock next level
			player.save_level_completion()
			
			# Show win result
			if player.level_result_node:
				player.level_result_node.visible = true
			if player.level_result_label:
				player.level_result_label.text = "CLEAR"
			
			# Wait 5 seconds then return to level select with next level
			await get_tree().create_timer(5.0).timeout
			var next_level = min(player.current_level + 1, 6)
			get_tree().root.set_meta("return_to_level_select", true)
			get_tree().root.set_meta("selected_level", next_level)
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
		else:
			# Save high score even on loss
			player.save_high_score_only()
			
			# Show lose result
			if player.level_result_node:
				player.level_result_node.visible = true
			if player.level_result_label:
				player.level_result_label.text = "FAIL"
			
			# Wait 5 seconds then return to level select with same level
			await get_tree().create_timer(5.0).timeout
			get_tree().root.set_meta("return_to_level_select", true)
			get_tree().root.set_meta("selected_level", player.current_level)
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func wait_for_all_npcs_to_exit():
	# Wait until all NPCs have exited
	while exiting_npcs.size() > 0:
		await get_tree().create_timer(0.1).timeout
		# Clean up invalid NPCs
		for i in range(exiting_npcs.size() - 1, -1, -1):
			if not is_instance_valid(exiting_npcs[i]):
				exiting_npcs.remove_at(i)

func _on_level_ended():
	# Play announcement sound when level ends
	if sfx_player:
		sfx_player.stream = sfx_announcement
		sfx_player.play()

func customize_level5_npc_appearance(npc: Node2D):
	# Level 5 NPCs have dark blue limbs and suit texture visible
	var dark_blue = Color("#202569")
	
	# Set all limbs to dark blue
	if npc.has_node("Right Arm/ColorRect"):
		npc.get_node("Right Arm/ColorRect").color = dark_blue
	if npc.has_node("Right Hand/ColorRect"):
		npc.get_node("Right Hand/ColorRect").color = dark_blue
	if npc.has_node("Left Arm/ColorRect"):
		npc.get_node("Left Arm/ColorRect").color = dark_blue
	if npc.has_node("Left Hand/ColorRect"):
		npc.get_node("Left Hand/ColorRect").color = dark_blue
	if npc.has_node("Right Leg/ColorRect"):
		npc.get_node("Right Leg/ColorRect").color = dark_blue
	if npc.has_node("Right Foot/ColorRect"):
		npc.get_node("Right Foot/ColorRect").color = dark_blue
	if npc.has_node("Left Leg/ColorRect"):
		npc.get_node("Left Leg/ColorRect").color = dark_blue
	if npc.has_node("Left Foot/ColorRect"):
		npc.get_node("Left Foot/ColorRect").color = dark_blue
	
	# Show suit TextureRect, hide ColorRects on torso
	if npc.has_node("Torso/TextureRect"):
		npc.get_node("Torso/TextureRect").visible = true
	if npc.has_node("Torso/ColorRect"):
		npc.get_node("Torso/ColorRect").visible = false
	if npc.has_node("Torso/ColorRect2"):
		npc.get_node("Torso/ColorRect2").visible = false

func handle_bg_shopper_left(delta: float):
	pass

func handle_bg_shopper_right(delta: float):
	pass
