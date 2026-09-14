extends RefCounted

# Every line the player can read, in both languages, keyed by a stable identifier.
# The game picks the column once at start-up from the device locale.
const TABLE = {
	"title_top": {"it":"ANCORA", "en":"ONE"},
	"title_main": {"it":"UNO!", "en":"MORE!"},
	"tagline": {"it":"UN ASCENSORE. UNA BANDA BESTIALE.", "en":"ONE LIFT. ONE WILD BUNCH."},
	"menu_motto": {"it":"Piccoli spazi. Grandi persone.", "en":"Small spaces. Big friends."},
	"menu_step1": {"it":"1. Tocca un animale per girarlo.", "en":"1. Tap an animal to turn it."},
	"menu_step2": {"it":"2. Trascinalo dentro l'ascensore.", "en":"2. Drag it into the lift."},
	"menu_step3": {"it":"3. Riempi il minimo prima che le porte si chiudano.", "en":"3. Fill the minimum before the doors close."},
	"menu_lives": {"it":"Tre vite. Le porte iniziano a chiudersi appena si apre il piano.", "en":"Three lives. The doors start closing the moment a floor opens."},
	"menu_start": {"it":"ENTRA IN ASCENSORE", "en":"STEP INTO THE LIFT"},
	"menu_best": {"it":"RECORD  %d", "en":"BEST  %d"},
	"menu_footer": {"it":"Tutti diversi. Stesso obiettivo.", "en":"All different. Same goal."},
	"hud_score": {"it":"PUNTI", "en":"SCORE"},
	"hud_floor": {"it":"PIANO %02d", "en":"FLOOR %02d"},
	"hud_best": {"it":"RECORD %d", "en":"BEST %d"},
	"hud_doors": {"it":"PORTE: %02d s", "en":"DOORS: %02d s"},
	"hud_cells": {"it":"CELLE %d / MIN %d", "en":"CELLS %d / MIN %d"},
	"hud_ok": {"it":"OK!", "en":"OK!"},
	"hud_hint": {"it":"TOCCA per girarlo · TRASCINA per farlo salire", "en":"TAP to turn · DRAG to board"},
	"hud_goal_done": {"it":"MINIMO RAGGIUNTO! Riempi tutto per tre stelle.", "en":"MINIMUM REACHED! Fill it all for three stars."},
	"hud_goal_todo": {"it":"Servono almeno %d caselle prima che le porte si chiudano", "en":"Fill at least %d cells before the doors close"},
	"toast_closing": {"it":"Le porte si chiudono!", "en":"The doors are closing!"},
	"toast_goal": {"it":"Obiettivo raggiunto! Ancora uno?", "en":"Goal reached! One more?"},
	"toast_nofit": {"it":"Qui non ci sta. Toccalo per girarlo!", "en":"It won't fit here. Tap it to turn it!"},
	"toast_aboard": {"it":"+%d · Tutti a bordo!", "en":"+%d · All aboard!"},
	"toast_fail": {"it":"Pochi a bordo! Una vita in meno.", "en":"Too few aboard! One life lost."},
	"pause_title": {"it":"UN RESPIRO.", "en":"TAKE A BREATH."},
	"pause_line1": {"it":"L'ascensore ti aspetta.", "en":"The lift is waiting for you."},
	"pause_line2": {"it":"Il tempo è in pausa.", "en":"Time is paused."},
	"pause_resume": {"it":"RIPRENDI", "en":"RESUME"},
	"over_title": {"it":"BELLA SQUADRA!", "en":"GREAT CREW!"},
	"over_floor": {"it":"PUNTI  ·  PIANO %d", "en":"POINTS  ·  FLOOR %d"},
	"over_best": {"it":"Il tuo record: %d", "en":"Your best: %d"},
	"over_again_q": {"it":"Ci sta un'altra partita?", "en":"Room for one more game?"},
	"over_again": {"it":"ANCORA UNO!", "en":"ONE MORE!"},
	"animal_dino": {"it":"DINO BRONTO", "en":"BRONTO DINO"},
	"animal_panda": {"it":"PANDA PIP", "en":"PIP PANDA"},
	"animal_croc": {"it":"COCCO CRUNCH", "en":"CRUNCH CROC"},
	"animal_giraffe": {"it":"GIRAFFA GIGI", "en":"GIGI GIRAFFE"},
	"animal_trice": {"it":"TRICERATÒ", "en":"TRICERA-TOPS"},
	"animal_elephant": {"it":"ELEFANTE ELMO", "en":"ELMO ELEPHANT"},
	"animal_turtle": {"it":"TARTARUGA TEA", "en":"TEA TORTOISE"},
}

# Italian devices read Italian; everyone else reads English.
static func language_for(locale: String) -> String:
	return "it" if locale.to_lower().begins_with("it") else "en"

static func text(key: String, lang: String) -> String:
	return TABLE[key][lang]
