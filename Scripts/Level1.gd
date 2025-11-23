extends Node2D

@onready var npc_slots: Node2D = $"NPC Slots"
@onready var spawn_slot: Node2D = $"NPC Slots/Spawn"
@onready var exit_slot: Node2D = $"NPC Slots/Exit"
@onready var player: Node2D = $WAVR

# Audio
@onready var music_player: AudioStreamPlayer = $Music
@onready var ambience_player: AudioStreamPlayer = $Ambience
@onready var sfx_player: AudioStreamPlayer = $SFX

# Background NPCs
@onready var check_me_out_bot: Node2D = $"BackgroundNPCs/CheckMeOutBot"
@onready var bg_shopper_left: Node2D = $"BackgroundNPCs/BGshopperLeft"
@onready var bg_shopper_right: Node2D = $"BackgroundNPCs/BGshopperRight"
@onready var bg_shopper_wait: Node2D = $"NPC Slots/BGshopperWait"
@onready var bg_shopper_left_end: Node2D = $"NPC Slots/BGshopperLeftEnd"
@onready var bg_shopper_right_end: Node2D = $"NPC Slots/BGshopperRightEnd"

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

# Background NPC state tracking
enum BGNPCState { IDLE, WALKING_TO_WAIT, WAITING, WALKING_TO_END }
var bg_left_state: BGNPCState = BGNPCState.IDLE
var bg_right_state: BGNPCState = BGNPCState.IDLE
var bg_left_timer: float = 60.0  # Start at 1 minute
var bg_right_timer: float = 120.0  # Start at 2 minutes
var bg_left_wait_timer: float = 0.0
var bg_right_wait_timer: float = 0.0
var bg_left_start_pos: Vector2 = Vector2.ZERO
var bg_right_start_pos: Vector2 = Vector2.ZERO
var bg_walk_duration: float = 6.0
var bg_wait_duration: float = 6.0

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
		player.current_level = 1
		player.catch_succeeded.connect(_on_catch_succeeded)
		player.catch_failed.connect(_on_catch_failed)
		player.level_ended.connect(_on_level_ended)
	
	# Start CheckMeOutBot idle animation
	if check_me_out_bot and check_me_out_bot.has_node("AnimationPlayer"):
		var anim_player = check_me_out_bot.get_node("AnimationPlayer")
		anim_player.play("idle")
	
	# Store starting positions for background shoppers
	if bg_shopper_left:
		bg_left_start_pos = bg_shopper_left.global_position
	if bg_shopper_right:
		bg_right_start_pos = bg_shopper_right.global_position
	
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
	
	# Handle spawn timer
	if spawn_timer > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_npc()
	
	# Handle background NPCs
	handle_bg_shopper_left(delta)
	handle_bg_shopper_right(delta)

func get_archetype_for_time() -> int:
	# Get time remaining from player
	var time_remaining = 180.0  # Default
	if player:
		time_remaining = player.level_time_remaining
	
	var archetype_roll = randi() % 100
	
	# Early game (3 min - 2 min): 80% Basic, 10% Busy, 10% Oblivious, 0% Angry
	if time_remaining > 120.0:
		if archetype_roll < 80:
			return 0  # BASIC
		elif archetype_roll < 90:
			return 1  # BUSY
		else:
			return 2  # OBLIVIOUS
	
	# Late game (< 1 min): 55% Basic, 30% Busy, 10% Oblivious, 5% Angry
	elif time_remaining < 60.0:
		if archetype_roll < 55:
			return 0  # BASIC
		elif archetype_roll < 85:
			return 1  # BUSY
		elif archetype_roll < 95:
			return 2  # OBLIVIOUS
		else:
			return 3  # ANGRY
	
	# Middle game (2 min - 1 min): 50% Basic, 25% Busy, 10% Oblivious, 15% Angry
	else:
		if archetype_roll < 50:
			return 0  # BASIC
		elif archetype_roll < 75:
			return 1  # BUSY
		elif archetype_roll < 85:
			return 2  # OBLIVIOUS
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
	
	# Assign random archetype based on time remaining
	var archetype = get_archetype_for_time()
	current_npc.set_archetype(archetype)
	
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
	
	# Play entrance chime shortly after NPC starts moving (0.5 second delay)
	await get_tree().create_timer(0.5).timeout
	if sfx_player and is_instance_valid(current_npc):
		sfx_player.stream = sfx_entrance_chime
		sfx_player.play()

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

func _on_level_ended():
	# Play announcement sound when level ends
	if sfx_player:
		sfx_player.stream = sfx_announcement
		sfx_player.play()

func handle_bg_shopper_left(delta: float):
	if not bg_shopper_left or not bg_shopper_wait or not bg_shopper_right_end:
		return
	
	var anim_player = null
	if bg_shopper_left.has_node("AnimationPlayer"):
		anim_player = bg_shopper_left.get_node("AnimationPlayer")
	
	match bg_left_state:
		BGNPCState.IDLE:
			# Wait for 1 minute timer
			bg_left_timer -= delta
			if bg_left_timer <= 0:
				# Start walking to wait slot
				bg_left_state = BGNPCState.WALKING_TO_WAIT
				bg_left_timer = bg_walk_duration
				if anim_player:
					anim_player.play("Walk")
		
		BGNPCState.WALKING_TO_WAIT:
			# Move towards wait slot
			bg_left_timer -= delta
			var t = 1.0 - (bg_left_timer / bg_walk_duration)
			bg_shopper_left.global_position = bg_left_start_pos.lerp(bg_shopper_wait.global_position, t)
			
			if bg_left_timer <= 0:
				# Arrived at wait slot
				bg_left_state = BGNPCState.WAITING
				bg_left_wait_timer = bg_wait_duration
				if anim_player:
					anim_player.stop()
		
		BGNPCState.WAITING:
			# Wait at the slot
			bg_left_wait_timer -= delta
			if bg_left_wait_timer <= 0:
				# Start walking to right end
				bg_left_state = BGNPCState.WALKING_TO_END
				bg_left_timer = bg_walk_duration
				if anim_player:
					anim_player.play("Walk")
		
		BGNPCState.WALKING_TO_END:
			# Move towards right end
			bg_left_timer -= delta
			var t = 1.0 - (bg_left_timer / bg_walk_duration)
			bg_shopper_left.global_position = bg_shopper_wait.global_position.lerp(bg_shopper_right_end.global_position, t)
			
			if bg_left_timer <= 0:
				# Finished, can hide or keep at end position
				if anim_player:
					anim_player.stop()

func handle_bg_shopper_right(delta: float):
	if not bg_shopper_right or not bg_shopper_wait or not bg_shopper_left_end:
		return
	
	var anim_player = null
	if bg_shopper_right.has_node("AnimationPlayer"):
		anim_player = bg_shopper_right.get_node("AnimationPlayer")
	
	match bg_right_state:
		BGNPCState.IDLE:
			# Wait for 2 minute timer
			bg_right_timer -= delta
			if bg_right_timer <= 0:
				# Start walking to wait slot
				bg_right_state = BGNPCState.WALKING_TO_WAIT
				bg_right_timer = bg_walk_duration
				if anim_player:
					anim_player.play("Walk")
		
		BGNPCState.WALKING_TO_WAIT:
			# Move towards wait slot
			bg_right_timer -= delta
			var t = 1.0 - (bg_right_timer / bg_walk_duration)
			bg_shopper_right.global_position = bg_right_start_pos.lerp(bg_shopper_wait.global_position, t)
			
			if bg_right_timer <= 0:
				# Arrived at wait slot
				bg_right_state = BGNPCState.WAITING
				bg_right_wait_timer = bg_wait_duration
				if anim_player:
					anim_player.stop()
		
		BGNPCState.WAITING:
			# Wait at the slot
			bg_right_wait_timer -= delta
			if bg_right_wait_timer <= 0:
				# Start walking to left end
				bg_right_state = BGNPCState.WALKING_TO_END
				bg_right_timer = bg_walk_duration
				if anim_player:
					anim_player.play("Walk")
		
		BGNPCState.WALKING_TO_END:
			# Move towards left end
			bg_right_timer -= delta
			var t = 1.0 - (bg_right_timer / bg_walk_duration)
			bg_shopper_right.global_position = bg_shopper_wait.global_position.lerp(bg_shopper_left_end.global_position, t)
			
			if bg_right_timer <= 0:
				# Finished, can hide or keep at end position
				if anim_player:
					anim_player.stop()
