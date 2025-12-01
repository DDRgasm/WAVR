extends HBoxContainer

var key1_label: Label
var key1_letter: TextureRect
var key1_arrow: TextureRect

var key2_label: Label
var key2_letter: TextureRect
var key2_arrow: TextureRect

var key3_label: Label
var key3_letter: TextureRect
var key3_arrow: TextureRect

var key4_label: Label
var key4_letter: TextureRect
var key4_arrow: TextureRect

func _ready():
	# Get node references
	key1_label = $Key1/Label
	key1_letter = $Key1/LetterKey
	key1_arrow = $Key1/ArrowKey
	
	key2_label = $Key2/Label
	key2_letter = $Key2/LetterKey
	key2_arrow = $Key2/ArrowKey
	
	key3_label = $Key3/Label
	key3_letter = $Key3/LetterKey
	key3_arrow = $Key3/ArrowKey
	
	key4_label = $Key4/Label
	key4_letter = $Key4/LetterKey
	key4_arrow = $Key4/ArrowKey
	
	# Check if there's a stored input scheme in the root meta
	var scheme = "WAVR"  # Default
	if get_tree().root.has_meta("input_scheme"):
		scheme = get_tree().root.get_meta("input_scheme")
	
	update_for_scheme(scheme)

func update_for_scheme(scheme: String):
	print("InputCallouts: update_for_scheme called with scheme: ", scheme)
	
	# Ensure nodes are ready
	if not is_node_ready():
		print("InputCallouts: Not ready yet, awaiting ready")
		await ready
	
	if not key1_label:
		print("InputCallouts: Getting node references")
		key1_label = $Key1/Label
		key1_letter = $Key1/LetterKey
		key1_arrow = $Key1/ArrowKey
		
		key2_label = $Key2/Label
		key2_letter = $Key2/LetterKey
		key2_arrow = $Key2/ArrowKey
		
		key3_label = $Key3/Label
		key3_letter = $Key3/LetterKey
		key3_arrow = $Key3/ArrowKey
		
		key4_label = $Key4/Label
		key4_letter = $Key4/LetterKey
		key4_arrow = $Key4/ArrowKey
	
	print("InputCallouts: Node references - key1_label: ", key1_label, ", key2_label: ", key2_label)
	
	if scheme == "WAVR":
		print("InputCallouts: Applying WAVR scheme")
		# Set labels
		key1_label.text = "W"
		key2_label.text = "A"
		key3_label.text = "V"
		key4_label.text = "R"
		
		# Show letter keys, hide arrow keys
		key1_letter.visible = true
		key1_label.visible = true
		key1_arrow.visible = false
		
		key2_letter.visible = true
		key2_label.visible = true
		key2_arrow.visible = false
		
		key3_letter.visible = true
		key3_label.visible = true
		key3_arrow.visible = false
		
		key4_letter.visible = true
		key4_label.visible = true
		key4_arrow.visible = false
		
	elif scheme == "QWOP":
		print("InputCallouts: Applying QWOP scheme")
		# Set labels
		key1_label.text = "Q"
		key2_label.text = "W"
		key3_label.text = "O"
		key4_label.text = "P"
		
		# Show letter keys, hide arrow keys
		key1_letter.visible = true
		key1_label.visible = true
		key1_arrow.visible = false
		
		key2_letter.visible = true
		key2_label.visible = true
		key2_arrow.visible = false
		
		key3_letter.visible = true
		key3_label.visible = true
		key3_arrow.visible = false
		
		key4_letter.visible = true
		key4_label.visible = true
		key4_arrow.visible = false
		
	elif scheme == "LDUR":
		print("InputCallouts: Applying LDUR scheme")
		# Hide letter keys and labels, show arrow keys
		key1_letter.visible = false
		key1_label.visible = false
		key1_arrow.visible = true
		
		key2_letter.visible = false
		key2_label.visible = false
		key2_arrow.visible = true
		
		key3_letter.visible = false
		key3_label.visible = false
		key3_arrow.visible = true
		
		key4_letter.visible = false
		key4_label.visible = false
		key4_arrow.visible = true
