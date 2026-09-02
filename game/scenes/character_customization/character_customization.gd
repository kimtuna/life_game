extends Control

const VARIANTS := ["green", "blue", "red"]
const VARIANT_LABELS := {
	"green": "초록 옷",
	"blue": "파랑 옷",
	"red": "빨강 옷",
}

var current_variant_index: int = 0

@onready var preview: TextureRect = $CenterContainer/VBoxContainer/PreviewFrame/PreviewMargin/Preview
@onready var variant_label: Label = $CenterContainer/VBoxContainer/VariantLabel
@onready var swatch_buttons: Array[Button] = [
	$CenterContainer/VBoxContainer/SwatchRow/GreenSwatch,
	$CenterContainer/VBoxContainer/SwatchRow/BlueSwatch,
	$CenterContainer/VBoxContainer/SwatchRow/RedSwatch,
]


func _ready() -> void:
	_select_variant(0)


func _select_variant(index: int) -> void:
	current_variant_index = index
	var variant: String = VARIANTS[index]
	preview.texture = load("res://assets/sprites/character/%s_south.png" % variant)
	variant_label.text = VARIANT_LABELS[variant]
	for i in range(swatch_buttons.size()):
		swatch_buttons[i].button_pressed = (i == index)


func _on_swatch_pressed(index: int) -> void:
	_select_variant(index)


func _on_confirm_pressed() -> void:
	var variant: String = VARIANTS[current_variant_index]
	CharacterData.save_character(CharacterData.active_slot_index, {
		"variant": variant,
		"label": VARIANT_LABELS[variant],
	})
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/character_slots/character_slots.tscn")
