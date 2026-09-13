extends SceneTree

var game
var checks = 0
var failures = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
		print("FAIL: " + message)
		return
	checks += 1
	print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.start_game()
	check(game.lives==3 and game.target==10,"initial lives and target")
	game._process(5)
	check(game.time_limit==34 and absf(game.time_left-29.0)<0.001,"the clock runs from the moment the floor opens")
	var square = game.make_piece(4,0)
	check(game.can_place(square,Vector2i(3,3)),"edge placement accepted")
	check(not game.can_place(square,Vector2i(4,4)),"outside placement rejected")
	game.tray[0] = square
	game.press(Vector2(110,930))
	game.release_drag(game.GRID+Vector2(43,43))
	check(game.occupied()==4,"drag from tray places the animal")
	check(not game.can_place(square,Vector2i(0,0)),"overlap rejected")
	game.press(game.GRID+Vector2(43,43))
	check(game.drag.is_empty(),"an animal already aboard cannot be picked up again")
	check(game.occupied()==4 and game.pieces[0].cell==Vector2i(0,0),"the animal stays where it was placed")
	var shape = game.make_piece(3,2)
	var original = shape.cells.duplicate()
	for i in 4:
		game.rotate_piece(shape)
	check(shape.cells==original,"four rotations preserve geometry")
	game.toggle_pause()
	var before = game.time_left
	game._process(9)
	check(game.time_left==before,"pause freezes timer")
	game.toggle_pause()
	game.depart()
	check(game.lives==2 and game.state=="transit","early departure costs one life")
	game._process(2)
	check(game.floor_number==1 and game.state=="playing","failed round retries same floor")
	for y in 2:
		for x in 5:
			var p = game.make_piece(0,1)
			p.cell = Vector2i(x,y)
			game.pieces.append(p)
	game.depart()
	check(game.score==168 and game.lives==2,"successful departure scores cells and time")
	game._process(2)
	check(game.floor_number==2 and game.target==11 and game.time_limit==31,"difficulty increases")
	game.floor_number = 3
	game.new_round()
	check(game.time_limit==28,"the third floor is six seconds tighter than the first")
	game.floor_number = 1
	game.new_round()
	game._process(50)
	check(game.lives==1,"timeout costs one life")
	game._process(2)
	game.depart()
	game._process(2)
	check(game.state=="over" and game.lives==0,"three failures end game")
	var cfg = ConfigFile.new()
	check(cfg.load(game.save_path)==OK and cfg.get_value("game","best")>=168,"record persisted on disk")
	game.start_game()
	check(game.score==0 and game.floor_number==1 and game.lives==3,"restart resets run")
	# All animal silhouettes remain one triangulatable polygon after rotation.
	for shape_id in game.SHAPES.size():
		var animal = game.make_piece(shape_id,0)
		for rotation in 4:
			var outline = game.animal_outline(animal.cells,Vector2.ZERO,86)
			check(Geometry2D.triangulate_polygon(outline).size()>0,"continuous animal silhouette %d rotation %d" % [shape_id,rotation])
			game.rotate_piece(animal)
	# Exercise real input event dispatch: press and release on the spot is a tap.
	game.tray[0] = game.make_piece(1,3)
	var press_event = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = Vector2(110,930)
	game._input(press_event)
	press_event.pressed = false
	press_event.position = Vector2(112,931)
	game._input(press_event)
	check(game.tray[0].cells.has(Vector2i(1,0)),"tap rotates through the real mouse/touch handler")
	game.pieces.clear()
	for y in 2:
		for x in 5:
			var p = game.make_piece(0,0)
			p.cell=Vector2i(x,y)
			game.pieces.append(p)
	game.time_left=0.1
	game._process(0.2)
	check(game.transit_success and game.score==100 and game.lives==3,"automatic doors evaluate minimum and award completed floor")
	game.depart()
	check(game.score==100,"double departure cannot duplicate score")
	for floor_id in range(1,40):
		game.floor_number=floor_id
		game.new_round()
		check(game.target<=25 and game.time_limit>=16,"bounded difficulty floor %d" % floor_id)
	# Doors close by themselves while the round runs, without hiding the whole lift.
	game.start_game()
	game._process(0.0)
	check(game.door>0.11 and game.door<0.13,"doors are already ajar the moment the floor opens")
	game._process(game.time_limit*0.5)
	check(game.door>0.33 and game.door<0.35,"doors are part way across at half time")
	game.time_left = 0.01
	game._process(0.0)
	check(game.door>0.54 and game.door<=0.55,"doors never cover more than half the lift while playing")
	# Departure continues the closing instead of restarting it from scratch.
	game.start_game()
	game._process(game.time_limit*0.5)
	var half_closed = game.door
	game.depart()
	game._process(0.001)
	check(absf(game.door-half_closed)<0.02,"transit resumes from the door position reached in play")
	game._process(0.6)
	check(game.door==1.0,"doors are fully closed during transit")
	# A full lift leaves on its own, with no button pressed.
	game.start_game()
	for y in 5:
		for x in 5:
			if x==4 and y==4:
				continue
			var filler = game.make_piece(0,0)
			filler.cell = Vector2i(x,y)
			game.pieces.append(filler)
	check(game.occupied()==24 and game.state=="playing","an almost full lift keeps waiting")
	game.tray[0] = game.make_piece(0,0)
	game.press(Vector2(110,930))
	game.release_drag(game.GRID+Vector2(4*86+43,4*86+43))
	check(game.occupied()==25,"the last free cell is filled")
	check(game.state=="transit","a full lift closes its doors without pressing anything")
	# Every animal must declare a full row, or draw_person crashes at runtime.
	for index in game.ANIMALS.size():
		var entry: Dictionary = game.ANIMALS[index]
		var complete = true
		for key in ["name","body","head","belly","torso","marks","feet","side","face","skull","snout","eyes","brow","patches","horns","mouth","floor"]:
			if not entry.has(key):
				complete = false
		check(complete,"animal %d declares every trait" % index)
	# The cast grows as the floors go up.
	game.start_game()
	check(game.ANIMALS.size()==7,"the cast counts seven animals")
	# Read defensively: indexing a short array aborts run() before quit(), hanging the run.
	var sixth: Dictionary = game.ANIMALS[5] if game.ANIMALS.size() > 5 else {}
	check(sixth.get("floor",0)==3,"the sixth animal waits for floor 3")
	var seventh: Dictionary = game.ANIMALS[6] if game.ANIMALS.size() > 6 else {}
	check(seventh.get("floor",0)==5,"the seventh animal waits for floor 5")
	game.floor_number = 1
	var early = {}
	for i in 400:
		early[game.make_piece(0).person] = true
	check(early.size()==5,"floor 1 draws from the five starters")
	check(not early.has(5) and not early.has(6),"neither latecomer appears on floor 1")
	game.floor_number = 3
	var middle = {}
	for i in 400:
		middle[game.make_piece(0).person] = true
	check(middle.size()==6,"floor 3 adds the sixth animal")
	check(not middle.has(6),"the seventh animal still waits on floor 3")
	game.floor_number = 5
	var late = {}
	for i in 400:
		late[game.make_piece(0).person] = true
	check(late.size()==7,"floor 5 draws from the whole cast")
	# A tap on a queue card turns the animal; a drag carries it into the lift.
	game.start_game()
	game.tray[0] = game.make_piece(1,0)
	var upright = game.tray[0].cells.duplicate()
	game.press(Vector2(110,930))
	game.release_drag(Vector2(113,933))
	check(game.tray[0].cells != upright,"a tap on the card rotates the animal")
	check(game.occupied()==0 and game.drag.is_empty(),"a tap places nothing")
	game.press(Vector2(110,930))
	game.release_drag(game.GRID+Vector2(43,43))
	check(game.occupied()==2,"a drag from the same card places the animal")
	# A drop that lands nowhere costs nothing: the animal is still in the queue.
	var queued = game.tray[1].cells.size()
	game.press(Vector2(313,930))
	game.release_drag(Vector2(700,60))
	check(game.occupied()==2,"a drop outside the grid places nothing")
	check(game.tray[1].cells.size()==queued and game.drag.is_empty(),"the animal stays in the queue")
	# The departure button is gone: nothing happens where it used to be.
	var lives_before = game.lives
	var state_before = game.state
	game.press(Vector2(360,1170))
	check(game.state==state_before and game.lives==lives_before,"the old departure button does nothing")
	var space = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	game._input(space)
	check(game.state==state_before and game.lives==lives_before,"the space bar no longer launches the lift")
	# The background theme is generated in code: it must loop, sound, and not click.
	if not game.has_method("build_music"):
		check(false,"the game builds its own background theme")
	else:
		var theme: AudioStreamWAV = game.build_music()
		var frames = theme.loop_end
		check(theme.loop_mode == AudioStreamWAV.LOOP_FORWARD,"the theme loops forward")
		check(frames > theme.mix_rate*4,"the theme runs at least four seconds")
		check(theme.data.size() >= (frames+64)*2,"the buffer carries silent padding past the loop end, so the mixer never reads outside it")
		check(theme.data.decode_s16(theme.data.size()-2) == 0,"the padding is silent")
		var peak = 0
		var idx = 0
		while idx < frames:
			peak = maxi(peak,absi(theme.data.decode_s16(idx*2)))
			idx += 128
		check(peak > 1000,"the theme actually makes sound")
		check(absi(theme.data.decode_s16((frames-1)*2)) < 400,"the theme fades at the seam, so the loop does not click")
	# Every string exists in both languages, and the device locale picks the language.
	if not ResourceLoader.exists("res://scripts/strings.gd") or not game.has_method("t"):
		check(false,"the game has a bilingual string table")
	else:
		var Strings = load("res://scripts/strings.gd")
		var missing = 0
		for key in Strings.TABLE:
			if not (Strings.TABLE[key].has("it") and Strings.TABLE[key].has("en")):
				missing += 1
		check(missing==0,"every string has both an Italian and an English version")
		check(Strings.language_for("it_IT")=="it" and Strings.language_for("it")=="it","Italian devices get Italian")
		check(Strings.language_for("en_US")=="en" and Strings.language_for("de_DE")=="en","everyone else gets English")
		game.lang = "en"
		check(game.t("hud_score")=="SCORE","the game reads its strings through the active language")
		game.lang = "it"
		check(game.t("hud_score")=="PUNTI","switching language switches every label")
		check(game.t(game.ANIMALS[3].name)=="GIRAFFA GIGI","animal names go through the table too")
	# Ads layer: where the native plugin is absent every call is a safe no-op.
	if not ResourceLoader.exists("res://scripts/ads.gd") or game.get("ads") == null:
		check(false,"the game carries an ads layer")
	else:
		check(game.ads.enabled == false,"ads stay disabled where the native plugin is absent")
		check(game.ads.show_interstitial() == false,"an interstitial cannot be shown without the plugin")
		check(game.ads.banner_reserve() == 0.0,"no space is reserved for a banner that cannot appear")
		check(game.ads.config.get("test",false) == true,"the shipped config runs on Google test ids")
		check(String(game.ads.unit("banner")).begins_with("ca-app-pub-3940256099942544/"),"the banner unit id is the official test one")
		check(String(game.ads.unit("interstitial")).begins_with("ca-app-pub-3940256099942544/"),"the interstitial unit id is the official test one")
		game.start_game()
		game.lives = 1
		game.depart()
		game._process(2)
		check(game.state=="over","game over still arrives with the ads layer in place")
	# Standing still is not free any more: the doors close and the floor is lost.
	game.start_game()
	game._process(game.time_limit+1.0)
	check(game.lives==2 and game.floor_number==1,"an untouched floor costs a life and is retried")
	if failures > 0:
		print("%d CHECKS FAILED, %d passed" % [failures, checks])
		quit(1)
		return
	print("ALL %d CHECKS PASSED" % checks)
	quit(0)
