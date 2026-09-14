extends SceneTree

# Renders every Play Store asset from the game's own drawing code: the 512 icon, the 1024x500
# feature graphic per language, and five captioned screenshots per language at phone, 7-inch
# and 10-inch tablet sizes. Needs a window (the headless renderer cannot read a viewport back),
# so tools/store.ps1 runs it windowed, with "-- --test" so the game stays silent.
# Texts and captions come from res://store/listing.cfg; output goes to res://artifacts/store.

const GAME = Vector2i(720, 1280)
const SIZES = {"phone": Vector2i(1080, 1920), "tablet7": Vector2i(1200, 2133), "tablet10": Vector2i(1600, 2844)}
const LANGS = ["it", "en"]
const OUT = "res://artifacts/store"
const INK = Color("26374b")
const CREAM = Color("fbf4e5")
const CORAL = Color("f47760")

# Icon and feature graphic, drawn with the game's helpers by inheriting its script.
class Art extends "res://scripts/game.gd":
	var mode = "icon"

	func _draw() -> void:
		if mode == "icon":
			draw_rect(Rect2(0, 0, 512, 512), CORAL)
			box(Rect2(76, 60, 360, 400), INK, 44)
			box(Rect2(100, 84, 312, 352), Color("eee2cd"), 28)
			# Doors ajar, the dinosaur peeking out between them.
			box(Rect2(100, 84, 84, 352), Color("b2b6b8"), 12, INK, 4)
			box(Rect2(328, 84, 84, 352), Color("b2b6b8"), 12, INK, 4)
			draw_person({"cells": SHAPES[4], "person": 0, "cell": Vector2i.ZERO}, Vector2(146, 150), 110)
			box(Rect2(206, 30, 100, 46), INK, 12)
			centered("↑ 01", 63, 26, CREAM, 256)
		else:
			draw_rect(Rect2(0, 0, 1024, 500), CREAM)
			box(Rect2(0, 400, 1024, 100), CORAL, 0)
			centered(t("title_top"), 165, 92, INK, 290)
			centered(t("title_main"), 285, 118, CORAL, 290)
			centered(t("tagline"), 345, 24, INK, 290)
			# Three of the gang standing on the coral floor.
			draw_person({"cells": SHAPES[4], "person": 0, "cell": Vector2i.ZERO}, Vector2(530, 180), 110)
			draw_person({"cells": SHAPES[3], "person": 2, "cell": Vector2i.ZERO}, Vector2(770, 210), 95)
			draw_person({"cells": SHAPES[0], "person": 1, "cell": Vector2i.ZERO}, Vector2(930, 320), 80)

# A captured game frame under a caption band, at any output size.
class Frame extends Control:
	var shot: Texture2D
	var caption = ""
	var font = ThemeDB.fallback_font

	func _draw() -> void:
		var w = size.x
		var h = size.y
		draw_rect(Rect2(0, 0, w, h), CREAM)
		var band = h * 0.16
		draw_rect(Rect2(0, 0, w, band), CORAL)
		# One line, shrunk until it fits nine tenths of the width.
		var fs = int(h * 0.034)
		while fs > 12 and font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w * 0.9:
			fs -= 2
		var tw = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((w - tw) / 2, band / 2 + fs * 0.36), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
		var margin = w * 0.05
		var avail = Rect2(margin, band + margin, w - 2 * margin, h - band - 2 * margin)
		var k = minf(avail.size.x / GAME.x, avail.size.y / GAME.y)
		var sz = Vector2(GAME) * k
		var pos = avail.position + (avail.size - sz) / 2
		var rim = StyleBoxFlat.new()
		rim.bg_color = INK
		rim.set_corner_radius_all(int(w * 0.02))
		draw_style_box(rim, Rect2(pos - Vector2(8, 8), sz + Vector2(16, 16)))
		draw_texture_rect(shot, Rect2(pos, sz), false)

func _initialize() -> void:
	call_deferred("run")

func viewport(px: Vector2i) -> SubViewport:
	var vp = SubViewport.new()
	vp.size = px
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp

func grab(vp: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func save(img: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err = img.save_png(path)
	if err != OK:
		push_error("Impossibile salvare %s: %s" % [path, err])
	else:
		print("scritto ", path)

# The first free spot, scanning rows, for a piece of this shape and animal.
func place(game, shape: int, person: int) -> void:
	var p = game.make_piece(shape, person)
	for y in game.SIDE:
		for x in game.SIDE:
			if game.can_place(p, Vector2i(x, y)):
				p.cell = Vector2i(x, y)
				game.pieces.append(p)
				return

# The five moments a shopper sees, in order: menu, a floor with luggage, three stars,
# the newcomer's spotlight, game over.
func setup(game, index: int) -> void:
	match index:
		0:
			game.state = "menu"
		1:
			game.start_game()
			game.floor_number = 2
			game.new_round()
			game.score = 386
			for entry in [[4, 0], [3, 2], [1, 1], [0, 3], [2, 4]]:
				place(game, entry[0], entry[1])
			game.time_left = 26.0
			game.door = game.PLAY_DOOR_MIN + (1.0 - game.time_left / game.time_limit) * (game.PLAY_DOOR_MAX - game.PLAY_DOOR_MIN)
			game.toast = game.t("toast_closing")
			game.toast_time = 1.0
		2:
			game.toast_time = 0.0
			game.state = "transit"
			game.transit_success = true
			game.round_stars = 3
			game.newcomer = -1
			game.transit_time = 1.1
			game.door = 1.0
		3:
			game.round_stars = 2
			game.newcomer = 5
			game.transit_time = 1.45
		4:
			game.state = "over"
			game.score = 1334
			game.best = 1334
			game.run_stars = 7
			game.floor_number = 5
			game.lives = 0
	game.queue_redraw()

func compose(shot: Image, caption: String, px: Vector2i) -> Image:
	var vp = viewport(px)
	var frame = Frame.new()
	frame.size = Vector2(px)
	frame.shot = ImageTexture.create_from_image(shot)
	frame.caption = caption
	vp.add_child(frame)
	var img = await grab(vp)
	vp.queue_free()
	return img

func art(mode: String, lang: String, px: Vector2i) -> Image:
	var vp = viewport(px)
	var piece = Art.new()
	vp.add_child(piece)
	piece.mode = mode
	piece.lang = lang
	piece.queue_redraw()
	var img = await grab(vp)
	vp.queue_free()
	return img

func run() -> void:
	var listing = ConfigFile.new()
	if listing.load("res://store/listing.cfg") != OK:
		push_error("store/listing.cfg mancante")
		quit(1)
		return
	var vp = viewport(GAME)
	var game = load("res://main.tscn").instantiate()
	vp.add_child(game)
	game.set_process(false)
	# No banner strip in the pictures: the layout shows the game, not the ad slot.
	game.ads.enabled = false
	game.best = 1334
	for lang in LANGS:
		game.lang = lang
		for i in 5:
			setup(game, i)
			var shot = await grab(vp)
			var caption = str(listing.get_value(lang, "caption_%d" % (i + 1), ""))
			for device in SIZES:
				var img = await compose(shot, caption, SIZES[device])
				save(img, "%s/%s/%s/%02d.png" % [OUT, lang, device, i + 1])
		var feature = await art("feature", lang, Vector2i(1024, 500))
		save(feature, "%s/%s/feature-1024x500.png" % [OUT, lang])
	var icon = await art("icon", "it", Vector2i(512, 512))
	save(icon, OUT + "/icon-512.png")
	save(icon, "res://assets/icon.png")
	quit(0)
