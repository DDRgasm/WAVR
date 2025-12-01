extends Control

@onready var main_menu: VBoxContainer = $VBoxContainer
@onready var options_menu: Control = $OptionsMenu
@onready var level_select_menu: Control = $LevelSelectMenu
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var level_select_button: Button = $VBoxContainer/LevelSelectButton
@onready var options_button: Button = $VBoxContainer/OptionsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var back_button: Button = $OptionsMenu/VBoxContainer/BackButton
@onready var qwop_button: Button = $OptionsMenu/VBoxContainer/InputSchemeContainer/QWOPButton
@onready var wavr_button: Button = $OptionsMenu/VBoxContainer/InputSchemeContainer/WAVRButton
@onready var ldur_button: Button = $OptionsMenu/VBoxContainer/InputSchemeContainer/LDURButton
@onready var reset_button: Button = $OptionsMenu/VBoxContainer/ResetButton
@onready var credits_button: Button = $OptionsMenu/VBoxContainer/CreditsButton

# High score UI elements
@onready var high_score_node: Control = $LevelSelectMenu/LevelBox/HighScore
@onready var pass_icon: TextureRect = $"LevelSelectMenu/LevelBox/HighScore/Pass Icon"
@onready var record_icon: TextureRect = $"LevelSelectMenu/LevelBox/HighScore/Record Icon"
@onready var score_amount_label: Label = $"LevelSelectMenu/LevelBox/HighScore/Score Amount"

# Level Select Menu
@onready var level_select_back_button: Button = $BackButton
@onready var level_box: Control = $LevelSelectMenu/LevelBox
@onready var level_box_anim: AnimationPlayer = $LevelSelectMenu/LevelBox/AnimationPlayer
@onready var level_description: Label = $LevelSelectMenu/LevelBox/LevelDescription
@onready var play_button_node: Control = $LevelSelectMenu/LevelBox/PlayButton

# Player and Title
@onready var menu_player: Node2D = $WAVR
@onready var title: Node2D = $Title
@onready var background_animation: Node2D = $BackgroundAnimation
@onready var vbox_outline: TextureRect = $VBoxContainerOutline
@onready var main_color_rect: ColorRect = $MainColorRect
@onready var input_callouts: HBoxContainer = $InputCallouts

# Audio
@onready var music_player: AudioStreamPlayer = $Music
@onready var sfx_player: AudioStreamPlayer = $SFX

# Audio resources
var music_jazzy_shop = preload("res://Assets/Music/Jazzy Shop.wav")
var sfx_register_scan = preload("res://Assets/SFX/Register Scan.wav")

# Global game settings
var debug_mode: bool = false
var input_scheme: String = "WAVR"  # "QWOP", "WAVR", or "LDUR"

# Save system
const SAVE_FILE_PATH = "user://wavr_save.dat"
var unlocked_levels: Array = [true, false, false, false, false, false]  # Level 1 always unlocked
var high_scores: Array = [0, 0, 0, 0, 0, 0]  # Wave backs for each level

# Level Select state
var selected_level: int = -1  # -1 means no selection, 1-6 for levels
var level_nodes: Array = []  # Will store references to Level1-6 nodes
var level_areas: Array = []  # Will store Area2D nodes for click detection
var level_outlines: Array = []  # Will store TextureRect nodes for outline images
var animation_playing: bool = false
var outline_normal = preload("res://Assets/TileOutline.png")
var outline_selected = preload("res://Assets/TileOutlineOn.png")
var hovered_level: int = -1  # Track which level is being hovered
var play_button_hovered: bool = false

# Level descriptions
var level_descriptions = [
	"Level 1 - First Day on the Job\nWelcome to your new job as a greeter at Roof Shack. Work on your waving form with some on the job training.",
	"Level 2 - The Busy Shift\nNow that you've gotten the hang of waving, you've been scheduled for the busy shift. Watch out for angry shoppers.",
	"Level 3 - The Big Sale\nThese discounts mean lots of shoppers, but your robot coworkers may be the real challenge. Wave high or low to work around them.",
	"Level 4 - Stock Overflow\nYour robot manager must have malfunctioned when ordering products. Now the robot warehouse workers are scrambling. Stay calm and wave side to side.",
	"Level 5 - Greet the Rich\nSo this company DOES have human employees! Unfortunately most of them are jerks. Your manager wants you in the boardroom to greet them.",
	"Level 6 - The Long Farewell\nAll that overtime at work has taken its toll on your family, and they've decided to leave you. Give it all you've got so you can see them wave back one final time."
]

func _ready():
	# Load input scheme from meta if returning from level
	if get_tree().root.has_meta("input_scheme"):
		input_scheme = get_tree().root.get_meta("input_scheme")
	
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	level_select_back_button.pressed.connect(_on_level_select_back_pressed)
	qwop_button.pressed.connect(_on_qwop_pressed)
	wavr_button.pressed.connect(_on_wavr_pressed)
	ldur_button.pressed.connect(_on_ldur_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	
	# Connect button hover signals
	start_button.mouse_entered.connect(_on_start_button_hover)
	start_button.mouse_exited.connect(_on_button_hover_exit)
	level_select_button.mouse_entered.connect(_on_level_select_button_hover)
	level_select_button.mouse_exited.connect(_on_button_hover_exit)
	options_button.mouse_entered.connect(_on_options_button_hover)
	options_button.mouse_exited.connect(_on_button_hover_exit)
	quit_button.mouse_entered.connect(_on_quit_button_hover)
	quit_button.mouse_exited.connect(_on_button_hover_exit)
	
	# Initialize level select menu
	setup_level_select_menu()
	
	# Load save data (after level nodes are set up)
	load_game_data()
	
	# Update input scheme button states
	update_input_scheme_buttons()
	
	# Play title animation
	if title and title.has_node("AnimationPlayer"):
		var title_anim = title.get_node("AnimationPlayer")
		title_anim.play("TitleDrop")
	
	# Start background music
	if music_player:
		music_player.stream = music_jazzy_shop
		music_player.finished.connect(_on_music_finished)
		music_player.play()
	
	# Start background animation
	if background_animation and background_animation.has_node("AnimationPlayer"):
		var bg_anim = background_animation.get_node("AnimationPlayer")
		bg_anim.play("TheWave")
	
	# Check if returning from a level
	if get_tree().root.has_meta("return_to_level_select"):
		get_tree().root.remove_meta("return_to_level_select")
		var level_to_select = get_tree().root.get_meta("selected_level", 1)
		get_tree().root.remove_meta("selected_level")
		
		# Open level select menu
		main_menu.visible = false
		if vbox_outline:
			vbox_outline.visible = false
		if main_color_rect:
			main_color_rect.visible = false
		level_select_menu.visible = true
		level_select_back_button.visible = true
		
		# Auto-select the level
		select_level(level_to_select)

func _on_music_finished():
	if music_player:
		music_player.play()

func _on_start_pressed():
	play_button_click()
	debug_mode = false
	start_game()

func _on_level_select_pressed():
	play_button_click()
	main_menu.visible = false
	if vbox_outline:
		vbox_outline.visible = false
	if main_color_rect:
		main_color_rect.visible = false
	level_select_menu.visible = true
	level_select_back_button.visible = true

func play_button_click():
	if sfx_player:
		sfx_player.stream = sfx_register_scan
		sfx_player.play()

func start_game(level_num: int = 1):
	# Store settings in a global autoload or pass to the level
	get_tree().root.set_meta("debug_mode", debug_mode)
	get_tree().root.set_meta("input_scheme", input_scheme)
	
	# Load the appropriate level scene
	var level_path = "res://Scenes/level1.tscn"  # Default
	if level_num == 2:
		level_path = "res://Scenes/level2.tscn"
	elif level_num == 3:
		level_path = "res://Scenes/level3.tscn"
	elif level_num == 4:
		level_path = "res://Scenes/level4.tscn"
	elif level_num == 5:
		level_path = "res://Scenes/level5.tscn"
	elif level_num == 6:
		level_path = "res://Scenes/level6.tscn"
	
	get_tree().change_scene_to_file(level_path)

func _on_options_pressed():
	play_button_click()
	main_menu.visible = false
	if vbox_outline:
		vbox_outline.visible = false
	if main_color_rect:
		main_color_rect.visible = false
	options_menu.visible = true

func _on_back_pressed():
	play_button_click()
	options_menu.visible = false
	main_menu.visible = true
	if vbox_outline:
		vbox_outline.visible = true
	if main_color_rect:
		main_color_rect.visible = true

func _on_qwop_pressed():
	play_button_click()
	input_scheme = "QWOP"
	update_input_scheme_buttons()
	update_input_actions()
	if input_callouts:
		print("MainMenu: input_callouts node: ", input_callouts)
		print("MainMenu: input_callouts script: ", input_callouts.get_script())
		if input_callouts.get_script():
			print("MainMenu: Calling update_for_scheme with QWOP")
			input_callouts.update_for_scheme(input_scheme)
		else:
			print("MainMenu: ERROR - No script attached to InputCallouts!")
	else:
		print("MainMenu: input_callouts is null")

func _on_wavr_pressed():
	play_button_click()
	input_scheme = "WAVR"
	update_input_scheme_buttons()
	update_input_actions()
	if input_callouts and input_callouts.get_script():
		input_callouts.update_for_scheme(input_scheme)

func update_input_scheme_buttons():
	qwop_button.disabled = (input_scheme == "QWOP")
	wavr_button.disabled = (input_scheme == "WAVR")
	ldur_button.disabled = (input_scheme == "LDUR")

func update_input_actions():
	# Clear existing actions
	InputMap.action_erase_events("move_arm_up")
	InputMap.action_erase_events("move_forearm_up")
	InputMap.action_erase_events("rotate_hand_ccw")
	InputMap.action_erase_events("rotate_hand_cw")
	
	if input_scheme == "QWOP":
		# Q, W, O, P
		var q_key = InputEventKey.new()
		q_key.physical_keycode = KEY_Q
		InputMap.action_add_event("move_arm_up", q_key)
		
		var w_key = InputEventKey.new()
		w_key.physical_keycode = KEY_W
		InputMap.action_add_event("move_forearm_up", w_key)
		
		var o_key = InputEventKey.new()
		o_key.physical_keycode = KEY_O
		InputMap.action_add_event("rotate_hand_ccw", o_key)
		
		var p_key = InputEventKey.new()
		p_key.physical_keycode = KEY_P
		InputMap.action_add_event("rotate_hand_cw", p_key)
	elif input_scheme == "WAVR":
		# W, A, V, R
		var w_key = InputEventKey.new()
		w_key.physical_keycode = KEY_W
		InputMap.action_add_event("move_arm_up", w_key)
		
		var a_key = InputEventKey.new()
		a_key.physical_keycode = KEY_A
		InputMap.action_add_event("move_forearm_up", a_key)
		
		var v_key = InputEventKey.new()
		v_key.physical_keycode = KEY_V
		InputMap.action_add_event("rotate_hand_ccw", v_key)
		
		var r_key = InputEventKey.new()
		r_key.physical_keycode = KEY_R
		InputMap.action_add_event("rotate_hand_cw", r_key)
	else:  # LDUR
		# Left, Down, Up, Right
		var left_key = InputEventKey.new()
		left_key.physical_keycode = KEY_LEFT
		InputMap.action_add_event("move_arm_up", left_key)
		
		var down_key = InputEventKey.new()
		down_key.physical_keycode = KEY_DOWN
		InputMap.action_add_event("move_forearm_up", down_key)
		
		var up_key = InputEventKey.new()
		up_key.physical_keycode = KEY_UP
		InputMap.action_add_event("rotate_hand_ccw", up_key)
		
		var right_key = InputEventKey.new()
		right_key.physical_keycode = KEY_RIGHT
		InputMap.action_add_event("rotate_hand_cw", right_key)

func _on_quit_pressed():
	play_button_click()
	get_tree().quit()

# Button hover handlers
func _on_start_button_hover():
	if menu_player and menu_player.has_method("set_hover_pose"):
		menu_player.set_hover_pose(-20, -15, 10)

func _on_level_select_button_hover():
	if menu_player and menu_player.has_method("set_hover_pose"):
		menu_player.set_hover_pose(-10, -10, 5)

func _on_options_button_hover():
	if menu_player and menu_player.has_method("set_hover_pose"):
		menu_player.set_hover_pose(5, -20, 5)

func _on_quit_button_hover():
	if menu_player and menu_player.has_method("set_hover_pose"):
		menu_player.set_hover_pose(20, -25, -5)

func _on_button_hover_exit():
	if menu_player and menu_player.has_method("clear_hover_pose"):
		menu_player.clear_hover_pose()

# Level Select Menu Functions
func setup_level_select_menu():
	# Get references to all level nodes
	var top_row = level_box.get_node("TopRow")
	var bottom_row = level_box.get_node("BottomRow")
	
	level_nodes = [
		top_row.get_node("Level1"),
		top_row.get_node("Level2"),
		top_row.get_node("Level3"),
		bottom_row.get_node("Level4"),
		bottom_row.get_node("Level5"),
		bottom_row.get_node("Level6")
	]
	
	# Get outline TextureRects and Area2D nodes, connect signals
	for i in range(6):
		var level_node = level_nodes[i]
		var outline = level_node.get_node("TextureRect")
		var area = level_node.get_node("Area2D")
		
		level_outlines.append(outline)
		level_areas.append(area)
		
		# Enable input and connect hover signals
		area.input_pickable = true
		area.mouse_entered.connect(_on_level_hover_enter.bind(i + 1))
		area.mouse_exited.connect(_on_level_hover_exit)
		
		# Also make the Control node itself clickable as backup
		level_node.mouse_filter = Control.MOUSE_FILTER_PASS
		level_node.gui_input.connect(_on_level_gui_input.bind(i + 1))
	
	# Connect play button hover
	var play_area = play_button_node.get_node("Area2D")
	play_area.input_pickable = true
	play_area.mouse_entered.connect(_on_play_button_hover_enter)
	play_area.mouse_exited.connect(_on_play_button_hover_exit)
	
	# Also make play button Control clickable
	play_button_node.mouse_filter = Control.MOUSE_FILTER_PASS
	play_button_node.gui_input.connect(_on_play_button_gui_input)
	
	# Hide level description, play button, and high score initially
	level_description.visible = false
	play_button_node.visible = false
	if high_score_node:
		high_score_node.visible = false
	
	# Connect animation finished signal
	level_box_anim.animation_finished.connect(_on_level_box_animation_finished)

func _input(event):
	if not level_select_menu.visible:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if animation_playing:
			return
		
		# Check if hovering over a level
		if hovered_level > 0:
			# If clicking the already selected level, deselect it
			if selected_level == hovered_level:
				deselect_level()
			else:
				select_level(hovered_level)
			get_viewport().set_input_as_handled()
		
		# Check if hovering over play button
		elif play_button_hovered and selected_level > 0:
			play_button_click()
			debug_mode = false
			start_game(selected_level)
			get_viewport().set_input_as_handled()

func _on_level_hover_enter(level_num: int):
	hovered_level = level_num

func _on_level_hover_exit():
	hovered_level = -1

func _on_level_gui_input(event: InputEvent, level_num: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if animation_playing:
			return
		
		# If clicking the already selected level, deselect it
		if selected_level == level_num:
			deselect_level()
		else:
			select_level(level_num)

func _on_play_button_hover_enter():
	play_button_hovered = true

func _on_play_button_hover_exit():
	play_button_hovered = false

func _on_play_button_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if animation_playing or selected_level <= 0:
			return
		
		play_button_click()
		debug_mode = false
		start_game(selected_level)

func select_level(level_num: int):
	# Check if level is unlocked
	if not unlocked_levels[level_num - 1]:
		return  # Can't select locked levels
	
	# If another level was selected, clear its outline first
	if selected_level > 0:
		level_outlines[selected_level - 1].texture = outline_normal
	
	var was_nothing_selected = (selected_level == -1)
	selected_level = level_num
	
	# Update outline to selected state
	level_outlines[level_num - 1].texture = outline_selected
	
	# Play expand animation if transitioning from no selection
	if was_nothing_selected:
		animation_playing = true
		level_box_anim.play("expand")
		# Description, play button, and high score visibility will be set after animation
	else:
		# Already expanded, just update description and high score immediately
		update_level_description()
		update_high_score_display()

func deselect_level():
	if selected_level <= 0:
		return
	
	# Clear outline
	level_outlines[selected_level - 1].texture = outline_normal
	selected_level = -1
	
	# Hide description, play button, and high score
	level_description.visible = false
	play_button_node.visible = false
	if high_score_node:
		high_score_node.visible = false
	
	# Play retract animation
	animation_playing = true
	level_box_anim.play("retract")

func update_level_description():
	if selected_level > 0 and selected_level <= 6:
		level_description.text = level_descriptions[selected_level - 1]

func _on_level_box_animation_finished(anim_name: String):
	animation_playing = false
	
	if anim_name == "expand" and selected_level > 0:
		# Show description, play button, and high score after expand completes
		level_description.visible = true
		play_button_node.visible = true
		if high_score_node:
			high_score_node.visible = true
		update_level_description()
		update_high_score_display()

func _on_level_select_back_pressed():
	play_button_click()
	# Reset level select state
	if selected_level > 0:
		level_outlines[selected_level - 1].texture = outline_normal
	selected_level = -1
	hovered_level = -1
	play_button_hovered = false
	level_description.visible = false
	play_button_node.visible = false
	if high_score_node:
		high_score_node.visible = false
	# Stop any playing animation and reset to retracted state
	if animation_playing:
		level_box_anim.stop()
		animation_playing = false
	level_box_anim.play("RESET")
	# Return to main menu
	level_select_menu.visible = false
	level_select_back_button.visible = false
	main_menu.visible = true
	if vbox_outline:
		vbox_outline.visible = true
	if main_color_rect:
		main_color_rect.visible = true

func _on_ldur_pressed():
	play_button_click()
	input_scheme = "LDUR"
	update_input_scheme_buttons()
	update_input_actions()
	if input_callouts and input_callouts.get_script():
		input_callouts.update_for_scheme(input_scheme)

func _on_reset_pressed():
	play_button_click()
	# Reset all progression
	unlocked_levels = [true, false, false, false, false, false]
	high_scores = [0, 0, 0, 0, 0, 0]
	save_game_data()
	# Update level select UI
	update_level_locked_states()
	# If a level is selected, update high score display
	if selected_level > 0:
		update_high_score_display()

func _on_credits_pressed():
	play_button_click()
	print("MainMenu: Credits button pressed")
	print("MainMenu: menu_player exists: ", menu_player != null)
	
	if menu_player:
		print("MainMenu: menu_player has show_hider method: ", menu_player.has_method("show_hider"))
		if menu_player.has_method("show_hider"):
			# Access HiderMode enum through the script constant (value 3 = CREDITS)
			print("MainMenu: Calling show_hider(3)")
			menu_player.show_hider(3)  # HiderMode.CREDITS
			if menu_player.hider and menu_player.hider.has_node("AnimationPlayer"):
				var credits_anim = menu_player.hider.get_node("AnimationPlayer")
				print("MainMenu: Playing CreditScroll animation")
				credits_anim.play("CreditScroll")
				# Wait 30 seconds then hide
				await get_tree().create_timer(30.0).timeout
				print("MainMenu: Hiding credits")
				menu_player.hide_hider()
			else:
				print("MainMenu: ERROR - No AnimationPlayer found in hider")
		else:
			print("MainMenu: ERROR - menu_player doesn't have show_hider method")
	else:
		print("MainMenu: ERROR - menu_player is null")

func save_game_data():
	var save_file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if save_file:
		var save_data = {
			"unlocked_levels": unlocked_levels,
			"high_scores": high_scores
		}
		save_file.store_var(save_data)
		save_file.close()

func load_game_data():
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var save_file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if save_file:
			var save_data = save_file.get_var()
			if save_data and save_data is Dictionary:
				if save_data.has("unlocked_levels"):
					unlocked_levels = save_data["unlocked_levels"]
				if save_data.has("high_scores"):
					high_scores = save_data["high_scores"]
					print("MainMenu: Loaded high scores: ", high_scores)
			save_file.close()
	else:
		print("MainMenu: No save file found")
	# Update UI based on loaded data
	update_level_locked_states()

func unlock_level(level_num: int):
	if level_num > 0 and level_num <= 6:
		unlocked_levels[level_num - 1] = true
		save_game_data()
		update_level_locked_states()

func save_high_score(level_num: int, score: int):
	if level_num > 0 and level_num <= 6:
		if score > high_scores[level_num - 1]:
			high_scores[level_num - 1] = score
			save_game_data()

func update_level_locked_states():
	# Update visibility of LevelPreview and LevelLocked for each level
	for i in range(6):
		var level_node = level_nodes[i]
		var preview = level_node.get_node("LevelPreview")
		var locked = level_node.get_node("LevelLocked")
		
		if unlocked_levels[i]:
			preview.visible = true
			locked.visible = false
		else:
			preview.visible = false
			locked.visible = true

func update_high_score_display():
	if selected_level <= 0 or selected_level > 6:
		print("MainMenu: update_high_score_display - invalid level: ", selected_level)
		return
	
	# Safety check for UI elements
	if not score_amount_label:
		print("MainMenu: update_high_score_display - score_amount_label is null")
		return
	if not pass_icon:
		print("MainMenu: update_high_score_display - pass_icon is null")
		return
	if not record_icon:
		print("MainMenu: update_high_score_display - record_icon is null")
		return
	
	var score = high_scores[selected_level - 1]
	print("MainMenu: Updating high score display for level ", selected_level, " with score ", score)
	score_amount_label.text = str(score)
	
	# Show appropriate icon based on score
	pass_icon.visible = (score >= 5 and score < 10)
	record_icon.visible = (score >= 10)
