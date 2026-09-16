extends Node2D
class_name DistanceDisplay

@export var digits_texture: Texture2D
@export var cell_width: int = 12
@export var cell_height: int = 12

@onready var hundreds: Sprite2D = $Hundreds
@onready var tens: Sprite2D = $Tens
@onready var ones: Sprite2D = $Ones
@onready var tenths: Sprite2D = $Tenths


func _ready() -> void:
	_prepare_digit(hundreds)
	_prepare_digit(tens)
	_prepare_digit(ones)
	_prepare_digit(tenths)

	set_distance(0.0)


func set_distance(distance_meters: float) -> void:
	var value := maxi(
		int(round(maxf(distance_meters, 0.0) * 10.0)),
		0
	)

	var whole := int(value / 10)
	var decimal := value % 10

	_set_digit(
		hundreds,
		int(whole / 100) % 10,
		whole >= 100
	)

	_set_digit(
		tens,
		int(whole / 10) % 10,
		whole >= 10
	)

	_set_digit(
		ones,
		whole % 10,
		true
	)

	_set_digit(
		tenths,
		decimal,
		true
	)


func _prepare_digit(sprite: Sprite2D) -> void:
	sprite.texture = digits_texture
	sprite.region_enabled = true
	sprite.centered = false


func _set_digit(
	sprite: Sprite2D,
	digit: int,
	show_digit: bool
) -> void:
	sprite.visible = show_digit

	if not show_digit:
		return

	sprite.region_rect = Rect2(
		digit * cell_width,
		0,
		cell_width,
		cell_height
	)
