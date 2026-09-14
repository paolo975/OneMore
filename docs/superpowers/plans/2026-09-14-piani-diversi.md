# Piani diversi — piano di lavoro

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendere ogni piano di "Ancora uno!" visibilmente diverso e dare obiettivi leggibili a un pubblico di 4-6 anni (bagagli, forme più grandi prima, stelle, festa per l'amico nuovo, rimbalzo), e far comparire davvero la pubblicità su Android.

**Architecture:** Tutto il gioco vive in `scripts/game.gd` (un solo `Control` che disegna e gestisce input, regole e audio): ogni meccanica aggiunge qualche variabile di stato, una o due funzioni e un pezzo di `_draw`. Lo strato pubblicità `scripts/ads.gd` viene riscritto per aspettare il callback di inizializzazione dell'SDK prima di caricare. I test sono un unico script `tests/game_test.gd` che estende `SceneTree`, istanzia la scena e verifica con `check(cond, msg)`; per la pubblicità `run()` diventa una coroutine che aspetta il mock del plugin.

**Tech Stack:** Godot 4.6 (GDScript, `gl_compatibility`), Godot AdMob Plugin di Poing Studios v5.0.0, PowerShell per `tools/*.ps1`, Android SDK (`adb`, `aapt`) in `%LOCALAPPDATA%\AncoraUnoTools`.

**Spec:** `docs/superpowers/specs/2026-09-14-piani-diversi-design.md`

## Global Constraints

- Il pubblico non legge: ogni novità deve capirsi guardando. La casella singola sempre in coda (terza carta) **resta**.
- Vite, timer, formula del punteggio, musica: **intoccati**.
- Codice di gioco in `scripts/game.gd`; stringhe in `scripts/strings.gd` con entrambe le colonne `it` e `en`; test in `tests/game_test.gd`.
- Commenti nel codice e messaggi dei test in **inglese** (come il codice esistente); prosa di README/MIGLIORIE e messaggi di commit in **italiano**.
- Test prima del codice. Ogni blocco nuovo di test va protetto con `has_method(...)` / `get(...)`: un errore a runtime dentro `run()` blocca il processo di Godot invece di far fallire il test (vedi il commento "indexing a short array aborts run() before quit(), hanging the run" già presente nel file).
- Comando di test: `powershell -ExecutionPolicy Bypass -File tools/test.ps1` (fa prima `--import`, poi lancia i test in headless; stampa il log e lancia un'eccezione se l'exit code non è 0). Oggi termina con `ALL 139 CHECKS PASSED`.
- Ogni commit finisce con la riga `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Scrivere il messaggio in un file e usare `git commit -F`: un heredoc annidato in `$(...)` ha già rotto il parser di bash una volta.
- La pubblicità su PC (mock del plugin) si tiene solo se non fa perdere tempo: se il mock non regge l'headless, applicare la contingenza del Task 6 e verificare solo su Android.

---

### Task 1: Bagagli

**Files:**
- Modify: `scripts/game.gd` (costanti/variabili dopo la riga 66; `demo_board` righe 101-105; `new_round` 135-150; `can_place` 158-167; `release_drag` riga 262; `_draw` righe 648-654; nuove funzioni)
- Test: `tests/game_test.gd` (nuovo blocco prima di `if failures > 0:`, riga 255)

**Interfaces:**
- Produces: `luggage: Array` di `{"cell": Vector2i, "kind": int}`; `luggage_count(floor_id: int) -> int`; `place_luggage() -> void`; `capacity() -> int`; `blocked(cell: Vector2i) -> bool`; `draw_luggage(kind: int, at: Vector2, unit: float) -> void`; costanti `LUGGAGE_KINDS`, `GOLD`, `GREY`. `target` ora vale `mini(mini(20, 10 + floor_number - 1), capacity() - 3)`.

- [ ] **Step 1: Scrivere i test (falliranno)**

In `tests/game_test.gd`, subito prima della riga `if failures > 0:` (riga 255), inserire:

```gdscript
	# Luggage: cells already taken when the floor opens, more of them the higher you go.
	if not game.has_method("luggage_count") or game.get("luggage") == null:
		check(false,"the game knows how much luggage each floor carries")
	else:
		for pair in [[1,0],[2,1],[3,2],[5,3],[7,4],[9,5],[20,5]]:
			check(game.luggage_count(pair[0])==pair[1],"floor %d carries %d pieces of luggage" % [pair[0],pair[1]])
		game.floor_number = 9
		game.new_round()
		check(game.luggage.size()==5,"the round places as much luggage as the floor says")
		var seen = {}
		var inside = true
		for item in game.luggage:
			seen[item.cell] = true
			if item.cell.x < 0 or item.cell.y < 0 or item.cell.x >= 5 or item.cell.y >= 5:
				inside = false
		check(seen.size()==5 and inside,"luggage sits on distinct cells inside the grid")
		check(game.capacity()==20,"capacity is the grid minus the luggage")
		check(game.occupied()==0,"luggage does not count as animals aboard")
		var single = game.make_piece(0,0)
		check(not game.can_place(single,game.luggage[0].cell),"an animal cannot stand on the luggage")
		for floor_id in range(1,40):
			game.floor_number=floor_id
			game.new_round()
			check(game.target<=game.capacity()-3,"at least three free cells beyond the minimum on floor %d" % floor_id)
		# A lift full around the luggage leaves on its own.
		game.floor_number = 2
		game.new_round()
		check(game.luggage.size()==1 and game.capacity()==24,"floor 2 has one piece of luggage")
		var last = Vector2i(-1,-1)
		for y in 5:
			for x in 5:
				var cell = Vector2i(x,y)
				if game.blocked(cell):
					continue
				if last.x < 0:
					last = cell
					continue
				var filler = game.make_piece(0,0)
				filler.cell = cell
				game.pieces.append(filler)
		check(game.occupied()==23 and game.state=="playing","23 animals around one suitcase keep waiting")
		game.tray[0] = game.make_piece(0,0)
		game.press(Vector2(110,930))
		game.release_drag(game.GRID+Vector2(last)*game.CELL+Vector2(43,43))
		check(game.occupied()==24 and game.state=="transit","the lift leaves when every cell not taken by luggage is filled")
		# Long enough to end any transit, including the stretched one the newcomer will bring later.
		game._process(4)
```

- [ ] **Step 2: Eseguire i test e vedere il fallimento**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: una riga `FAIL: the game knows how much luggage each floor carries`, poi `1 CHECKS FAILED, 139 passed` e l'eccezione `Test falliti: 1`.

- [ ] **Step 3: Aggiungere costanti e stato**

In `scripts/game.gd`, dopo la riga 66 (`var last_tick = -1`) aggiungere:

```gdscript
const LUGGAGE_KINDS = 3
const GOLD = Color("efc66e")
const GREY = Color("d7cec1")
var luggage: Array = []
```

- [ ] **Step 4: Conteggio, posizionamento, capacità**

Dopo `unlocked_animals()` (che termina alla riga 112) aggiungere:

```gdscript
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

func blocked(cell: Vector2i) -> bool:
	for item in luggage:
		if item.cell == cell:
			return true
	return false
```

- [ ] **Step 5: Agganciare `new_round`, `can_place`, `release_drag`, `demo_board`**

In `new_round()` sostituire

```gdscript
	target = mini(20, 10 + floor_number - 1)
```

con

```gdscript
	place_luggage()
	# At least three free cells beyond the minimum, however much luggage there is.
	target = mini(mini(20, 10 + floor_number - 1), capacity() - 3)
```

In `can_place()` sostituire

```gdscript
		if c.x < 0 or c.y < 0 or c.x >= SIDE or c.y >= SIDE:
			return false
```

con

```gdscript
		if c.x < 0 or c.y < 0 or c.x >= SIDE or c.y >= SIDE or blocked(c):
			return false
```

In `release_drag()` sostituire `if occupied() >= SIDE*SIDE:` con `if occupied() >= capacity():`.

In `demo_board()` aggiungere in coda alla funzione:

```gdscript
	luggage = [{"cell":Vector2i(4,3),"kind":0}, {"cell":Vector2i(0,4),"kind":1}]
```

- [ ] **Step 6: Disegnare i bagagli**

In `_draw()` sostituire

```gdscript
	for p in pieces:
		draw_person(p,GRID+Vector2(p.cell)*CELL,CELL)
```

con

```gdscript
	for item in luggage:
		draw_luggage(item.kind, GRID+Vector2(item.cell)*CELL, CELL)
	for p in pieces:
		draw_person(p,GRID+Vector2(p.cell)*CELL,CELL)
```

Dopo `heart()` (righe 433-437) aggiungere:

```gdscript
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
```

- [ ] **Step 7: Eseguire i test e vederli passare**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: nessuna riga `FAIL`, ultima riga `ALL N CHECKS PASSED` con N > 139. I 139 vecchi restano verdi: i test che partono dal piano 1 non hanno bagagli, `difficulty increases` trova ancora `target == 11` al piano 2 (`mini(11, 24-3)`), `bounded difficulty` vale ancora.

- [ ] **Step 8: Anteprima con i bagagli**

Run (PowerShell): `& "$env:LOCALAPPDATA\AncoraUnoTools\Godot\Godot_v4.6-stable_win64.exe" --path . -- --screenshot`
Expected: il processo si chiude da solo e `artifacts/anteprima.png` mostra una valigia in basso a destra e una pianta in basso a sinistra della griglia. Aprire l'immagine con lo strumento Read per controllare che i tre oggetti si leggano.

- [ ] **Step 9: Commit**

```bash
git add scripts/game.gd tests/game_test.gd
git commit -F <file con il messaggio>
```

Messaggio:

```
Bagagli sul pavimento dell'ascensore dal secondo piano

Caselle già occupate da valigie, piante e scatole: una al piano 2, poi una in
più ogni due piani fino a cinque. Gli animali non ci salgono, la capacità cala
di conseguenza e il minimo lascia sempre almeno tre caselle libere.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

---

### Task 2: Forme grandi prima

**Files:**
- Modify: `scripts/game.gd:117`
- Test: `tests/game_test.gd` (in coda al blocco del Task 1, dentro lo stesso `else`)

**Interfaces:**
- Consumes: `make_piece(shape_index: int = -1, person: int = -1) -> Dictionary`, `SHAPES`.
- Produces: tetto delle forme `mini(6, 3 + (floor_number - 1) / 2)`.

- [ ] **Step 1: Scrivere il test (fallirà)**

In coda al blocco `else:` del Task 1 (dopo `game._process(2)`), stesso livello di indentazione:

```gdscript
		# Bigger shapes arrive sooner: the L from floor 1, the square from 3, the bar from 5, the T from 7.
		for pair in [[1,3],[3,4],[5,5],[7,6]]:
			game.floor_number = pair[0]
			var biggest = -1
			for i in 400:
				biggest = maxi(biggest, game.SHAPES.find(game.make_piece().cells))
			check(biggest==pair[1],"floor %d deals shapes up to index %d" % [pair[0],pair[1]])
```

- [ ] **Step 2: Eseguire i test e vedere il fallimento**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: quattro FAIL, uno per piano. Con la formula di oggi (`2 + piano/3`) il tetto vale 2 al piano 1, 3 al piano 3, 3 al piano 5 e 4 al piano 7; il test pretende 3, 4, 5, 6.

- [ ] **Step 3: Cambiare la formula**

In `make_piece()` sostituire

```gdscript
		shape_index = rng.randi_range(0, mini(6, 2 + floor_number / 3))
```

con

```gdscript
		# The L from the first floor, the square from the third, the bar from the fifth, the T from the seventh.
		shape_index = rng.randi_range(0, mini(6, 3 + (floor_number - 1) / 2))
```

- [ ] **Step 4: Eseguire i test e vederli passare**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `ALL N CHECKS PASSED`.

- [ ] **Step 5: Commit**

```
Forme più grandi prima: la L dal piano 1, il quadrato dal 3, la T dal 7

Il tetto delle forme passa da 2 + piano/3 a 3 + (piano-1)/2. Il tetramino a T
arrivava al piano 12, che nessun bambino raggiunge.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

---

### Task 3: Stelle

**Files:**
- Modify: `scripts/game.gd` (costanti; `start_game`; `depart`; `_process` transito; `_draw` dopo le porte e nella schermata finale; nuove funzioni `stars_for`, `transit_cues`, `star_points`, `draw_transit`)
- Modify: `scripts/strings.gd` (`hud_goal_done`)
- Test: `tests/game_test.gd`

**Interfaces:**
- Consumes: `target`, `capacity()`, `occupied()`, `tone(frequency, duration)`, `confetti`, `transit_time`.
- Produces: `stars_for(count: int) -> int`; `round_stars: int`; `run_stars: int`; `cues_played: int`; `transit_cues() -> Array` di `[tempo: float, frequenza: float]`; `star_points(centre: Vector2, radius: float) -> PackedVector2Array`; `draw_transit() -> void`; costanti `STAR_TIMES = [0.4, 0.7, 1.0]`, `STAR_TONES = [700.0, 900.0, 1100.0]`. Il Task 4 estende `transit_cues()` e `draw_transit()`.

- [ ] **Step 1: Scrivere i test (falliranno)**

Sempre in coda al blocco `else:` del Task 1:

```gdscript
		# Stars: one for the minimum, two half way to full, three for a full lift.
		if not game.has_method("stars_for") or game.get("run_stars") == null:
			check(false,"the game rates every floor with stars")
		else:
			game.floor_number = 1
			game.new_round()
			check(game.target==10 and game.capacity()==25,"floor 1 asks for 10 of 25")
			check(game.stars_for(9)==0 and game.stars_for(10)==1 and game.stars_for(16)==1,"the minimum earns one star")
			check(game.stars_for(17)==2 and game.stars_for(24)==2,"half way between minimum and full earns two")
			check(game.stars_for(25)==3,"a full lift earns three")
			game.start_game()
			check(game.run_stars==0,"a new game starts with no stars")
			for y in 2:
				for x in 5:
					var p = game.make_piece(0,1)
					p.cell = Vector2i(x,y)
					game.pieces.append(p)
			game.confetti.clear()
			game.depart()
			check(game.round_stars==1 and game.run_stars==1,"ten animals earn one star")
			check(game.confetti.size()==15,"confetti scale with the stars")
			game._process(2)
			game.depart()
			check(game.round_stars==0 and game.run_stars==1 and game.lives==2,"a failed floor earns nothing and costs a life")
			game._process(2)
```

- [ ] **Step 2: Eseguire i test e vedere il fallimento**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `FAIL: the game rates every floor with stars`, un solo FAIL.

- [ ] **Step 3: Costanti e stato**

Sotto le costanti del Task 1 aggiungere:

```gdscript
const STAR_TIMES = [0.4, 0.7, 1.0]
const STAR_TONES = [700.0, 900.0, 1100.0]
var round_stars = 0
var run_stars = 0
var cues_played = 0
```

In `start_game()` aggiungere `run_stars = 0` dopo `floor_number = 1`.

- [ ] **Step 4: `stars_for` e `depart`**

Dopo `capacity()` aggiungere:

```gdscript
# The floor's rating: the minimum is one star, half way to full is two, a full lift is three.
func stars_for(count: int) -> int:
	if count < target:
		return 0
	if count >= capacity():
		return 3
	if count >= target + (capacity() - target) / 2:
		return 2
	return 1
```

In `depart()` sostituire

```gdscript
	transit_success = occupied() >= target
	if transit_success:
		var bonus = occupied()*10 + int(time_left)*2
		score += bonus
		toast = t("toast_aboard") % bonus
		tone(880,0.22)
		for i in 36:
```

con

```gdscript
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
```

- [ ] **Step 5: Suoni durante il transito**

Dopo `stars_for()` aggiungere:

```gdscript
# Sound cues of the current transit, as [time, frequency]: one rising tone per star lit.
func transit_cues() -> Array:
	var cues: Array = []
	for k in round_stars:
		cues.append([STAR_TIMES[k], STAR_TONES[k]])
	return cues
```

In `_process()` sostituire

```gdscript
	if state == "transit":
		transit_time += delta
		door = lerpf(door_at_depart,1.0,clampf(transit_time*2,0,1))
		if transit_time > 1.6:
```

con

```gdscript
	if state == "transit":
		transit_time += delta
		door = lerpf(door_at_depart,1.0,clampf(transit_time*2,0,1))
		var cues = transit_cues()
		while cues_played < cues.size() and transit_time >= cues[cues_played][0]:
			tone(cues[cues_played][1],0.1)
			cues_played += 1
		if transit_time > 1.6:
```

- [ ] **Step 6: Disegno delle stelle**

Dopo `heart()` aggiungere:

```gdscript
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
```

In `_draw()`, subito prima del commento `# Timer and explicit capacity goal.`, inserire:

```gdscript
	if state == "transit":
		draw_transit()
```

Nella schermata finale sostituire

```gdscript
			centered(t("over_floor") % floor_number,631,23)
```

con

```gdscript
			centered(t("over_floor") % floor_number,631,23)
			draw_colored_polygon(star_points(Vector2(300,658),14),GOLD)
			label_at("× %d" % run_stars,Vector2(322,666),22)
```

- [ ] **Step 7: La frase che il genitore legge**

In `scripts/strings.gd` sostituire la riga `hud_goal_done` con:

```gdscript
	"hud_goal_done": {"it":"MINIMO RAGGIUNTO! Riempi tutto per tre stelle.", "en":"MINIMUM REACHED! Fill it all for three stars."},
```

- [ ] **Step 8: Eseguire i test e vederli passare**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `ALL N CHECKS PASSED`. Il vecchio `successful departure scores cells and time` (168 punti) non cambia: la formula del punteggio è la stessa.

- [ ] **Step 9: Commit**

```
Stelle a fine piano: una per il minimo, due a metà strada, tre a pieno

Sulle porte chiuse tre sagome grigie si accendono d'oro una alla volta con un
tono in salita; i coriandoli seguono le stelle e il totale della partita è
sulla schermata finale. Il punteggio non cambia formula.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

---

### Task 4: Festa per l'amico nuovo

**Files:**
- Modify: `scripts/game.gd` (costanti; `new_round`; `depart`; `_process`; `transit_cues`; `draw_transit`; nuova `transit_length`)
- Modify: `scripts/strings.gd` (`toast_newcomer`)
- Test: `tests/game_test.gd`

**Interfaces:**
- Consumes: `ANIMALS[i].floor`, `SHAPES[4]`, `draw_person(p, origin, unit)`, `centered(text, y, size_px)`, `transit_cues()`, `draw_transit()`, `cues_played`.
- Produces: `newcomer: int` (−1 se nessuno); `transit_length() -> float`; costanti `TRANSIT_SHORT = 1.6`, `TRANSIT_LONG = 3.4`, `FANFARE_TIMES = [1.3, 1.5, 1.7]`, `FANFARE_TONES = [660.0, 880.0, 1320.0]`; stringa `toast_newcomer`.

- [ ] **Step 1: Scrivere i test (falliranno)**

In coda al blocco `else:` delle stelle (Task 3), stesso livello:

```gdscript
			# The floor that brings a new animal celebrates it with a longer transit.
			if not game.has_method("transit_length") or game.get("newcomer") == null:
				check(false,"the game announces a new animal")
			else:
				game.start_game()
				check(game.transit_length()==1.6,"an ordinary transit lasts 1.6 seconds")
				game.floor_number = 2
				game.new_round()
				for y in 5:
					for x in 3:
						var cell = Vector2i(x,y)
						if game.blocked(cell):
							continue
						var p = game.make_piece(0,0)
						p.cell = cell
						game.pieces.append(p)
				game.depart()
				check(game.transit_success and game.newcomer==5,"leaving floor 2 announces the sixth animal")
				check(game.transit_length()==3.4,"the announcement stretches the transit")
				game._process(2)
				check(game.state=="transit","two seconds in, the newcomer is still on stage")
				game._process(1.5)
				check(game.state=="playing" and game.floor_number==3 and game.newcomer==-1,"the lift then opens on floor 3 with the stage cleared")
				game.start_game()
				game.pieces.clear()
				for y in 2:
					for x in 5:
						var p = game.make_piece(0,0)
						p.cell = Vector2i(x,y)
						game.pieces.append(p)
				game.depart()
				check(game.newcomer==-1 and game.transit_length()==1.6,"leaving floor 1 announces nobody")
				game._process(2)
```

- [ ] **Step 2: Eseguire i test e vedere il fallimento**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `FAIL: the game announces a new animal`, un solo FAIL.

- [ ] **Step 3: Costanti, stato, durata**

Sotto le costanti del Task 3 aggiungere:

```gdscript
const TRANSIT_SHORT = 1.6
const TRANSIT_LONG = 3.4
const FANFARE_TIMES = [1.3, 1.5, 1.7]
const FANFARE_TONES = [660.0, 880.0, 1320.0]
var newcomer = -1
```

Dopo `transit_cues()` aggiungere:

```gdscript
# The transit stretches when there is a new animal to introduce.
func transit_length() -> float:
	return TRANSIT_LONG if newcomer >= 0 else TRANSIT_SHORT
```

In `new_round()` aggiungere `newcomer = -1` subito dopo `state = "playing"`.

In `_process()` sostituire `if transit_time > 1.6:` con `if transit_time > transit_length():`.

- [ ] **Step 4: Chi arriva al piano dopo**

In `depart()`, dentro `if transit_success:`, dopo `tone(880,0.22)` aggiungere:

```gdscript
		# The animal whose floor is the next one steps on stage during the transit.
		for i in ANIMALS.size():
			if ANIMALS[i].floor == floor_number + 1:
				newcomer = i
```

- [ ] **Step 5: Fanfara**

Sostituire `transit_cues()` con:

```gdscript
# Sound cues of the current transit, as [time, frequency]: one rising tone per star lit,
# then a three-note fanfare when a new animal steps on stage.
func transit_cues() -> Array:
	var cues: Array = []
	for k in round_stars:
		cues.append([STAR_TIMES[k], STAR_TONES[k]])
	if newcomer >= 0:
		for k in 3:
			cues.append([FANFARE_TIMES[k], FANFARE_TONES[k]])
	return cues
```

- [ ] **Step 6: Il riflettore**

In coda a `draw_transit()` aggiungere:

```gdscript
	# The newcomer under a spotlight, bouncing, with the fanfare: the stars had their moment already.
	if newcomer >= 0 and transit_time >= FANFARE_TIMES[0]:
		var bounce = absf(sin((transit_time-FANFARE_TIMES[0])*6))*30
		draw_circle(Vector2(360,545), 175, CREAM)
		draw_arc(Vector2(360,545), 175, 0, TAU, 64, INK, 3, true)
		centered(t("toast_newcomer"), 400, 26)
		draw_person({"cells":SHAPES[4], "person":newcomer, "cell":Vector2i.ZERO}, Vector2(250,445-bounce), 110)
		centered(t(ANIMALS[newcomer].name), 705, 28)
```

In `scripts/strings.gd`, dopo la riga `toast_fail`, aggiungere:

```gdscript
	"toast_newcomer": {"it":"Nuovo amico!", "en":"New friend!"},
```

- [ ] **Step 7: Eseguire i test e vederli passare**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `ALL N CHECKS PASSED`. Il controllo `every string has both an Italian and an English version` copre la stringa nuova.

- [ ] **Step 8: Guardarlo**

Run (PowerShell): `powershell -ExecutionPolicy Bypass -File tools/run.ps1`
Giocare fino al piano 3 (o, per fare prima, in `_ready()` mettere temporaneamente `floor_number = 2` dopo `rng.randomize()` e toglierlo subito dopo). Alla partenza dal piano 2: stelle, poi il riflettore con Elefante Elmo che rimbalza e la fanfara. Il riflettore copre le stelle da 1,3 s: è voluto.

- [ ] **Step 9: Commit**

```
Festa per l'amico nuovo: riflettore, rimbalzo e fanfara al piano 3 e 5

Alla partenza riuscita dal piano che precede l'arrivo di un animale il transito
dura 3,4 secondi e lo presenta al centro delle porte. Oggi Elmo e Tea entravano
in coda senza che nessuno lo annunciasse.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

---

### Task 5: Rimbalzo dell'animale appena salito

**Files:**
- Modify: `scripts/game.gd` (`release_drag`; ciclo dei pezzi in `_draw`)
- Test: `tests/game_test.gd`

**Interfaces:**
- Consumes: `elapsed`, `draw_person(p, origin, unit)`.
- Produces: campo `born: float` sui pezzi piazzati con `release_drag`.

- [ ] **Step 1: Scrivere il test (fallirà)**

In coda al blocco `else:` del Task 1 (stesso livello dei test dei bagagli, dopo il blocco stelle/festa):

```gdscript
		# An animal that has just boarded remembers when, so it can bounce for a moment.
		game.start_game()
		game.tray[0] = game.make_piece(0,0)
		game.press(Vector2(110,930))
		game.release_drag(game.GRID+Vector2(43,43))
		check(game.occupied()==1 and game.pieces[0].has("born"),"a placed animal carries its boarding time")
		check(not game.make_piece(0,0).has("born"),"animals in the queue have not boarded yet")
```

- [ ] **Step 2: Eseguire i test e vedere il fallimento**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `FAIL: a placed animal carries its boarding time`.

- [ ] **Step 3: Segnare l'istante**

In `release_drag()` sostituire

```gdscript
		drag.cell = cell
		pieces.append(drag.duplicate(true))
```

con

```gdscript
		drag.cell = cell
		drag.born = elapsed
		pieces.append(drag.duplicate(true))
```

- [ ] **Step 4: Scalare per 0,3 s**

In `_draw()` sostituire

```gdscript
	for p in pieces:
		draw_person(p,GRID+Vector2(p.cell)*CELL,CELL)
```

con

```gdscript
	for p in pieces:
		var origin = GRID+Vector2(p.cell)*CELL
		var unit = CELL
		# A fresh arrival swells for a third of a second, around its own centre.
		var age = elapsed - p.get("born", -10.0)
		if age < 0.3:
			# Not "scale": that would shadow Control.scale.
			var swell = 1.0 + 0.12*sin(PI*age/0.3)
			var span = Vector2.ONE
			for c in p.cells:
				span.x = maxf(span.x, c.x+1)
				span.y = maxf(span.y, c.y+1)
			var centre = origin + span*CELL*0.5
			origin = centre + (origin-centre)*swell
			unit = CELL*swell
		draw_person(p,origin,unit)
```

- [ ] **Step 5: Eseguire i test e vederli passare**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `ALL N CHECKS PASSED`.

- [ ] **Step 6: Commit**

```
L'animale appena salito rimbalza per un terzo di secondo

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

---

### Task 6: Pubblicità che compare davvero

**Files:**
- Rewrite: `scripts/ads.gd`
- Test: `tests/game_test.gd` (blocco esistente righe 237-250; `run()` diventa coroutine; blocco finale asincrono)

**Interfaces:**
- Consumes (plugin, `addons/admob/gdscript/src`): `MobileAds.initialize(listener: OnInitializationCompleteListener)`, `MobileAds.set_request_configuration(RequestConfiguration)`, `OnInitializationCompleteListener.on_initialization_complete: Callable(status)`, `AdView.new(unit_id, AdSize, AdPosition)`, `AdView.ad_listener: AdListener` con `on_ad_loaded: Callable()` e `on_ad_failed_to_load: Callable(LoadAdError)`, `AdView.load_ad(AdRequest)`, `AdView.show()`, `AdView.destroy()`, `AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)`, `AdPosition.BOTTOM`, `InterstitialAdLoader.new().load(unit_id, AdRequest, InterstitialAdLoadCallback)`, `InterstitialAdLoadCallback.on_ad_loaded: Callable(InterstitialAd)` / `on_ad_failed_to_load: Callable(LoadAdError)`, `InterstitialAd.show()/destroy()/full_screen_content_callback`, `LoadAdError.code: int`, `LoadAdError.message: String`. In editor (`OS.has_feature("editor")`, non Android/iOS) ogni classe usa il mock di `addons/admob/internal/mock/`: `initialize()` emette il callback dopo 0,5 s, le load emettono `on_*_loaded` dopo 0,5 s.
- Produces: `ads.enabled`, `ads.initialized`, `ads.banner_wanted`, `ads.banner_loaded`, `ads.has_plugin() -> bool`, `ads.show_banner()`, `ads.preload_interstitial()`, `ads.show_interstitial() -> bool`, `ads.banner_reserve() -> float` (invariati nel nome, cambiano nel comportamento). Stampe con prefisso `AdMob:` per `tools/logcat.ps1`.

- [ ] **Step 1: Aggiornare il blocco sincrono dei test (fallirà)**

In `tests/game_test.gd` sostituire le tre righe

```gdscript
		check(game.ads.enabled == false,"ads stay disabled where the native plugin is absent")
		check(game.ads.show_interstitial() == false,"an interstitial cannot be shown without the plugin")
		check(game.ads.banner_reserve() == 0.0,"no space is reserved for a banner that cannot appear")
```

con

```gdscript
		# In editor builds the plugin ships a mock, so the layer is on; on a phone without the plugin it stays off.
		check(game.ads.enabled,"the ads layer runs on the plugin's editor mock where the native plugin is absent")
		check(game.ads.get("initialized") == false and game.ads._banner == null and game.ads.get("banner_wanted") == true,"a banner asked for before the SDK is ready is remembered, not loaded")
		check(game.ads.show_interstitial() == false,"an interstitial cannot be shown before it is loaded")
		check(game.ads.banner_reserve() == 90.0,"the layout keeps a strip for the banner")
```

- [ ] **Step 2: Aggiungere il blocco asincrono (fallirà)**

Subito prima di `if failures > 0:` (ora dopo tutti i blocchi dei Task 1-5) inserire:

```gdscript
	# The ads layer loads nothing until the SDK says it is ready; the editor mock answers in half a second.
	if game.ads.get("initialized") == null:
		check(false,"the ads layer waits for the SDK before loading")
	else:
		await create_timer(0.7).timeout
		check(game.ads.initialized,"the ads layer hears the initialisation callback")
		check(game.ads._banner != null,"the banner asked for before initialisation is created afterwards")
		await create_timer(0.7).timeout
		check(game.ads.banner_loaded,"the banner loads once the SDK is ready")
		check(game.ads._interstitial != null,"the interstitial is preloaded by the initialisation callback")
		check(game.ads.show_interstitial(),"a loaded interstitial goes on screen")
		check(game.ads._interstitial == null,"a shown interstitial is consumed")
```

`run()` contiene ora `await`, quindi è una coroutine: `call_deferred("run")` in `_initialize()` la avvia e il main loop di Godot continua a girare finché `quit()` non viene chiamato in coda. Nessun'altra modifica al harness.

- [ ] **Step 3: Eseguire i test e vedere il fallimento**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `FAIL: the ads layer runs on the plugin's editor mock ...`, `FAIL: a banner asked for before the SDK is ready ...`, `FAIL: the layout keeps a strip for the banner`, `FAIL: the ads layer waits for the SDK before loading`. Se invece il processo **non termina** entro un minuto, ucciderlo (`Stop-Process -Name Godot_v4.6-stable_win64`) e passare allo Step 4: era il blocco sincrono a inciampare su una proprietà mancante, cosa che la riscrittura risolve.

- [ ] **Step 4: Riscrivere `scripts/ads.gd`**

Contenuto completo del file:

```gdscript
extends Node

# Ads through the Poing AdMob plugin. Where neither the native singleton nor the mock the plugin
# ships for editor builds exists — the exported Windows build, a phone without the plugin — every
# call is a no-op: the game never waits on an ad. The GMA Next-Gen SDK initialises asynchronously
# and throws if asked to load before it has finished, so every load waits for its callback.
# Unit ids come from res://ads.cfg; the App ID lives in project.godot under [admob].

const BANNER_RESERVE = 90.0

var enabled = false
var initialized = false
var banner_wanted = false
var banner_loaded = false
var config = {"test": true}
var _ids = {}
var _banner = null
var _interstitial = null
var _loading = false

func _ready() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("res://ads.cfg") == OK:
		config["test"] = bool(cfg.get_value("ads", "test", true))
		var section = "test" if config["test"] else "production"
		_ids = {
			"banner": str(cfg.get_value(section, "banner", "")),
			"interstitial": str(cfg.get_value(section, "interstitial", "")),
		}
	enabled = has_plugin() and unit("banner") != ""
	if not enabled:
		return
	# The audience is children: child-directed treatment, G-rated, hence non-personalised.
	var rules = RequestConfiguration.new()
	rules.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE
	rules.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	MobileAds.set_request_configuration(rules)
	var listener = OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_initialized
	MobileAds.initialize(listener)

# The native plugin on a phone, or the mock the plugin provides in editor builds.
func has_plugin() -> bool:
	return Engine.has_singleton("PoingGodotAdMob") or OS.has_feature("editor")

func _on_initialized(_status) -> void:
	initialized = true
	print("AdMob: inizializzato")
	preload_interstitial()
	if banner_wanted:
		show_banner()

func unit(kind: String) -> String:
	return str(_ids.get(kind, ""))

# Height, in canvas units, to keep clear at the bottom for the anchored banner.
func banner_reserve() -> float:
	return BANNER_RESERVE if enabled else 0.0

func show_banner() -> void:
	if not enabled:
		return
	banner_wanted = true
	if not initialized:
		return
	if _banner == null:
		var size = AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
		_banner = AdView.new(unit("banner"), size, AdPosition.BOTTOM)
		var listener = AdListener.new()
		listener.on_ad_loaded = func() -> void:
			banner_loaded = true
			print("AdMob: banner caricato")
		listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
			print("AdMob: banner fallito codice %d: %s" % [error.code, error.message])
			# Drop the empty view, so the next game asks again instead of showing nothing forever.
			_banner.destroy()
			_banner = null
			banner_loaded = false
		_banner.ad_listener = listener
		_banner.load_ad(AdRequest.new())
	else:
		_banner.show()

func hide_banner() -> void:
	if _banner != null:
		_banner.hide()

func preload_interstitial() -> void:
	if not enabled or not initialized or _interstitial != null or _loading:
		return
	_loading = true
	var callback = InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		_loading = false
		print("AdMob: interstitial caricato")
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading = false
		print("AdMob: interstitial fallito codice %d: %s" % [error.code, error.message])
	InterstitialAdLoader.new().load(unit("interstitial"), AdRequest.new(), callback)

# Returns true only if an ad actually went on screen; the caller never blocks on it.
func show_interstitial() -> bool:
	if not enabled or _interstitial == null:
		preload_interstitial()
		return false
	var ad = _interstitial
	_interstitial = null
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		preload_interstitial()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		ad.destroy()
		preload_interstitial()
	print("AdMob: interstitial mostrato")
	ad.show()
	return true
```

- [ ] **Step 5: Eseguire i test e vederli passare**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `ALL N CHECKS PASSED`; nel log compaiono anche `AdMob: inizializzato`, `AdMob: banner caricato`, `AdMob: interstitial caricato`, `AdMob: interstitial mostrato` stampate dal mock. Con la fascia da 90 unità i tocchi dei test a `y = 930` restano dentro le carte (866-1016).

**Contingenza (solo se il mock non regge l'headless: errori `mock_ad_view_plugin.gd` / `DisplayServer` nel log, o processo che non termina).** Non spendere più di un tentativo di diagnosi. Applicare:
1. in `has_plugin()`: `return Engine.has_singleton("PoingGodotAdMob") or (OS.has_feature("editor") and DisplayServer.get_name() != "headless")`;
2. nel blocco sincrono dei test tornare a `check(game.ads.enabled == false, "ads stay disabled where neither plugin nor mock is present")`, `check(game.ads.show_interstitial() == false, ...)`, `check(game.ads.banner_reserve() == 0.0, ...)` e togliere il controllo su `initialized/banner_wanted`;
3. cancellare il blocco asincrono dello Step 2 (e con lui gli `await`);
4. annotare in `MIGLIORIE.md` §8 (Task 7) che la sequenza si verifica solo sul telefono.

- [ ] **Step 6: Su PC, se il mock è rimasto acceso**

Run: `powershell -ExecutionPolicy Bypass -File tools/run.ps1`
Expected: toccando ENTRA IN ASCENSORE compare in basso un rettangolo bianco con una `×` (il banner finto) e le carte in coda sono più basse di 90 unità; al game over uno schermo nero con l'icona del plugin (l'interstitial finto), che si chiude con la sua `×`.

- [ ] **Step 7: Commit**

```
Pubblicità: aspetta l'inizializzazione dell'SDK prima di caricare

L'SDK Next-Gen di AdMob è asincrono e solleva un'eccezione se si carica prima
del callback: ads.gd caricava banner e interstitial appena si toccava ENTRA IN
ASCENSORE, l'AdView restava vuoto e l'interstitial bloccato in caricamento per
sempre. Ora ogni load aspetta il callback, un banner fallito viene ritentato e
tutti gli esiti finiscono nel log con prefisso "AdMob:". In editor il layer gira
sul mock del plugin, così la sequenza è coperta dai test headless.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

---

### Task 7: Documentazione

**Files:**
- Modify: `README.md` (sezione "Giocare", sezione "Pubblicità (AdMob)")
- Modify: `MIGLIORIE.md` (nuove sezioni 8 e 9 prima di `---` / "Da valutare al prossimo playtest")

- [ ] **Step 1: README, sezione "Giocare"**

Sostituire il punto

```
- Se riempi tutte e 25 le caselle l'ascensore parte subito, senza aspettare il timer.
```

con

```
- Se riempi tutte le caselle libere l'ascensore parte subito, senza aspettare il timer.
- Dal secondo piano alcune caselle sono già occupate da **bagagli** lasciati in ascensore — valigie, piante, scatole: uno al piano 2, poi uno in più ogni due piani fino a cinque dal piano 9. Gli animali non ci salgono sopra e il minimo lascia sempre almeno tre caselle libere oltre l'obiettivo.
- A ogni partenza riuscita le porte chiuse mostrano da una a tre **stelle**: una per il minimo, due a metà strada tra minimo e ascensore pieno, tre per l'ascensore pieno. Il totale della partita è sulla schermata finale, accanto al punteggio.
- Quando un animale nuovo entra nel cast il transito si allunga e lo presenta sotto un riflettore, con rimbalzo e fanfara: Elefante Elmo alla partenza dal piano 2, Tartaruga Tea da quello 4.
```

Sostituire il punto

```
- Il cast cresce salendo: i primi cinque animali ci sono da subito, Elefante Elmo entra in coda dal piano 3 e Tartaruga Tea dal piano 5.
```

con

```
- Il cast cresce salendo: i primi cinque animali ci sono da subito, Elefante Elmo entra in coda dal piano 3 e Tartaruga Tea dal piano 5. Crescono anche le forme: la L c'è dal primo piano, il quadrato dal terzo, la barra da tre dal quinto, la T dal settimo.
```

- [ ] **Step 2: README, sezione "Pubblicità (AdMob)"**

Dopo il punto che descrive `scripts/ads.gd` aggiungere:

```
- L'SDK Next-Gen di AdMob si inizializza in modo **asincrono** e solleva un'eccezione se si carica un annuncio prima del callback: `ads.gd` aspetta `OnInitializationCompleteListener` prima di qualsiasi load, ritenta un banner fallito alla partita successiva e stampa ogni esito con prefisso `AdMob:`. Per verificare sul telefono: `tools/build.ps1 -Target Android`, `adb install -r artifacts/AncoraUno-debug.apk`, poi `tools/logcat.ps1 -Seconds 150` toccando ENTRA IN ASCENSORE entro venti secondi e lasciando scadere i tre piani. In `artifacts/logcat.txt` devono comparire, in ordine, `AdMob: inizializzato`, `AdMob: banner caricato`, `AdMob: interstitial caricato`, `AdMob: interstitial mostrato`; un `AdMob: banner fallito codice N` si legge con la tabella del plugin (0 interno, 1 richiesta non valida, 2 rete, 3 nessun annuncio). In editor il layer gira sul mock del plugin: un banner finto bianco e un interstitial finto nero, utili per vedere il layout.
```

- [ ] **Step 3: MIGLIORIE.md**

Prima della riga `---` che precede "Da valutare al prossimo playtest" aggiungere:

```
## 8. La pubblicità non compariva — fatto (14/09/2026)

L'APK del 13/09 conteneva l'SDK (cinque `classes.dex`, App ID di test nel manifest, tutti i
singleton `PoingGodotAdMob*` inizializzati nel log) ma né il banner né l'interstitial si vedevano
mai. Lo dice la guida di migrazione del plugin stesso: con l'SDK Next-Gen `MobileAds.initialize()`
è asincrono e caricare prima del callback **solleva un'eccezione**. `ads.gd` caricava appena si
toccava ENTRA IN ASCENSORE: l'`AdView` restava creato ma vuoto, e non veniva più ricreato;
l'interstitial restava "in caricamento" per sempre. Nessun errore GDScript nel log, coerente con
un'eccezione nativa.

Correzione: ogni load aspetta `OnInitializationCompleteListener`; un banner fallito viene distrutto
e ritentato alla partita dopo; ogni esito è stampato con prefisso `AdMob:` così `tools/logcat.ps1`
lo cattura. In editor il layer gira sul mock del plugin e la sequenza è coperta dai test headless.

## 9. Piani diversi — fatto (14/09/2026)

Giocando qualche minuto il gioco annoiava: le forme erano da 1-2 caselle fino al piano 3 (la T al
piano 12), ogni piano era una griglia vuota identica alla precedente, gli sblocchi di Elmo e Tea
passavano in silenzio e dopo il minimo non c'era un obiettivo che un bambino di cinque anni
potesse leggere. Quattro cose, tutte visive:

- **Bagagli**: valigie, piante e scatole già sul pavimento dal piano 2 (1, 2, 2, 3, 3, 4, 4, 5…).
  Il minimo tiene sempre almeno tre caselle libere oltre l'obiettivo.
- **Forme grandi prima**: L dal piano 1, quadrato dal 3, barra dal 5, T dal 7.
- **Stelle**: una per il minimo, due a metà strada, tre a ascensore pieno; si accendono una alla
  volta sulle porte chiuse con un tono in salita, e il totale è sulla schermata finale.
- **Festa per l'amico nuovo**: alla partenza dal piano 2 e dal 4 il transito dura 3,4 s e presenta
  l'animale nuovo sotto un riflettore, con rimbalzo e fanfara.

Più un rimbalzo di un terzo di secondo per l'animale appena salito. Vite, timer e punteggio sono
rimasti quelli di prima. Spec completa in `docs/superpowers/specs/2026-09-14-piani-diversi-design.md`.
```

Aggiungere in coda alla lista "Da valutare al prossimo playtest":

```
- Quantità di bagagli per piano e soglia delle due stelle: numeri a tavolino, da guardare in mano a
  un bambino. Se il riflettore che copre le stelle al piano 3 confonde, spostare le stelle in alto.
```

- [ ] **Step 4: Rileggere**

Run: `git diff README.md MIGLIORIE.md`
Expected: solo le aggiunte sopra; nessun'altra riga toccata.

- [ ] **Step 5: Commit**

```
Documenta bagagli, stelle, festa e la correzione della pubblicità

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

---

### Task 8: Build Android e verifica sul telefono

**Files:**
- Nessuna modifica al codice. Produce `artifacts/AncoraUno-debug.apk` e `artifacts/logcat.txt` (entrambi fuori da Git).

**Interfaces:**
- Consumes: `tools/build.ps1`, `tools/logcat.ps1 -Seconds N`, `adb` in `%LOCALAPPDATA%\AncoraUnoTools\Android\platform-tools\adb.exe`, le stampe `AdMob:` del Task 6.

- [ ] **Step 1: Test completi un'ultima volta**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `ALL N CHECKS PASSED`.

- [ ] **Step 2: Costruire l'APK**

Run: `powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target Android`
Expected: le ultime righe del log contengono `Exporting Poing AdMob '.cfg' file` e `[ DONE ] export`; `artifacts/AncoraUno-debug.apk` ha data odierna. Controllo che l'SDK sia dentro (Bash): `unzip -p artifacts/AncoraUno-debug.apk 'classes*.dex' | grep -a -c "com/google/android/gms/ads"` → un numero > 0.

- [ ] **Step 3: Installare**

Collegare il telefono con debug USB attivo. Run (PowerShell):
`& "$env:LOCALAPPDATA\AncoraUnoTools\Android\platform-tools\adb.exe" install -r artifacts/AncoraUno-debug.apk`
Expected: `Success`.

- [ ] **Step 4: Registrare il log giocando**

Run: `powershell -ExecutionPolicy Bypass -File tools/logcat.ps1 -Seconds 150`
Il gioco si avvia da solo sul telefono. Entro venti secondi toccare ENTRA IN ASCENSORE; giocare il piano 1 fino alla partenza (per vedere le stelle), poi lasciar scadere i piani fino al game over.
Expected sullo schermo: dal piano 2 i bagagli; alla partenza riuscita le stelle che si accendono con i toni; il banner *Test Ad* in basso durante la partita; l'annuncio a tutto schermo al game over prima di "Bella squadra!".
Expected in `artifacts/logcat.txt` (Bash: `grep -a "AdMob:" artifacts/logcat.txt`), in ordine: `AdMob: inizializzato`, `AdMob: banner caricato`, `AdMob: interstitial caricato`, `AdMob: interstitial mostrato`.

- [ ] **Step 5: Se qualcosa manca**

- `AdMob: banner fallito codice N`: 0 interno, 1 richiesta non valida (controllare gli unit ID in `ads.cfg`), 2 rete (il telefono è online?), 3 nessun annuncio.
- Nessuna riga `AdMob:` affatto: l'inizializzazione non arriva. Attivare **Disable Initialization Optimization** (Impostazioni progetto → Admob → General → Android, cioè `admob/general/android/disable_initialization_optimization=true` in `project.godot`), ricostruire, ripetere lo Step 4.
- Riportare l'esito nell'ultimo paragrafo di `MIGLIORIE.md` §8 ("Verificato sul telefono il …" oppure cosa è emerso) e committare.

---

## Self-review

**Copertura della spec.** §1 bagagli → Task 1 (conteggio, posizionamento, `capacity`, `blocked`, `can_place`, minimo, partenza automatica, disegno, `demo_board`). §2 forme → Task 2. §3 stelle → Task 3 (soglie, `round_stars`/`run_stars`, transito con tempi e toni, coriandoli 15×, schermata finale, `hud_goal_done`). §4 festa → Task 4 (`newcomer`, 3,4 s, riflettore, rimbalzo, fanfara, `toast_newcomer`). §5 rimbalzo → Task 5. §6 pubblicità → Task 6 (correzione, mock, test headless, contingenza) e Task 8 (telefono). §7 test → distribuiti nei Task 1-6. §8 documentazione → Task 7. §10 accettazione → Task 1 Step 8 (anteprima), Task 8.

**Scostamento dalla spec.** La stella sulla schermata finale è a `(300, 658)` con raggio 14 e testo a 22 px, non `(300, 662)` raggio 16 a 24 px: con 16 di raggio sfiorava la riga del record a y 692. La spec è stata aggiornata nello stesso commit di questo piano.

**Coerenza dei nomi.** `luggage_count`, `place_luggage`, `capacity`, `blocked`, `draw_luggage`, `stars_for`, `round_stars`, `run_stars`, `cues_played`, `transit_cues`, `transit_length`, `star_points`, `draw_transit`, `newcomer`, `born`, `initialized`, `banner_wanted`, `banner_loaded`, `has_plugin` sono usati con lo stesso nome in test e implementazione. `STAR_TIMES`/`STAR_TONES`/`FANFARE_TIMES`/`FANFARE_TONES` sono array paralleli di tre elementi.

---

### Task 9: `ads.cfg` non veniva esportato

Aggiunto il 14/09/2026 durante il Task 8. Sull'emulatore il plugin nativo si registra (`GodotPluginRegistry: Completed initialization for Godot plugin PoingGodotAdMob`) ma nessuna riga `AdMob:` compare, nemmeno `inizializzato`, e la fascia del banner non è riservata (`lift()` = 0): `enabled` è falso sul dispositivo. Verifica con `unzip -l`: `assets/ads.cfg` manca in tutti gli APK mai costruiti (v2, telefono, odierno) e nell'`.exe`; `addons/admob/plugin.cfg` c'è solo perché l'exporter del plugin lo aggiunge con `add_file`. Causa: `export_filter="all_resources"` esporta solo le risorse riconosciute da Godot, e un `.cfg` non lo è finché non compare in `include_filter`. Con `ads.cfg` assente `cfg.load` fallisce, gli unit ID restano vuoti e `unit("banner") != ""` è falso. È la causa primaria dell'assenza di pubblicità; l'inizializzazione asincrona (Task 6) è un secondo difetto reale, latente dietro il primo.

**Files:**
- Modify: `export_presets.cfg` (`include_filter` di `preset.0` e `preset.1`)
- Modify: `scripts/ads.gd` (`_ready`: stampa se il file manca)
- Modify: `tests/game_test.gd` (test di guardia sui preset, a un tab, subito prima del blocco asincrono della pubblicità)
- Modify: `README.md`, `MIGLIORIE.md`, `docs/superpowers/specs/2026-09-14-piani-diversi-design.md` (diagnosi corretta)
- Produce: `artifacts/AncoraUno-debug.apk` con `assets/ads.cfg` dentro; `artifacts/logcat.txt` con le quattro righe `AdMob:`

**Interfaces:**
- Consumes: `ads.enabled`, `unit("banner")`, le stampe `AdMob:` del Task 6; `tools/build.ps1`, `tools/logcat.ps1`; emulatore `emulator-5554` con override `wm size 720x1280` (coordinate schermo = coordinate canvas: START (360,1070), carta 0 (142,941), casella (0,0) (188,368)).

- [ ] **Step 1: Test di guardia (fallirà)**

In `tests/game_test.gd`, a UN tab (livello di `run()`), subito prima del commento `# The ads layer loads nothing until the SDK says it is ready`:

```gdscript
	# ads.cfg is not a Godot resource: with export_filter "all_resources" it ships only if the
	# presets name it. Left out, unit ids are empty and the layer stays silently off on devices.
	var presets = ConfigFile.new()
	check(presets.load("res://export_presets.cfg")==OK,"the export presets are readable")
	for section in ["preset.0","preset.1"]:
		check("ads.cfg" in str(presets.get_value(section,"include_filter","")),"%s exports ads.cfg" % section)
```

- [ ] **Step 2: Eseguire i test e vedere il fallimento**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `FAIL: preset.0 exports ads.cfg` e `FAIL: preset.1 exports ads.cfg`; `2 CHECKS FAILED, 221 passed`.

- [ ] **Step 3: Includere il file nell'export**

In `export_presets.cfg` sostituire entrambe le righe `include_filter=""` con `include_filter="ads.cfg"`.

- [ ] **Step 4: Fallimento rumoroso**

In `scripts/ads.gd`, `_ready()`, aggiungere il ramo `else` al `if cfg.load("res://ads.cfg") == OK:`, subito dopo la chiusura del dizionario `_ids`:

```gdscript
	else:
		# Loud, not silent: a config left out of the export is exactly what switched the ads off once.
		print("AdMob: ads.cfg non trovato, pubblicità spenta")
```

- [ ] **Step 5: Eseguire i test e vederli passare**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `ALL 223 CHECKS PASSED` (poi le due righe di leak note).

- [ ] **Step 6: Documentazione corretta**

`README.md`, sezione "Pubblicità (AdMob)": nel punto che inizia con "L'SDK Next-Gen di AdMob si inizializza in modo **asincrono**" anteporre la frase:

```
`ads.cfg` non è una risorsa Godot: con `export_filter="all_resources"` finisce nell'APK solo perché `include_filter` lo nomina — senza, gli unit ID restano vuoti e il gioco spegne la pubblicità in silenzio (è successo: nessun APK fino al 14/09 lo conteneva; ora un test lo pretende e `ads.gd` lo dice nel log).
```

`MIGLIORIE.md`, §8: sostituire il paragrafo che inizia con "L'APK del 13/09 conteneva l'SDK" con:

```
L'APK del 13/09 conteneva l'SDK (cinque `classes.dex`, App ID di test nel manifest, tutti i
singleton `PoingGodotAdMob*` inizializzati nel log) ma né il banner né l'interstitial si vedevano
mai. Due cause, una dietro l'altra. La prima, trovata solo il 14/09 sull'emulatore: **`ads.cfg` non
veniva esportato**. Con `export_filter="all_resources"` Godot mette nell'APK solo le risorse che
riconosce, e un `.cfg` non lo è finché `include_filter` non lo nomina (il plugin aggiunge il proprio
`plugin.cfg` a mano per lo stesso motivo). Senza il file gli unit ID restano vuoti e `ads.gd` spegne
tutto in silenzio: nessun APK costruito fino ad allora lo conteneva. La seconda, latente dietro la
prima, la dice la guida di migrazione del plugin: con l'SDK Next-Gen `MobileAds.initialize()` è
asincrono e caricare prima del callback **solleva un'eccezione**; `ads.gd` caricava appena si toccava
ENTRA IN ASCENSORE.
```

e sostituire il paragrafo che inizia con "Correzione: ogni load aspetta" con:

```
Correzione: `include_filter="ads.cfg"` nei due preset, un test che lo pretende e una riga
`AdMob: ads.cfg non trovato` nel log se dovesse mancare di nuovo; ogni load aspetta
`OnInitializationCompleteListener`; un banner fallito viene distrutto e ritentato alla partita dopo;
ogni esito è stampato con prefisso `AdMob:` così `tools/logcat.ps1` lo cattura. In editor il layer
gira sul mock del plugin e la sequenza è coperta dai test headless.
```

`docs/superpowers/specs/2026-09-14-piani-diversi-design.md`, §6, subito dopo la riga `### Diagnosi`, inserire:

```
**Aggiornamento 14/09, dopo la verifica sull'emulatore.** La causa primaria è un'altra: `ads.cfg`
non veniva esportato (`export_filter="all_resources"` esclude i file che non sono risorse Godot;
`include_filter` era vuoto), quindi sul dispositivo `unit("banner")` era vuoto ed `enabled` falso.
L'inizializzazione asincrona descritta sotto è reale e resta corretta, ma sarebbe emersa solo dopo.
Correzione e test nel Task 9 del piano.
```

- [ ] **Step 7: Commit**

Stage `export_presets.cfg scripts/ads.gd tests/game_test.gd README.md MIGLIORIE.md docs/superpowers/specs/2026-09-14-piani-diversi-design.md` (non `project.godot`). Messaggio:

```
Esporta ads.cfg: era la vera causa della pubblicità assente

Con export_filter "all_resources" un .cfg finisce nell'APK solo se include_filter
lo nomina: nessuna build lo conteneva, gli unit ID restavano vuoti e ads.gd
spegneva tutto in silenzio. Test di guardia sui preset, riga di log se il file
manca, diagnosi corretta in README, MIGLIORIE e spec.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

- [ ] **Step 8: Rebuild e controllo del pacchetto**

Run: `powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target Android` (timeout 600 s).
Expected: `[ DONE ] export`; poi `unzip -l artifacts/AncoraUno-debug.apk | grep ads.cfg` → `assets/ads.cfg`.

- [ ] **Step 9: Installare e registrare**

`adb -s emulator-5554 install -r artifacts/AncoraUno-debug.apk` → `Success`. Poi `tools/logcat.ps1 -Seconds 150` in background; dopo 12 s `adb -s emulator-5554 shell input tap 360 1070`; dopo 3 s screenshot `artifacts/emulatore-partita.png`; `input swipe 142 941 188 368 500`; screenshot `artifacts/emulatore-piazzato.png`; una sola attesa di ~125 s.
Expected in `artifacts/logcat.txt`: `AdMob: inizializzato`, `AdMob: banner caricato`, `AdMob: interstitial caricato`, `AdMob: interstitial mostrato`. Nello screenshot le carte in coda alte 150 unità (866-1016) e in basso il banner *Test Ad* o la fascia libera.

- [ ] **Step 10: Annotare l'esito**

Se le quattro righe ci sono: in coda a `MIGLIORIE.md` §8, dopo il paragrafo "Resta un avviso innocuo", la riga
`Verificato sull'emulatore x86_64 (Android 15) il 14/09/2026: le quattro righe `AdMob:` compaiono nel logcat e il banner di test è visibile in partita; la prova sul telefono ARM resta da fare.`
(adattare "il banner di test è visibile" a ciò che mostra lo screenshot). Commit solo di `MIGLIORIE.md`: `Annota la verifica della pubblicità sull'emulatore` + riga Co-Authored-By.

---

### Task 10: il wrapper del plugin passa `Array[String]` dove il nativo vuole `String[]`

Aggiunto il 14/09/2026 dopo il Task 9. Con `ads.cfg` esportato compare `AdMob: inizializzato`, ma banner e interstitial non partono: il logcat mostra tre `SCRIPT ERROR: Invalid type in function '…' in base 'JNISingleton'. The array of argument N (Array[String]) does not have the same element type as the expected typed array argument` in `MobileAds.gd:48` (`set_request_configuration`), `InterstitialAdLoader.gd:54` (`load`) e `AdView.gd:62` (`load_ad`). `javap` sull'AAR conferma le firme Java: `set_request_configuration(Dictionary, String[])`, `load_ad(int, Dictionary, String[])`, `load(String, Dictionary, String[], int)`. Il wrapper GDScript del plugin v5.0.0 passa `AdRequest.keywords` e `RequestConfiguration.test_device_ids`, dichiarati `Array[String]`; Godot 4.6 li rifiuta. Il changelog upstream ammette lo stesso difetto ("Fixed `Array[String]` JNI signature mismatch in `RewardedAdLoader.load()`") e la v5.1.0 è uscita il 13/09/2026: l'aggiornamento dell'addon è rinviato (binari nativi da riscaricare, protezione anti-mismatch dell'exporter); qui si corregge il wrapper in locale passando `PackedStringArray(...)`, il tipo Variant naturale di `String[]`, con un test che pretende la patch così che un reinstall dell'addon fallisca rumorosamente.

**Files:**
- Modify: `addons/admob/gdscript/src/api/AdView.gd:62`, `addons/admob/gdscript/src/api/InterstitialAdLoader.gd:54`, `addons/admob/gdscript/src/api/MobileAds.gd:48-49`
- Modify: `tests/game_test.gd` (test di guardia, a un tab, subito dopo il blocco `for section in ["preset.0","preset.1"]` del Task 9)
- Modify: `README.md`, `MIGLIORIE.md`, `docs/superpowers/specs/2026-09-14-piani-diversi-design.md`
- Produce: APK ricostruito; `artifacts/logcat.txt` con le quattro righe `AdMob:`; screenshot con banner

**Interfaces:**
- Consumes: come Task 9 (emulatore `emulator-5554`, coordinate 720×1280, `tools/build.ps1`, `tools/logcat.ps1`).

- [ ] **Step 1: Test di guardia (fallirà)**

In `tests/game_test.gd`, a UN tab, subito dopo il ciclo `for section in ["preset.0","preset.1"]:` del Task 9 (e prima del commento `# The ads layer loads nothing until the SDK says it is ready`):

```gdscript
	# Godot 4.6 rejects a typed Array[String] where the native plugin declares String[]: the three
	# wrapper calls this game uses must hand over a PackedStringArray, or no ad ever loads on Android.
	for pair in [
			["res://addons/admob/gdscript/src/api/AdView.gd", "PackedStringArray(ad_request.keywords))"],
			["res://addons/admob/gdscript/src/api/InterstitialAdLoader.gd", "PackedStringArray(ad_request.keywords), _uid)"],
			["res://addons/admob/gdscript/src/api/MobileAds.gd", "PackedStringArray(request_configuration.test_device_ids)"]]:
		check(FileAccess.get_file_as_string(pair[0]).contains(pair[1]),"%s hands the native plugin a PackedStringArray" % pair[0].get_file())
```

- [ ] **Step 2: Eseguire i test e vedere il fallimento**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: tre FAIL (`AdView.gd hands the native plugin a PackedStringArray`, `InterstitialAdLoader.gd …`, `MobileAds.gd …`); `3 CHECKS FAILED, 223 passed`.

- [ ] **Step 3: Patch del wrapper**

`addons/admob/gdscript/src/api/AdView.gd`, riga 62: sostituire
`_plugin.load_ad(_uid, ad_request.convert_to_dictionary(), ad_request.keywords)`
con
`_plugin.load_ad(_uid, ad_request.convert_to_dictionary(), PackedStringArray(ad_request.keywords))`

`addons/admob/gdscript/src/api/InterstitialAdLoader.gd`, riga 54: sostituire
`_plugin.load(ad_unit_id, ad_request.convert_to_dictionary(), ad_request.keywords, _uid)`
con
`_plugin.load(ad_unit_id, ad_request.convert_to_dictionary(), PackedStringArray(ad_request.keywords), _uid)`

`addons/admob/gdscript/src/api/MobileAds.gd`, righe 47-49: sostituire
```gdscript
		_plugin.set_request_configuration(
			request_configuration.convert_to_dictionary(), request_configuration.test_device_ids
		)
```
con
```gdscript
		# Godot 4.6 rejects Array[String] for a Java String[]: hand over a PackedStringArray.
		_plugin.set_request_configuration(
			request_configuration.convert_to_dictionary(), PackedStringArray(request_configuration.test_device_ids)
		)
```

- [ ] **Step 4: Eseguire i test e vederli passare**

Run: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
Expected: `ALL 226 CHECKS PASSED` (poi le due righe di leak note). Il mock accetta qualsiasi tipo, quindi il resto della sequenza resta verde.

- [ ] **Step 5: Documentazione**

`README.md`, sezione "Pubblicità (AdMob)", dopo il punto che inizia con "`ads.cfg` non è una risorsa Godot" aggiungere il punto:

```
- Il wrapper GDScript del plugin v5.0.0 passa `Array[String]` a tre metodi nativi che dichiarano `String[]` (`set_request_configuration`, `AdView.load_ad`, `InterstitialAdLoader.load`) e Godot 4.6 li rifiuta con `Invalid type … JNISingleton`: nessun annuncio si caricava. Le tre chiamate in `addons/admob/gdscript/src/api/` sono **patchate in locale** con `PackedStringArray(...)` e un test lo pretende — reinstallando l'addon la patch va riapplicata o va verificato che la v5.1.0 (13/09/2026) l'abbia risolto.
```

`MIGLIORIE.md`, §8: nel paragrafo che inizia con "L'APK del 13/09 conteneva l'SDK", sostituire "Due cause, una dietro l'altra." con "Tre cause, una dietro l'altra." e aggiungere in coda al paragrafo:

```
 La terza, dietro le prime due: il wrapper GDScript del plugin passa `Array[String]` a metodi nativi che
vogliono `String[]` (`set_request_configuration`, `load_ad`, `load`) e Godot 4.6 li rifiuta con
`Invalid type … JNISingleton` — lo stesso difetto che upstream dichiara di aver corretto solo per il
`RewardedAdLoader`.
```

e nel paragrafo "Correzione:" aggiungere prima di "ogni load aspetta": "le tre chiamate del wrapper patchate in locale con `PackedStringArray(...)` (test di guardia, da riverificare aggiornando l'addon alla 5.1.0);".

`docs/superpowers/specs/2026-09-14-piani-diversi-design.md`, §6, in coda al paragrafo "**Aggiornamento 14/09**" aggiungere:

```
Terza causa, emersa dopo la seconda: il wrapper GDScript del plugin passa `Array[String]` dove il nativo
dichiara `String[]` e Godot 4.6 rifiuta la chiamata; patch locale con `PackedStringArray` nel Task 10.
```

- [ ] **Step 6: Commit**

Stage `addons/admob/gdscript/src/api/AdView.gd addons/admob/gdscript/src/api/InterstitialAdLoader.gd addons/admob/gdscript/src/api/MobileAds.gd tests/game_test.gd README.md MIGLIORIE.md docs/superpowers/specs/2026-09-14-piani-diversi-design.md` (non `project.godot`). Messaggio:

```
Plugin AdMob: PackedStringArray dove il nativo vuole String[]

Godot 4.6 rifiuta gli Array[String] che il wrapper v5.0.0 passa a
set_request_configuration, load_ad e load: nessun annuncio si caricava anche
con ads.cfg a bordo. Patch locale alle tre chiamate, test che la pretende,
diagnosi aggiornata in README, MIGLIORIE e spec.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
```

- [ ] **Step 7: Rebuild, installazione, registrazione**

Come Task 9, Step 8-9: `tools/build.ps1 -Target Android` (600 s) → `[ DONE ] export`; `adb -s emulator-5554 install -r artifacts/AncoraUno-debug.apk` → `Success`; `tools/logcat.ps1 -Seconds 150` in background; dopo 12 s tap (360,1070); dopo 3 s screenshot `artifacts/emulatore-partita.png`; swipe `142 941 188 368 500`; screenshot `artifacts/emulatore-piazzato.png`; attesa fino alla riscrittura di `artifacts/logcat.txt`; poi un ulteriore screenshot `artifacts/emulatore-banner.png` a circa 20 s dal tocco (il banner di test arriva dalla rete).
Expected: `grep -a "AdMob:" artifacts/logcat.txt` → `inizializzato`, `banner caricato`, `interstitial caricato`, `interstitial mostrato`; `grep -a "SCRIPT ERROR" artifacts/logcat.txt` vuoto; negli screenshot carte alte 150 e, in `emulatore-banner.png`, il banner *Test Ad* in basso.

- [ ] **Step 8: Annotare l'esito**

Se le quattro righe ci sono e nessun `SCRIPT ERROR`: in coda a `MIGLIORIE.md` §8, dopo il paragrafo "Resta un avviso innocuo", la riga
`Verificato sull'emulatore x86_64 (Android 15) il 14/09/2026: le quattro righe `AdMob:` compaiono nel logcat e il banner di test è visibile in partita; la prova sul telefono ARM resta da fare.`
(adattare la parte sul banner a ciò che mostra `emulatore-banner.png`). Commit solo di `MIGLIORIE.md`: `Annota la verifica della pubblicità sull'emulatore` + riga Co-Authored-By. Se invece compare un errore nuovo, riportarlo testualmente e non toccare MIGLIORIE.
