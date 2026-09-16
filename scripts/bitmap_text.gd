@tool
extends Control
class_name BitmapText


@export var font_texture: Texture2D:
	set(value):
		font_texture = value
		_refresh()

@export var font_color: Color = Color.WHITE:
	set(value):
		font_color = value
		_refresh()
		
@export var right_aligned: bool = false:
	set(value):
		right_aligned = value
		_refresh()
		
@export var glyph_width: int = 16:
	set(value):
		glyph_width = maxi(value, 1)
		_refresh()


@export var glyph_height: int = 16:
	set(value):
		glyph_height = maxi(value, 1)
		_refresh()


@export var letter_spacing: int = 0:
	set(value):
		letter_spacing = value
		_refresh()


@export var line_spacing: int = 2:
	set(value):
		line_spacing = value
		_refresh()


@export var text: String = "0":
	set(value):
		text = value
		_refresh()


const GLYPH_ROWS := [
	"0123456789"
]


func _ready() -> void:
	_refresh()


func set_text(new_text: String) -> void:
	text = new_text


func _refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if font_texture == null:
		return

	var y := 0

	for line in text.split("\n", true):
		var line_width := (
			line.length() * glyph_width
			+ maxi(line.length() - 1, 0) * letter_spacing
		)

		var x := 0

		if right_aligned:
			x = -line_width

		for i in range(line.length()):
			var ch := line.substr(i, 1)

			if ch == " ":
				x += glyph_width + letter_spacing
				continue

			var region := _get_glyph_region(ch)

			if region.size != Vector2i.ZERO:
				draw_texture_rect_region(
					font_texture,
					Rect2(
						x,
						y,
						glyph_width,
						glyph_height
					),
					Rect2(
						region.position,
						region.size
					),
					font_color
				)

			x += glyph_width + letter_spacing

		y += glyph_height + line_spacing


func _get_glyph_region(ch: String) -> Rect2i:
	for row_index in range(GLYPH_ROWS.size()):
		var row: String = GLYPH_ROWS[row_index]
		var column := row.find(ch)

		if column != -1:
			return Rect2i(
				column * glyph_width,
				row_index * glyph_height,
				glyph_width,
				glyph_height
			)

	return Rect2i()
