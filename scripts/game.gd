extends Control

const Strings = preload("res://scripts/strings.gd")
const INK = Color("26374b")
const CREAM = Color("fbf4e5")
const CORAL = Color("f47760")
const MINT = Color("9dd7bc")
const PURPLE = Color("b6a0dc")
const COLORS = [CORAL, MINT, PURPLE, Color("efc66e"), Color("8ec9d8")]
const GRID = Vector2(145, 325)
const CELL = 86.0
const SIDE = 5
const PLAY_DOOR_MIN = 0.12
const PLAY_DOOR_MAX = 0.55
const TAP_SLOP = 14.0
const TRAY_UNIT = 55.0
const MUSIC_RATE = 22050
const MUSIC_PAD = 256
const SHAPES = [ [Vector2i(0,0)], [Vector2i(0,0),Vector2i(0,1)], [Vector2i(0,0),Vector2i(1,0)], [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)], [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)], [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)], [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(1,1)] ]
# One row per animal. "head" null means the head tone is derived from the body.
# "floor" is the floor from which the animal starts appearing in the queue.
const ANIMALS = [
	{"name":"animal_dino", "body":Color("f68a70"), "head":null, "belly":true, "torso":"ridges", "marks":"", "feet":"body", "side":"purple", "face":"muzzle", "skull":false, "snout":"", "eyes":"round", "brow":"soft", "patches":false, "horns":false, "mouth":true, "floor":1},
	{"name":"animal_panda", "body":Color("fffaf0"), "head":Color("fffaf0"), "belly":false, "torso":"belt", "marks":"", "feet":"ink", "side":"", "face":"ears", "skull":true, "snout":"", "eyes":"small", "brow":"", "patches":true, "horns":false, "mouth":true, "floor":1},
	{"name":"animal_croc", "body":Color("90c8a3"), "head":Color("b7dfa0"), "belly":true, "torso":"ridges", "marks":"", "feet":"body", "side":"body", "face":"domes", "skull":true, "snout":"croc", "eyes":"round", "brow":"", "patches":false, "horns":false, "mouth":true, "floor":1},
	{"name":"animal_giraffe", "body":Color("edc264"), "head":Color("ffe2a0"), "belly":true, "torso":"", "marks":"spots", "feet":"body", "side":"", "face":"ossicones", "skull":true, "snout":"", "eyes":"round", "brow":"", "patches":false, "horns":false, "mouth":true, "floor":1},
	{"name":"animal_trice", "body":Color("bba4df"), "head":Color("c3b0e9"), "belly":true, "torso":"ridges", "marks":"", "feet":"body", "side":"", "face":"frill", "skull":true, "snout":"", "eyes":"sharp", "brow":"stern", "patches":false, "horns":true, "mouth":true, "floor":1},
	{"name":"animal_elephant", "body":Color("9ec6d8"), "head":Color("b3d6e4"), "belly":true, "torso":"", "marks":"", "feet":"body", "side":"", "face":"flaps", "skull":true, "snout":"trunk", "eyes":"big", "brow":"", "patches":false, "horns":false, "mouth":false, "floor":3},
	{"name":"animal_turtle", "body":Color("c58a55"), "head":Color("8fb069"), "belly":false, "torso":"", "marks":"shell", "feet":"body", "side":"", "face":"", "skull":true, "snout":"beak", "eyes":"round", "brow":"", "patches":false, "horns":false, "mouth":false, "floor":5},
]
const EYE_SIZES = {"big":0.085, "round":0.068, "sharp":0.055, "small":0.042}
var rng = RandomNumberGenerator.new()
var font = ThemeDB.fallback_font
var lang = "en"
var state = "menu"
var score = 0
var best = 0
var floor_number = 1
var lives = 3
var target = 10
var time_left = 35.0
var time_limit = 35.0
var pieces: Array = []
var tray: Array = []
var serial = 0
var drag: Dictionary = {}
var drag_point = Vector2.ZERO
var drag_offset = Vector2.ZERO
var drag_source = -1
var press_point = Vector2.ZERO
var selected = 0
var door = 0.0
var door_at_depart = 0.0
var transit_time = 0.0
var transit_success = false
var toast = ""
var toast_time = 0.0
var elapsed = 0.0
var muted = false
var audio_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var ads: Node
var confetti: Array = []
var test_mode = false
var save_path = "user://record.cfg"
var last_tick = -1
const LUGGAGE_KINDS = 3
const GOLD = Color("efc66e")
const GREY = Color("d7cec1")
const STAR_TIMES = [0.4, 0.7, 1.0]
const STAR_TONES = [700.0, 900.0, 1100.0]
var luggage: Array = []
var round_stars = 0
var run_stars = 0
var cues_played = 0

func t(key: String) -> String:
	return Strings.text(key, lang)

func _ready() -> void:
	lang = Strings.language_for(OS.get_locale())
	test_mode = "--test" in OS.get_cmdline_user_args()
	if test_mode:
		save_path = "user://test_record.cfg"
	rng.randomize()
	var cfg = ConfigFile.new()
	if cfg.load(save_path) == OK:
		best = int(cfg.get_value("game", "best", 0))
		muted = bool(cfg.get_value("game", "muted", false))
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -12.0
	add_child(music_player)
	if not test_mode:
		music_player.stream = build_music()
	ads = preload("res://scripts/ads.gd").new()
	add_child(ads)
	if "--screenshot" in OS.get_cmdline_user_args():
		start_game()
		demo_board()
		capture.call_deferred()

func capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/anteprima.png")
	get_tree().quit()

func demo_board() -> void:
	for entry in [[4,Vector2i(0,0),0],[3,Vector2i(3,0),2],[2,Vector2i(1,3),1]]:
		var p = make_piece(entry[0], entry[2])
		p.cell = entry[1]
		pieces.append(p)
	luggage = [{"cell":Vector2i(4,3),"kind":0}, {"cell":Vector2i(0,4),"kind":1}]

func unlocked_animals() -> Array:
	var pool: Array = []
	for i in ANIMALS.size():
		if ANIMALS[i].floor <= floor_number:
			pool.append(i)
	return pool

# Luggage left in the lift: none on the first floor, then one more every two floors, five at most.
func luggage_count(floor_id: int) -> int:
	return 0 if floor_id <= 1 else mini(5, 1 + (floor_id - 1) / 2)

func place_luggage() -> void:
	luggage.clear()
	var open_cells: Array = []
	for y in SIDE:
		for x in SIDE:
			open_cells.append(Vector2i(x,y))
	for i in luggage_count(floor_number):
		var pick = rng.randi_range(0, open_cells.size()-1)
		luggage.append({"cell":open_cells[pick], "kind":rng.randi_range(0, LUGGAGE_KINDS-1)})
		open_cells.remove_at(pick)

# Cells an animal can still take on this floor.
func capacity() -> int:
	return SIDE*SIDE - luggage.size()

# The floor's rating: the minimum is one star, half way to full is two, a full lift is three.
func stars_for(count: int) -> int:
	if count < target:
		return 0
	if count >= capacity():
		return 3
	if count >= target + (capacity() - target) / 2:
		return 2
	return 1

# Sound cues of the current transit, as [time, frequency]: one rising tone per star lit.
func transit_cues() -> Array:
	var cues: Array = []
	for k in round_stars:
		cues.append([STAR_TIMES[k], STAR_TONES[k]])
	return cues

func blocked(cell: Vector2i) -> bool:
	for item in luggage:
		if item.cell == cell:
			return true
	return false

func make_piece(shape_index: int = -1, person: int = -1) -> Dictionary:
	serial += 1
	if shape_index < 0:
		# The L from the first floor, the square from the third, the bar from the fifth, the T from the seventh.
		shape_index = rng.randi_range(0, mini(6, 3 + (floor_number - 1) / 2))
	if person < 0:
		var pool = unlocked_animals()
		person = pool[rng.randi_range(0, pool.size()-1)]
	return {"id":serial, "cells":SHAPES[shape_index].duplicate(), "person":person, "cell":Vector2i.ZERO}

func start_game() -> void:
	score = 0
	lives = 3
	floor_number = 1
	run_stars = 0
	new_round()
	ads.show_banner()
	ads.preload_interstitial()

# Canvas units the bottom of the layout gives up to the banner, when there is one.
func lift() -> float:
	return ads.banner_reserve() if ads != null else 0.0

func new_round() -> void:
	state = "playing"
	pieces.clear()
	drag.clear()
	tray = [make_piece(3), make_piece(1), make_piece(0)]
	selected = 0
	place_luggage()
	# At least three free cells beyond the minimum, however much luggage there is.
	target = mini(mini(20, 10 + floor_number - 1), capacity() - 3)
	# Three seconds a floor: enough for the pressure to be felt by the third one.
	time_limit = maxf(16, 34 - (floor_number - 1) * 3.0)
	time_left = time_limit
	last_tick = -1
	door = 0
	toast = t("toast_closing")
	toast_time = 2.0
	tone(300,0.22)
	queue_redraw()

func occupied() -> int:
	var total = 0
	for p in pieces:
		total += p.cells.size()
	return total

func can_place(p: Dictionary, cell: Vector2i) -> bool:
	for local in p.cells:
		var c: Vector2i = cell + local
		if c.x < 0 or c.y < 0 or c.x >= SIDE or c.y >= SIDE or blocked(c):
			return false
		for other in pieces:
			for other_local in other.cells:
				if c == other.cell + other_local:
					return false
	return true

func rotate_piece(p: Dictionary) -> void:
	var rotated: Array = []
	var min_x = 100
	for c in p.cells:
		var v = Vector2i(-c.y,c.x)
		rotated.append(v)
		min_x = mini(min_x,v.x)
	for i in rotated.size():
		rotated[i].x -= min_x
	p.cells = rotated

func tray_origin(i: int) -> Vector2:
	# Centre each animal in its card: shapes differ in size, the card does not.
	var cols = 1
	var rows = 1
	for c in tray[i].cells:
		cols = maxi(cols,c.x+1)
		rows = maxi(rows,c.y+1)
	return Vector2(49+i*203+(186-cols*TRAY_UNIT)*0.5, 900+(196-lift()-rows*TRAY_UNIT)*0.5)

func drag_cell() -> Vector2i:
	return Vector2i(((drag_point - drag_offset - GRID) / CELL).round())

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()
		elif event.keycode == KEY_R and state == "playing" and drag.is_empty():
			rotate_piece(tray[selected])
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press(event.position)
		else:
			release_drag(event.position)
	if event is InputEventMouseMotion and not drag.is_empty():
		drag_point = event.position
	queue_redraw()

func press(pos: Vector2) -> void:
	if Rect2(612,30,70,62).has_point(pos):
		muted = not muted
		save_record()
		return
	if state == "menu":
		if Rect2(95,1020,530,100).has_point(pos):
			start_game()
		return
	if state == "over":
		if Rect2(110,810,500,90).has_point(pos):
			start_game()
		return
	if state == "paused":
		if Rect2(110,700,500,90).has_point(pos):
			state = "playing"
		return
	if state != "playing":
		return
	if Rect2(610,198,70,64).has_point(pos):
		toggle_pause()
		return
	# An animal already aboard stays where it is: once in the lift, it is settled.
	for i in tray.size():
		if Rect2(49+i*203,866,186,240-lift()).has_point(pos):
			selected = i
			drag = tray[i].duplicate(true)
			drag_source = i
			drag_point = pos
			press_point = pos
			drag_offset = Vector2(CELL*0.5,CELL*0.5)
			return

func release_drag(pos: Vector2) -> void:
	if drag.is_empty() or state != "playing":
		return
	# The finger barely moved: that was a tap, and a tap turns the animal round.
	if press_point.distance_to(pos) < TAP_SLOP:
		rotate_piece(tray[drag_source])
		drag.clear()
		tone(460,0.06)
		queue_redraw()
		return
	drag_point = pos
	var cell = drag_cell()
	if can_place(drag,cell):
		drag.cell = cell
		pieces.append(drag.duplicate(true))
		if drag_source >= 0:
			tray[drag_source] = make_piece(0 if drag_source == 2 else -1)
		tone(580 + occupied()*14,0.09)
		if occupied() >= target:
			toast = t("toast_goal")
			toast_time = 2.5
		drag.clear()
		if occupied() >= capacity():
			depart()
	else:
		drag.clear()
		toast = t("toast_nofit")
		toast_time = 1.8
		tone(170,0.09)
	queue_redraw()

func depart() -> void:
	if state != "playing":
		return
	drag.clear()
	transit_success = occupied() >= target
	round_stars = stars_for(occupied())
	cues_played = 0
	if transit_success:
		var bonus = occupied()*10 + int(time_left)*2
		score += bonus
		run_stars += round_stars
		toast = t("toast_aboard") % bonus
		tone(880,0.22)
		for i in 15*round_stars:
			confetti.append({"pos":Vector2(rng.randf_range(80,640),rng.randf_range(270,700)),"vel":Vector2(rng.randf_range(-70,70),rng.randf_range(-160,-30)),"life":1.5,"color":COLORS[i%5]})
	else:
		lives -= 1
		toast = t("toast_fail")
		tone(140,0.3)
	toast_time = 2
	door_at_depart = door
	state = "transit"
	transit_time = 0
	save_record()

func save_record() -> void:
	best = maxi(best,score)
	var cfg = ConfigFile.new()
	cfg.set_value("game","best",best)
	cfg.set_value("game","muted",muted)
	var error = cfg.save(save_path)
	if error != OK:
		push_warning("Impossibile salvare record: %s" % error)

func toggle_pause() -> void:
	if state == "playing":
		drag.clear()
		state = "paused"
	elif state == "paused":
		state = "playing"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state == "playing":
			drag.clear()
			state = "paused"

func _process(delta: float) -> void:
	elapsed += delta
	update_music()
	toast_time = maxf(0,toast_time-delta)
	if state == "playing":
		time_left = maxf(0,time_left-delta)
		# Doors slide shut on their own, stopping halfway so every cell stays reachable.
		# They start already ajar, so the movement is visible from the first second.
		door = PLAY_DOOR_MIN+(1.0-time_left/time_limit)*(PLAY_DOOR_MAX-PLAY_DOOR_MIN)
		var seconds = int(ceil(time_left))
		if seconds > 0 and seconds <= 5 and seconds != last_tick:
			last_tick = seconds
			tone(700,0.045)
		if time_left <= 0:
			depart()
	if state == "transit":
		transit_time += delta
		door = lerpf(door_at_depart,1.0,clampf(transit_time*2,0,1))
		var cues = transit_cues()
		while cues_played < cues.size() and transit_time >= cues[cues_played][0]:
			tone(cues[cues_played][1],0.1)
			cues_played += 1
		if transit_time > 1.6:
			if lives <= 0:
				state = "over"
				ads.show_interstitial()
			elif transit_success:
				floor_number += 1
				new_round()
			else:
				new_round()
	for particle in confetti:
		particle.pos += particle.vel*delta
		particle.vel.y += 250*delta
		particle.life -= delta
	confetti = confetti.filter(func(p): return p.life > 0)
	queue_redraw()

# The theme is written here, not loaded: a I-V-vi-IV turn with a major pentatonic
# melody over it, so no interval can land sour however the phrases line up.
func build_music() -> AudioStreamWAV:
	var step = 0.25
	var lead = [659.25,783.99,880.00,783.99, 659.25,587.33,523.25,0.0,
		587.33,659.25,783.99,659.25, 587.33,523.25,587.33,0.0,
		659.25,783.99,880.00,1046.50, 880.00,783.99,659.25,0.0,
		783.99,659.25,587.33,523.25, 587.33,659.25,523.25,0.0]
	var bass = [130.81,130.81,196.00,196.00, 220.00,220.00,174.61,174.61]
	var frames = int(MUSIC_RATE*step*lead.size())
	var data = PackedByteArray()
	# Silent padding past loop_end: Godot's WAV mixer reads up to loop_end inclusive when
	# looping, and on ARM phones the hardened allocator kills a one-sample over-read.
	data.resize((frames+MUSIC_PAD)*2)
	for i in frames:
		var t = float(i)/MUSIC_RATE
		var value = 0.0
		var note: float = lead[mini(lead.size()-1,int(t/step))]
		if note > 0.0:
			var wave_phase = sin(TAU*note*t)
			# Sine with a pinch of square: chiptune character without the shrillness.
			value += (wave_phase*0.75 + (1.0 if wave_phase > 0.0 else -1.0)*0.25)*exp(-3.2*fmod(t,step)/step)*0.20
		var bar = step*4.0
		var root: float = bass[mini(bass.size()-1,int(t/bar))]
		value += sin(TAU*root*t)*exp(-1.6*fmod(t,bar)/bar)*0.30
		# Fade the last moments to silence, or the loop point clicks every eight seconds.
		var tail = float(frames-i)/(MUSIC_RATE*0.05)
		if tail < 1.0:
			value *= tail
		data.encode_s16(i*2,int(clampf(value,-1.0,1.0)*9000))
	var music = AudioStreamWAV.new()
	music.format = AudioStreamWAV.FORMAT_16_BITS
	music.mix_rate = MUSIC_RATE
	music.data = data
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = frames
	return music

func update_music() -> void:
	if music_player == null:
		return
	var should_play = not muted and not test_mode and state != "paused"
	if should_play and not music_player.playing:
		music_player.play()
	elif not should_play and music_player.playing:
		music_player.stop()

func tone(frequency: float, duration: float) -> void:
	if muted or test_mode:
		return
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var data = PackedByteArray()
	var count = int(22050*duration)
	data.resize(count*2)
	for i in count:
		var sample = int(sin(TAU*frequency*i/22050.0)*6500*(1-float(i)/count))
		data.encode_s16(i*2,sample)
	wave.data = data
	audio_player.stream = wave
	audio_player.play()

func box(rect: Rect2, color: Color, radius: int = 20, border: Color = Color.TRANSPARENT, width: int = 0) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	draw_style_box(style,rect)

func label_at(text: String, pos: Vector2, size_px: int, color: Color = INK) -> void:
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func centered(text: String, y: float, size_px: int, color: Color = INK, x: float = 360) -> void:
	var w = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
	label_at(text,Vector2(x-w/2,y),size_px,color)

func button(rect: Rect2, text: String, color: Color = CORAL, size_px: int = 32) -> void:
	box(Rect2(rect.position+Vector2(0,6),rect.size),INK,26)
	box(rect,color,26,INK,3)
	centered(text,rect.position.y+rect.size.y/2+size_px*0.34,size_px,INK,rect.get_center().x)

func heart(pos: Vector2, filled: bool) -> void:
	var color = CORAL if filled else Color("d7cec1")
	draw_circle(pos+Vector2(-9,-5),12,color)
	draw_circle(pos+Vector2(9,-5),12,color)
	draw_colored_polygon(PackedVector2Array([pos+Vector2(-20,0),pos+Vector2(20,0),pos+Vector2(0,24)]),color)

func star_points(centre: Vector2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for k in 10:
		var ang = -PI/2 + k*PI/5
		points.append(centre+Vector2(cos(ang),sin(ang))*(radius if k % 2 == 0 else radius*0.45))
	return points

# What the closed doors show while the lift moves: three star slots, the earned ones lighting up in turn.
func draw_transit() -> void:
	for k in 3:
		var centre = Vector2(360+(k-1)*130, 540)
		var lit = k < round_stars and transit_time >= STAR_TIMES[k]
		draw_colored_polygon(star_points(centre, 55), GOLD if lit else GREY)
		var rim = star_points(centre, 55)
		rim.append(rim[0])
		draw_polyline(rim, INK, 3, true)

# Three things people leave in lifts, in the same flat style as the animals.
func draw_luggage(kind: int, at: Vector2, unit: float) -> void:
	var inset = unit*0.1
	var body = Rect2(at+Vector2(inset,inset), Vector2.ONE*(unit-inset*2))
	match kind:
		0: # Suitcase: leather, a handle on top, two brass latches.
			box(Rect2(body.position+Vector2(0,unit*0.14), Vector2(body.size.x, body.size.y-unit*0.14)), Color("8d5a34"), int(unit*0.08), INK, 2)
			box(Rect2(at+Vector2(unit*0.36,unit*0.08), Vector2(unit*0.28,unit*0.14)), Color("6f4526"), int(unit*0.05), INK, 2)
			for dx in [0.28, 0.66]:
				box(Rect2(at+Vector2(unit*dx,unit*0.42), Vector2(unit*0.08,unit*0.14)), GOLD, 2)
		1: # Potted plant: a coral pot under three mint leaves.
			var pot = PackedVector2Array([at+Vector2(unit*0.25,unit*0.5), at+Vector2(unit*0.75,unit*0.5), at+Vector2(unit*0.66,unit*0.9), at+Vector2(unit*0.34,unit*0.9)])
			draw_colored_polygon(pot, CORAL)
			pot.append(pot[0])
			draw_polyline(pot, INK, 2, true)
			for leaf in [Vector2(0.5,0.28), Vector2(0.32,0.4), Vector2(0.68,0.4)]:
				draw_circle(at+leaf*unit, unit*0.16, MINT)
				draw_arc(at+leaf*unit, unit*0.16, 0, TAU, 24, INK, 2, true)
		2: # Cardboard box with a cross of tape.
			box(body, Color("d9b67a"), int(unit*0.05), INK, 2)
			draw_line(body.position+Vector2(body.size.x*0.5,0), body.position+Vector2(body.size.x*0.5,body.size.y), Color("c58a55"), unit*0.09)
			draw_line(body.position+Vector2(0,body.size.y*0.5), body.position+Vector2(body.size.x,body.size.y*0.5), Color("c58a55"), unit*0.09)

func animal_outline(cells: Array, origin: Vector2, unit: float) -> PackedVector2Array:
	# Trace only external edges: the animal IS the polyomino, without tile seams.
	var edges = {}
	for c in cells:
		if not cells.has(c+Vector2i(0,-1)):
			edges[c] = c+Vector2i(1,0)
		if not cells.has(c+Vector2i(1,0)):
			edges[c+Vector2i(1,0)] = c+Vector2i(1,1)
		if not cells.has(c+Vector2i(0,1)):
			edges[c+Vector2i(1,1)] = c+Vector2i(0,1)
		if not cells.has(c+Vector2i(-1,0)):
			edges[c+Vector2i(0,1)] = c
	var points: Array = []
	var cursor: Vector2i = edges.keys()[0]
	var first = cursor
	for i in edges.size():
		points.append(origin+Vector2(cursor)*unit)
		cursor = edges[cursor]
		if cursor==first:
			break
	var rounded = PackedVector2Array()
	for i in points.size():
		var p: Vector2 = points[i]
		var previous: Vector2 = points[(i-1+points.size())%points.size()]
		var next: Vector2 = points[(i+1)%points.size()]
		var a = p+(previous-p).normalized()*unit*0.19
		var b = p+(next-p).normalized()*unit*0.19
		for step in 6:
			var t = step/5.0
			rounded.append(a.lerp(p,t).lerp(p.lerp(b,t),t))
	return rounded

func hexagon(centre: Vector2, radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for k in 6:
		var ang = PI/6 + k*PI/3
		points.append(centre+Vector2(cos(ang),sin(ang))*radius)
	return points

func draw_person(p: Dictionary, origin: Vector2, unit: float, alpha: float = 1.0) -> void:
	var animal: Dictionary = ANIMALS[p.person]
	var col: Color = animal.body
	col.a = alpha
	var outline = animal_outline(p.cells,origin,unit)
	# A vertical value gradient down the silhouette: volume without leaving the flat style.
	var lowest = 0
	for c in p.cells:
		lowest = maxi(lowest,c.y)
	var span = unit*(lowest+1)
	var lit: Color = col.lightened(0.10)
	var deep: Color = col.darkened(0.16)
	var shades = PackedColorArray()
	for point in outline:
		shades.append(lit.lerp(deep,clampf((point.y-origin.y)/span,0,1)))
	draw_polygon(outline,shades)
	var border = outline.duplicate()
	border.append(border[0])
	draw_polyline(border,INK,maxf(2,unit*0.035),true)
	var head_cell: Vector2i = p.cells[0]
	for c in p.cells:
		if c.y < head_cell.y or (c.y==head_cell.y and c.x<head_cell.x):
			head_cell=c
	var head = origin+Vector2(head_cell)*unit+Vector2(unit*0.48,unit*0.46)
	var skin: Color = col.lightened(0.18)
	var torso_y = 0
	var torso_width = 0
	var torso_x = 0
	for c in p.cells:
		var row: Array = p.cells.filter(func(v): return v.y==c.y)
		if row.size()>torso_width or (row.size()==torso_width and c.y>torso_y):
			torso_y=c.y
			torso_width=row.size()
			torso_x=100
			for part in row:
				torso_x=mini(torso_x,part.x)
	var torso = origin+Vector2(torso_x,torso_y)*unit
	# The belly plate is the lit underside; the pattern on top is what varies by species.
	if animal.belly:
		box(Rect2(torso+Vector2(unit*0.16,unit*0.18),Vector2(unit*(torso_width-0.32),unit*0.6)),skin,int(unit*0.3))
	if animal.torso == "ridges":
		for line_y in [0.37,0.53,0.67]:
			draw_line(torso+Vector2(unit*0.32,unit*line_y),torso+Vector2(unit*(torso_width-0.32),unit*line_y),col.darkened(0.12),unit*0.025,true)
	elif animal.torso == "belt" and p.cells.size()>1:
		box(Rect2(torso+Vector2(unit*0.08,unit*0.24),Vector2(unit*(torso_width-0.16),unit*0.35)),INK,int(unit*0.15))
	# Body markings, limbs and tail fill the full silhouette, including its bends.
	for c in p.cells:
		var at = origin+Vector2(c)*unit
		# The shell tiles the whole silhouette, head cell included: its corner plates
		# stay visible around the head, so even a one-cell turtle still reads as one.
		if animal.marks == "shell":
			for corner in [Vector2(0.20,0.18),Vector2(0.80,0.18),Vector2(0.20,0.82),Vector2(0.80,0.82)]:
				var plate = at+corner*unit
				draw_colored_polygon(hexagon(plate,unit*0.185),col.darkened(0.30))
				draw_colored_polygon(hexagon(plate,unit*0.135),col.lightened(0.18))
		if c != head_cell:
			if animal.marks == "spots":
				# Rim plus core: a patch with an edge instead of a flat dot.
				for spot in [Vector2(0.28,0.25),Vector2(0.68,0.47),Vector2(0.33,0.72)]:
					draw_circle(at+spot*unit,unit*0.13,Color("8d5a34"))
					draw_circle(at+spot*unit,unit*0.095,Color("b8823f"))
		if not p.cells.has(c+Vector2i(0,1)):
			for dx in [0.13,0.67]:
				box(Rect2(at+Vector2(unit*dx,unit*0.73),Vector2(unit*0.23,unit*0.23)),INK if animal.feet == "ink" else col.darkened(0.15),int(unit*0.08))
				for toe in 2:
					draw_line(at+Vector2(unit*(dx+0.07+toe*0.07),unit*0.88),at+Vector2(unit*(dx+0.07+toe*0.07),unit*0.94),CREAM,unit*0.025,true)
		if animal.side != "" and not p.cells.has(c+Vector2i(-1,0)):
			var plate: Color = PURPLE if animal.side == "purple" else col.darkened(0.2)
			for sy in [0.21,0.45,0.69]:
				var v = at+Vector2(unit*0.05,unit*sy)
				draw_colored_polygon(PackedVector2Array([v,v+Vector2(unit*0.18,unit*0.08),v+Vector2(0,unit*0.16)]),plate)
				draw_colored_polygon(PackedVector2Array([v+Vector2(unit*0.03,unit*0.035),v+Vector2(unit*0.115,unit*0.075),v+Vector2(unit*0.03,unit*0.115)]),plate.lightened(0.30))
	# The head tone, when the animal declares one, applies from here down.
	if animal.head != null:
		skin = animal.head
	# Contact shadow: the crescent that makes the head sit on the body rather than float.
	if animal.skull:
		draw_circle(head+Vector2(0,unit*0.055),unit*0.385,Color(col.darkened(0.30),0.30*alpha))
	match animal.face:
		"muzzle": # Friendly dinosaur: big muzzle instead of a round skull.
			box(Rect2(head+Vector2(-unit*0.28,-unit*0.1),Vector2(unit*0.72,unit*0.39)),skin,int(unit*0.16))
		"ears": # Panda.
			for dx in [-0.24,0.24]:
				draw_circle(head+Vector2(unit*dx,-unit*0.22),unit*0.13,INK)
		"domes": # Crocodile: raised eyes.
			for dx in [-0.18,0.18]:
				draw_circle(head+Vector2(unit*dx,-unit*0.18),unit*0.15,skin)
		"ossicones": # Giraffe.
			for dx in [-0.17,0.17]:
				draw_line(head+Vector2(unit*dx,0),head+Vector2(unit*dx,-unit*0.31),INK,unit*0.05)
				draw_circle(head+Vector2(unit*dx,-unit*0.31),unit*0.055,Color("9d654d"))
		"frill": # Triceratops: a lit plate scalloped along its rim, not a string of beads.
			draw_circle(head,unit*0.40,PURPLE.lightened(0.12))
			for k in 7:
				var ang = PI+k*PI/6
				draw_circle(head+Vector2(cos(ang),sin(ang))*unit*0.32,unit*0.10,PURPLE.darkened(0.10))
		"flaps": # Elephant: wide ears tucked behind the skull, lighter inside.
			for dx in [-0.38,0.38]:
				draw_circle(head+Vector2(unit*dx,-unit*0.02),unit*0.27,skin.darkened(0.12))
				draw_circle(head+Vector2(unit*dx*0.86,-unit*0.02),unit*0.16,skin.lightened(0.16))
	if animal.skull:
		draw_circle(head,unit*0.34,skin)
	match animal.snout:
		"croc":
			box(Rect2(head+Vector2(-unit*0.34,0),Vector2(unit*0.68,unit*0.26)),skin,int(unit*0.1))
			for k in 4:
				var tooth = head+Vector2(unit*(-0.25+k*0.17),unit*0.02)
				draw_colored_polygon(PackedVector2Array([tooth+Vector2(-unit*0.048,unit*0.10),tooth,tooth+Vector2(unit*0.048,unit*0.10)]),CREAM)
		"beak": # Turtle: a horny beak standing in for the mouth.
			draw_colored_polygon(PackedVector2Array([head+Vector2(-unit*0.11,unit*0.06),head+Vector2(unit*0.11,unit*0.06),head+Vector2(0,unit*0.23)]),skin.darkened(0.24))
		"trunk": # Elephant: a tapering trunk curving down and to the side.
			var left = PackedVector2Array()
			var right = PackedVector2Array()
			for step in 7:
				var t = step/6.0
				var centre = head+Vector2(unit*0.18*t*t,unit*(0.10+0.46*t))
				var half = unit*(0.15-0.09*t)
				left.append(centre-Vector2(half,0))
				right.append(centre+Vector2(half,0))
			for i in range(right.size()-1,-1,-1):
				left.append(right[i])
			draw_colored_polygon(left,skin)
			for step in 3:
				var t = 0.28+step*0.21
				var centre = head+Vector2(unit*0.18*t*t,unit*(0.10+0.46*t))
				var half = unit*(0.15-0.09*t)*0.78
				draw_line(centre-Vector2(half,0),centre+Vector2(half,0),skin.darkened(0.18),maxf(1.0,unit*0.022),true)
	if animal.patches: # Panda: black mask, white eye field, pupil inside it.
		for dx in [-0.12,0.12]:
			draw_circle(head+Vector2(unit*dx,-unit*0.01),unit*0.145,INK)
			draw_circle(head+Vector2(unit*dx,0),unit*0.075,CREAM)
	var eye_r = unit*EYE_SIZES[animal.eyes]
	for dx in [-0.11,0.11]:
		draw_circle(head+Vector2(unit*dx,0),eye_r,INK)
		draw_circle(head+Vector2(unit*dx,0)-Vector2(eye_r*0.28,eye_r*0.38),maxf(1.0,eye_r*0.34),CREAM)
	match animal.brow:
		"soft": # Easy-going: a low arch over each eye.
			for dx in [-0.11,0.11]:
				draw_arc(head+Vector2(unit*dx,unit*0.01),unit*0.10,PI*1.12,PI*1.88,9,INK,maxf(1.2,unit*0.026),true)
		"stern": # Determined: angled down towards the middle of the face.
			for dx in [-1.0,1.0]:
				draw_line(head+Vector2(unit*dx*0.05,-unit*0.09),head+Vector2(unit*dx*0.19,-unit*0.16),INK,maxf(1.2,unit*0.034),true)
	if animal.horns:
		for dx in [-0.20,0.20]:
			var v = head+Vector2(unit*dx,-unit*0.12)
			draw_colored_polygon(PackedVector2Array([v+Vector2(-unit*0.05,0),v+Vector2(0,-unit*0.21),v+Vector2(unit*0.05,0)]),CREAM)
		draw_circle(head+Vector2(0,unit*0.07),unit*0.045,CREAM)
	if animal.mouth:
		draw_arc(head+Vector2(0,unit*0.075),unit*0.12,0,PI,14,INK,2,true)

func _draw() -> void:
	draw_rect(Rect2(0,0,720,1280),CREAM)
	for y in range(800,1280,100):
		draw_line(Vector2(0,y),Vector2(720,y),Color("eae0cf"),2)
	centered(t("title_top"),90,53)
	centered(t("title_main"),155,66,CORAL)
	centered(t("tagline"),183,18)
	box(Rect2(612,30,70,62),MINT,18)
	centered("♪" if not muted else "×♪",71,26,INK,647)
	if state == "menu":
		draw_menu()
		return
	box(Rect2(43,203,555,89),Color("fffaf1"),24,INK,2)
	label_at(t("hud_score"),Vector2(67,229),16)
	label_at(str(score),Vector2(67,271),35)
	label_at(t("hud_floor") % floor_number,Vector2(238,230),18)
	label_at(t("hud_best") % best,Vector2(238,264),18)
	for i in 3:
		heart(Vector2(459+i*43,245),i<lives)
	button(Rect2(612,206,64,64),"Ⅱ",MINT,25)
	box(Rect2(112,307,496,471),CORAL,27,INK,4)
	box(Rect2(133,317,454,450),INK,14)
	for y in SIDE:
		for x in SIDE:
			box(Rect2(GRID+Vector2(x,y)*CELL+Vector2.ONE*2,Vector2.ONE*(CELL-4)),Color("eee2cd"),9)
	for item in luggage:
		draw_luggage(item.kind, GRID+Vector2(item.cell)*CELL, CELL)
	for p in pieces:
		draw_person(p,GRID+Vector2(p.cell)*CELL,CELL)
	if not drag.is_empty():
		var c = drag_cell()
		var valid = can_place(drag,c)
		for local in drag.cells:
			box(Rect2(GRID+Vector2(c+local)*CELL+Vector2.ONE*4,Vector2.ONE*(CELL-8)),Color(0.3,0.75,0.55,0.45) if valid else Color(1,0.3,0.3,0.3),10)
	if door > 0:
		var dw = 215*door
		var panel = Color("b2b6b8")
		var edge = INK
		# Solid enough to read at a glance, translucent enough to keep every cell playable.
		if state == "playing":
			panel.a = 0.82
			edge.a = 0.82
		box(Rect2(GRID,Vector2(dw,430)),panel,3,edge,2)
		box(Rect2(GRID+Vector2(430-dw,0),Vector2(dw,430)),panel,3,edge,2)
		if door >= 1.0:
			draw_line(Vector2(355,360),Vector2(355,715),INK,3)
	if state == "transit":
		draw_transit()
	# Timer and explicit capacity goal.
	box(Rect2(49,793,622,14),Color("e1d6c6"),7)
	box(Rect2(49,793,622*maxf(0.001,time_left/time_limit),14),CORAL if time_left<8 else MINT,7)
	var timer_color = CORAL if time_left<=5 and sin(elapsed*9)>0 else INK
	label_at(t("hud_doors") % int(ceil(time_left)),Vector2(50,844),24,timer_color)
	label_at(t("hud_cells") % [occupied(),target],Vector2(258,844),24)
	label_at(t("hud_ok") if occupied()>=target else "+%d" % (target-occupied()),Vector2(606,844),24,Color("388967"))
	# Everything below the tray slides up by lift(), leaving the banner its strip.
	var card_h = 240-lift()
	for i in tray.size():
		box(Rect2(49+i*203,866,186,card_h),Color("fffaf1"),22,PURPLE if i==selected else Color("e5dac9"),3)
		label_at(t(ANIMALS[tray[i].person].name),Vector2(61+i*203,890),14)
		if drag.is_empty() or drag_source != i:
			draw_person(tray[i],tray_origin(i),TRAY_UNIT)
	var ready = occupied() >= target
	var hint_y = 866+card_h+46
	centered(t("hud_hint"),hint_y,21)
	centered(t("hud_goal_done") if ready else t("hud_goal_todo") % target,hint_y+53,22,Color("388967") if ready else INK)
	if toast_time > 0:
		box(Rect2(15,hint_y+77,690,45),CREAM,14)
		centered(toast,hint_y+106,22)
	if not drag.is_empty():
		draw_person(drag,drag_point-drag_offset,CELL,0.95)
	for p in confetti:
		draw_rect(Rect2(p.pos,Vector2(7,12)),p.color)
	if state == "paused" or state == "over":
		draw_rect(Rect2(0,0,720,1280),Color(0.1,0.16,0.23,0.68))
		box(Rect2(65,386,590,560),CREAM,38,INK,3)
		if state == "paused":
			centered(t("pause_title"),491,43)
			centered(t("pause_line1"),559,26)
			centered(t("pause_line2"),611,24)
			button(Rect2(110,700,500,90),t("pause_resume"),MINT)
		else:
			centered(t("over_title"),480,39)
			centered(str(score),587,80,CORAL)
			centered(t("over_floor") % floor_number,631,23)
			draw_colored_polygon(star_points(Vector2(300,658),14),GOLD)
			label_at("× %d" % run_stars,Vector2(322,666),22)
			centered(t("over_best") % best,692,29)
			centered(t("over_again_q"),752,25)
			button(Rect2(110,810,500,90),t("over_again"))

func draw_menu() -> void:
	centered(t("menu_motto"),241,27)
	box(Rect2(135,287,450,423),CORAL,35,INK,4)
	box(Rect2(159,312,402,375),Color("eee2cd"),20,INK,3)
	for y in 4:
		for x in 4:
			box(Rect2(175+x*92,328+y*84,86,78),Color("f9eedb"),10)
	var preview = [{"cells":SHAPES[4],"person":0},{"cells":SHAPES[3],"person":2},{"cells":SHAPES[2],"person":1}]
	draw_person(preview[0],Vector2(179,339),83)
	draw_person(preview[1],Vector2(369,423),83)
	draw_person(preview[2],Vector2(184,588),83)
	box(Rect2(292,274,136,48),INK,13)
	centered("↑ 01",309,25,CREAM)
	centered(t("menu_step1"),776,25)
	centered(t("menu_step2"),826,25)
	centered(t("menu_step3"),876,23)
	centered(t("menu_lives"),942,23)
	button(Rect2(95,1020,530,100),t("menu_start"),CORAL,30)
	centered(t("menu_best") % best,1180,25)
	centered(t("menu_footer"),1240,21)
