class_name UiStyle
extends RefCounted
## The game's interface look in one place: colours, font, and a Theme with
## framed paper panels and chunky buttons (retro-cute, close to beat beat; GDD § 6).
##
## Used by the HUD, the title menu and the pause menu, so every screen matches.
## Change a colour or the font here and every screen follows.

## Text and outlines: the night-sky ink.
const INK := Color("2b2140")
## Panels and buttons: warm paper.
const PAPER := Color("fffaf0")
## Highlights (hovered button, happy bubbles): lamp yellow.
const YELLOW := Color("ffd166")
## Accent for important buttons.
const PINK := Color("ff7aa2")
## Baloo 2 (SIL OFL), has every Vietnamese letter.
const FONT_PATH := "res://assets/fonts/Baloo2.ttf"


## A Theme for any Control tree: Baloo 2 at weight 650, ink labels, framed
## paper panels with a hard drop shadow, and matching buttons and sliders.
static func make_theme() -> Theme:
	var th := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		var fv := FontVariation.new()
		fv.base_font = load(FONT_PATH)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
		th.default_font = fv
	th.default_font_size = 20
	th.set_color("font_color", "Label", INK)
	th.set_stylebox("panel", "PanelContainer", framed(PAPER, 14))
	# Buttons: paper normally, yellow under the mouse, pressed sinks into its shadow.
	th.set_stylebox("normal", "Button", framed(PAPER, 10))
	th.set_stylebox("hover", "Button", framed(YELLOW, 10))
	var pressed := framed(YELLOW, 10)
	pressed.shadow_offset = Vector2(1, 1)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(state, "Button", INK)
	# Sliders: a thick ink track with a yellow fill.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.25)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	th.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = YELLOW
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return th


## A rounded box in [param fill] with a 3 px ink border and a hard shadow
## (the comic-panel look used everywhere). [param radius] in pixels.
static func framed(fill: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(14)
	sb.shadow_color = INK
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(5, 5)
	return sb
