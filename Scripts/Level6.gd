extends Node2D

@onready var npc_slots: Node2D = $"NPC Slots"
@onready var spawn_slot: Node2D = $"NPC Slots/Spawn"
@onready var exit_slot: Node2D = $"NPC Slots/Exit"
@onready var player: Node2D = $WAVR
@onready var kid1: Node2D = $Car/Kid1
@onready var kid2: Node2D = $Car/Kid2
@onready var emote1: TextureRect = $Car/Emote1
@onready var emote2: TextureRect = $Car/Emote2
@onready var car: Node2D = $Car
@onready var traffic: Node2D = $Traffic
@onready var tears_node: Node2D = $Tears
@onready var tear1: TextureRect = $Tears/Tear1
@onready var tear2: TextureRect = $Tears/Tear2
@onready var tear3: TextureRect = $Tears/Tear3
@onready var tear4: TextureRect = $Tears/Tear4

# Audio
@onready var music_player: AudioStreamPlayer = $Music
@onready var ambience_player: AudioStreamPlayer = $Ambience
@onready var sfx_player: AudioStreamPlayer = $SFX

# Wait slots
var wait_slots: Array[Node2D] = []
var npc_scene = preload("res://Scenes/npc.tscn")

# Audio resources
var music_quirky_shop = preload("res://Assets/Music/Jazzy Shop.wav")
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

# Level 6 continuous wave event
var continuous_wave_active: bool = false
var target_catch_value: float = 100.0  # Extremely high value (~2 minutes to fill)
var max_catch_buffer: float = 120.0  # 120% of target (allows 20% buffer)

# Traffic phases
var in_traffic_phase: bool = false
var traffic_phase_timer: float = 0.0
var current_traffic_phase: int = 0  # 0-2 for three phases
var traffic_animation_index: int = 0  # 0 = ready to play, 1 = playing/played
var saved_catch_value: float = 0.0  # Store catch value when traffic starts

# Tear meter
var tear_meter: float = 15.0  # Start at 15% so first tear appears faster
var tear_meter_increase_rate: float = 1.3  # ~1.3% per second = 30% in ~11.5 seconds (starting from 15%)
var tear_thresholds: Array = [30.0, 50.0, 80.0, 100.0]
var tears_active: Array = [false, false, false, false]
var blocked_quadrants_by_tears: Array = []  # Track which quadrants were blocked by tears

# Quadrant disabling schedule
var quadrant_schedule_active: bool = false  # Disabled for Level 6
var time_elapsed: float = 0.0
var quadrant_phase: int = 0  # Track which phase we're in (0-5)

func _ready():
	# Get all wait slots
	wait_slots = [
		$"NPC Slots/Wait 1",
		$"NPC Slots/Wait 2",
		$"NPC Slots/Wait 3",
		$"NPC Slots/Wait 4"
	]
	
	# No spawning for Level 6
	spawn_timer = 0.0
	ready_to_spawn = false
	
	# Connect to player signals
	if player:
		player.current_level = 6
		player.catch_succeeded.connect(_on_catch_succeeded)
		player.catch_failed.connect(_on_catch_failed)
		player.level_ended.connect(_on_level_ended)
		
		# Set Level 6 specific values
		player.target_catch_value_level6 = target_catch_value
		player.max_catch_buffer_level6 = max_catch_buffer
		
		# Set clear condition to /2 for Level 6
		if player.clear_condition_label:
			player.clear_condition_label.text = "/2"
	
	# Hide all tears initially
	if tear1:
		tear1.visible = false
	if tear2:
		tear2.visible = false
	if tear3:
		tear3.visible = false
	if tear4:
		tear4.visible = false
	
	# Debug: verify traffic node
	if traffic:
		print("Level6: Traffic node loaded: ", traffic.name)
		if traffic.has_node("AnimationPlayer"):
			var anim_player = traffic.get_node("AnimationPlayer")
			print("Level6: AnimationPlayer found with animations: ", anim_player.get_animation_list())
		else:
			print("Level6: ERROR - No AnimationPlayer found on traffic node!")
	else:
		print("Level6: ERROR - Traffic node is null!")
	
	# Start audio
	start_level_audio()
	
	# Start continuous wave event after brief delay
	await get_tree().create_timer(2.0).timeout
	start_continuous_wave_event()

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

func start_continuous_wave_event():
	continuous_wave_active = true
	
	# Show watching emote on both kids
	if kid1 and kid1.has_method("show_emote_watching"):
		kid1.show_emote_watching()
	if kid2 and kid2.has_method("show_emote_watching"):
		kid2.show_emote_watching()
	
	# Initiate the catch with player
	if player:
		player.can_catch = true
		player.current_npc = kid1  # Use kid1 as reference
		player.initiate_catch_level6()
	
func handle_traffic_schedule(delta: float):
	# Traffic phase timings: start at 25s, 85s (1m25s), 145s (2m25s)
	# Each lasts 15 seconds
	var traffic_start_times = [25.0, 85.0, 145.0]
	var traffic_animation_start_times = [23.0, 83.0, 143.0]  # 1 second later so first car blocks line of sight as traffic phase starts
	var traffic_duration = 15.0
	
	if in_traffic_phase:
		traffic_phase_timer += delta
		if traffic_phase_timer >= traffic_duration:
			end_traffic_phase()
	else:
		# Check if we should start a traffic phase
		if current_traffic_phase < traffic_start_times.size():
			if time_elapsed >= traffic_start_times[current_traffic_phase]:
				print("Level6: Starting traffic phase ", current_traffic_phase, " at time ", time_elapsed)
				start_traffic_phase()
		
		# Check if we should start traffic animations (3s before traffic phase)
		# Use separate counter that's based purely on time
		for i in range(traffic_animation_start_times.size()):
			if traffic_animation_index == 0 and time_elapsed >= traffic_animation_start_times[i] and time_elapsed < traffic_animation_start_times[i] + 0.1:
				print("Level6: Animation trigger condition met at time ", time_elapsed, " for phase ", i)
				play_traffic_animation_sequence()
				break

func play_traffic_animation_sequence():
	# Mark that we've started this animation sequence
	traffic_animation_index = 1
	print("Level6: play_traffic_animation_sequence called at time ", time_elapsed)
	
	if not traffic:
		print("Level6: ERROR - traffic node is null!")
		return
	
	print("Level6: Traffic node found: ", traffic.name)
	
	var anim_player = traffic.get_node("AnimationPlayer")
	if not anim_player:
		print("Level6: ERROR - AnimationPlayer not found on traffic node!")
		return
	
	print("Level6: AnimationPlayer found, has animations: ", anim_player.get_animation_list())
	print("Level6: Starting traffic animation sequence")
	
	# Play the combined 'AllCars' animation that controls all 6 cars
	print("Level6: Playing AllCars animation")
	anim_player.play("AllCars")
	
	# Trigger random wave animations for all traffic NPCs
	var car_names = ["CarA", "CarB", "CarC", "CarD", "CarE", "CarF"]
	for car_name in car_names:
		if traffic.has_node(car_name):
			var car = traffic.get_node(car_name)
			# Each car has CarNPC and CarNPC2
			for npc_name in ["CarNPC", "CarNPC2"]:
				if car.has_node(npc_name):
					var npc = car.get_node(npc_name)
					if npc.has_node("AnimationPlayer"):
						var npc_anim = npc.get_node("AnimationPlayer")
						# Randomly select from Wave, Wave2, or Wave3
						var rand = randf()
						var wave_anim = "Wave"
						if rand < 0.333:
							wave_anim = "Wave"
						elif rand < 0.666:
							wave_anim = "Wave2"
						else:
							wave_anim = "Wave3"
						npc_anim.play(wave_anim)
	
	# Wait for animation to complete (adjust duration if needed)
	await get_tree().create_timer(18.0).timeout
	
	# Reset for next phase
	traffic_animation_index = 0
	print("Level6: Traffic animation sequence complete")

func start_traffic_phase():
	in_traffic_phase = true
	traffic_phase_timer = 0.0
	current_traffic_phase += 1
	
	# Save current catch value to restore after traffic
	if player:
		saved_catch_value = player.catch_value
	
	# Hide target zone
	if player and player.has_node("Target Zone"):
		player.get_node("Target Zone").visible = false
	
	# Show secondary target zone
	if player and player.has_node("Secondary Target Zone"):
		player.get_node("Secondary Target Zone").visible = true
	
	# Hide emotes
	if emote1:
		emote1.visible = false
	if emote2:
		emote2.visible = false
	
	# Pause catch decay in player
	if player:
		player.traffic_phase_active = true

func end_traffic_phase():
	in_traffic_phase = false
	traffic_phase_timer = 0.0
	
	# Restore catch value to what it was when traffic started
	if player:
		player.catch_value = saved_catch_value
	
	# Show target zone
	if player and player.has_node("Target Zone"):
		player.get_node("Target Zone").visible = true
	
	# Hide secondary target zone
	if player and player.has_node("Secondary Target Zone"):
		player.get_node("Secondary Target Zone").visible = false
	
	# Show emotes again
	if emote1:
		emote1.visible = true
	if emote2:
		emote2.visible = true
	
	# Resume catch mechanics in player
	if player:
		player.traffic_phase_active = false
	
	# Play Stall animation 1 second after traffic phase ends
	play_stall_animation()

func play_stall_animation():
	await get_tree().create_timer(1.0).timeout
	if car and car.has_node("AnimationPlayer"):
		var anim_player = car.get_node("AnimationPlayer")
		anim_player.play("Stall")

func handle_tear_meter(delta: float):
	# Increase tear meter
	tear_meter += tear_meter_increase_rate * delta
	tear_meter = min(tear_meter, 100.0)
	
	# Check thresholds
	for i in range(tear_thresholds.size()):
		if not tears_active[i] and tear_meter >= tear_thresholds[i]:
			activate_tear(i)
			
func activate_tear(tear_index: int):
	tears_active[tear_index] = true
	
	# Show tear texture
	var tear_nodes = [tear1, tear2, tear3, tear4]
	if tear_index < tear_nodes.size() and tear_nodes[tear_index]:
		tear_nodes[tear_index].visible = true
	
	# Block a random quadrant that isn't already blocked
	var available_quadrants = []
	for i in range(4):
		if not player.disabled_quadrants[i]:
			available_quadrants.append(i)
	
	if available_quadrants.size() > 0:
		var random_quadrant = available_quadrants[randi() % available_quadrants.size()]
		blocked_quadrants_by_tears.append(random_quadrant)
		if player:
			player.set_quadrant_disabled(random_quadrant, true)

func deactivate_tear(tear_index: int):
	tears_active[tear_index] = false
	
	# Hide tear texture
	var tear_nodes = [tear1, tear2, tear3, tear4]
	if tear_index < tear_nodes.size() and tear_nodes[tear_index]:
		tear_nodes[tear_index].visible = false
	
	# Unblock the most recently blocked quadrant
	if blocked_quadrants_by_tears.size() > 0:
		var quadrant_to_unblock = blocked_quadrants_by_tears.pop_back()
		if player:
			player.set_quadrant_disabled(quadrant_to_unblock, false)

func handle_secondary_target_zone(delta: float):
	# Check if player is waving in secondary target zone
	if player and player.has_node("Secondary Target Zone/Area2D"):
		var secondary_area = player.get_node("Secondary Target Zone/Area2D")
		var hand_hitbox = player.hand_hitbox
		
		if hand_hitbox and secondary_area:
			var overlapping = hand_hitbox.get_overlapping_areas()
			if secondary_area in overlapping:
				# Player is waving in secondary zone - reduce tear meter
				if player.hand_is_rotating:
					tear_meter -= 3.5 * delta  # Reduce at 3.5% per second
					tear_meter = max(tear_meter, 0.0)
					
					# Update secondary target zone pips display
					update_secondary_pips()
					
					# Check if we've dropped below thresholds
					for i in range(tear_thresholds.size() - 1, -1, -1):
						if tears_active[i] and tear_meter < tear_thresholds[i]:
							deactivate_tear(i)

func update_secondary_pips():
	# Update the 10 pips in Secondary Target Zone based on tear meter
	if player and player.has_node("Secondary Target Zone/Timer Pips"):
		var pips_container = player.get_node("Secondary Target Zone/Timer Pips")
		var pip_count = pips_container.get_child_count()
		var pips_to_show = int((tear_meter / 100.0) * float(pip_count))
		
		for i in range(pip_count):
			var pip = pips_container.get_child(i)
			pip.visible = (i < pips_to_show)

func _process(delta: float):
	# Don't process if level is not active
	if player and not player.level_active:
		return
	
	# Track time elapsed
	time_elapsed += delta
	
	# Debug: print time every 5 seconds
	if int(time_elapsed) % 5 == 0 and int(time_elapsed) != int(time_elapsed - delta):
		print("Level6: time_elapsed = ", time_elapsed, ", traffic_animation_index = ", traffic_animation_index)
	
	# Handle traffic phase schedule (also triggers animations)
	handle_traffic_schedule(delta)
	
	# Handle tear meter (only increases when NOT in traffic phase)
	if not in_traffic_phase and continuous_wave_active:
		handle_tear_meter(delta)
	
	# Handle secondary target zone during traffic phases
	if in_traffic_phase:
		handle_secondary_target_zone(delta)
	
	# Handle background NPCs
	handle_bg_shopper_left(delta)
	handle_bg_shopper_right(delta)

func handle_quadrant_schedule(delta: float):
	if not player:
		return
	
	time_elapsed += delta
	
	# Phase 0 -> 1: 30 seconds - Disable right quadrants (TR=1, BR=3)
	if quadrant_phase == 0 and time_elapsed >= 30.0:
		player.set_quadrant_disabled(1, true)  # Top-Right
		player.set_quadrant_disabled(3, true)  # Bottom-Right
		print("Level4: Disabled right quadrants at ", time_elapsed, "s")
		quadrant_phase = 1
	
	# Phase 1 -> 2: 60 seconds - Enable right, disable left quadrants (TL=0, BL=2)
	elif quadrant_phase == 1 and time_elapsed >= 60.0:
		player.set_quadrant_disabled(1, false)  # Top-Right
		player.set_quadrant_disabled(3, false)  # Bottom-Right
		player.set_quadrant_disabled(0, true)   # Top-Left
		player.set_quadrant_disabled(2, true)   # Bottom-Left
		print("Level4: Disabled left quadrants at ", time_elapsed, "s")
		quadrant_phase = 2
	
	# Phase 2 -> 3: 90 seconds - Enable left, disable right quadrants
	elif quadrant_phase == 2 and time_elapsed >= 90.0:
		player.set_quadrant_disabled(0, false)  # Top-Left
		player.set_quadrant_disabled(2, false)  # Bottom-Left
		player.set_quadrant_disabled(1, true)   # Top-Right
		player.set_quadrant_disabled(3, true)   # Bottom-Right
		print("Level4: Disabled right quadrants at ", time_elapsed, "s")
		quadrant_phase = 3
	
	# Phase 3 -> 4: 120 seconds - Enable right, disable left quadrants
	elif quadrant_phase == 3 and time_elapsed >= 120.0:
		player.set_quadrant_disabled(1, false)  # Top-Right
		player.set_quadrant_disabled(3, false)  # Bottom-Right
		player.set_quadrant_disabled(0, true)   # Top-Left
		player.set_quadrant_disabled(2, true)   # Bottom-Left
		print("Level4: Disabled left quadrants at ", time_elapsed, "s")
		quadrant_phase = 4
	
	# Phase 4 -> 5: 150 seconds - Enable all quadrants
	elif quadrant_phase == 4 and time_elapsed >= 150.0:
		player.set_quadrant_disabled(0, false)  # Top-Left
		player.set_quadrant_disabled(1, false)  # Top-Right
		player.set_quadrant_disabled(2, false)  # Bottom-Left
		player.set_quadrant_disabled(3, false)  # Bottom-Right
		print("Level4: Enabled all quadrants at ", time_elapsed, "s")
		quadrant_phase = 5
		quadrant_schedule_active = false  # Stop checking after final transition

func get_archetype_for_time() -> int:
	# Get time remaining from player
	var time_remaining = 180.0  # Default
	if player:
		time_remaining = player.level_time_remaining
	
	var archetype_roll = randi() % 100
	
	# Early game (3 min - 2 min): 50% Basic, 25% Busy, 10% Oblivious, 15% Angry
	if time_remaining > 120.0:
		if archetype_roll < 50:
			return 0  # BASIC
		elif archetype_roll < 75:
			return 1  # BUSY
		elif archetype_roll < 85:
			return 2  # OBLIVIOUS
		else:
			return 3  # ANGRY
	
	# Late game (< 1 min): 45% Basic, 35% Busy, 10% Oblivious, 10% Angry
	elif time_remaining < 60.0:
		if archetype_roll < 45:
			return 0  # BASIC
		elif archetype_roll < 80:
			return 1  # BUSY
		elif archetype_roll < 90:
			return 2  # OBLIVIOUS
		else:
			return 3  # ANGRY
	
	# Middle game (2 min - 1 min): 30% Basic, 25% Busy, 10% Oblivious, 35% Angry
	else:
		if archetype_roll < 30:
			return 0  # BASIC
		elif archetype_roll < 55:
			return 1  # BUSY
		elif archetype_roll < 65:
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
	# Nothing happens - catch doesn't resolve in Level 6 until level ends
	pass

func _on_npc_wave_complete():
	# Not used in Level 6
	pass

func _on_catch_failed():
	# Catch can't fail in Level 6 - value just stays low
	pass

func _on_npc_wait_timeout():
	# Not used in Level 6
	pass

func _on_npc_reached_exit():
	# Not used in Level 6
	pass

func _on_level_ended():
	# Stop continuous wave and check if player reached target catch value
	continuous_wave_active = false
	var passed = player and player.catch_value >= target_catch_value
	
	if passed:
		# Success - kids wave for 3 seconds
		if kid1 and kid1.has_node("AnimationPlayer"):
			kid1.get_node("AnimationPlayer").play("Wave")
		if kid2 and kid2.has_node("AnimationPlayer"):
			kid2.get_node("AnimationPlayer").play("Wave")
		
		# Wait for wave animations
		await get_tree().create_timer(3.0).timeout
	
	# Play Car 'Go' animation (both pass and fail)
	if car and car.has_node("AnimationPlayer"):
		var anim_player = car.get_node("AnimationPlayer")
		anim_player.play("Go")
	
	# Wait for Go animation to complete
	await get_tree().create_timer(4.0).timeout
	
	# Stop ambience but keep music playing for credits
	if ambience_player:
		ambience_player.stop()
	
	# Disconnect signal to prevent duplicate calls
	if player and player.level_ended.is_connected(_on_level_ended):
		player.level_ended.disconnect(_on_level_ended)
	
	# Show level result
	if passed:
		if player:
			# Set wave backs to 2 on pass
			player.wave_backs_count = 2
			player.update_wave_backs_display()
			
			# Save completion
			player.save_level_completion()
			
			# Don't show Level Result for Level 6 pass - go straight to credits
			
			# Show hider in credits mode
			if player and player.has_method("show_hider"):
				player.show_hider(3)  # HiderMode.CREDITS
				# Play credits animation
				if player.hider and player.hider.has_node("AnimationPlayer"):
					var credits_anim = player.hider.get_node("AnimationPlayer")
					credits_anim.play("CreditScroll")
					# Wait for credits to complete (30 seconds)
					await get_tree().create_timer(30.0).timeout
			
			# Stop music after credits finish
			if music_player:
				music_player.stop()
			
			# Return to main menu
			var next_level = 6  # Stay on level 6 since it's the last level
			get_tree().root.set_meta("return_to_level_select", true)
			get_tree().root.set_meta("selected_level", next_level)
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	else:
		if player:
			# Wave backs stay at 0 on fail
			player.level_lose()

func handle_bg_shopper_left(delta: float):
	pass

func handle_bg_shopper_right(delta: float):
	pass
