# Piani diversi — design

14/09/2026. Approvato in chat come "approccio A", fascia d'età 4-6 anni.

## Perché

Dopo il playtest del 13/09 la build regge sul telefono ma, giocando qualche minuto, annoia. Cause
lette in `scripts/game.gd`:

- **Non è un puzzle.** Ai piani 1-2 le forme hanno 1 o 2 caselle e la terza carta è sempre una casella
  singola: tutto entra sempre, ovunque. L'unica pressione è il timer. Il tetramino a T arriva al piano
  12, che nessun bambino raggiunge.
- **Ogni piano è identico.** Stessa griglia vuota, minimo +1, timer −3 s. Niente che cambi a vista.
- **Gli sblocchi sono muti.** Elefante Elmo (piano 3) e Tartaruga Tea (piano 5) entrano in coda senza
  che nessuno lo annunci.
- **Dopo il minimo non c'è un obiettivo.** "Ogni animale in più vale punti" è astratto a cinque anni.

Vincolo che governa tutto: il pubblico **non legge**. Ogni novità deve capirsi guardando, e un bambino
di quattro anni non deve mai restare bloccato — la casella singola sempre in coda resta.

Nello stesso giro si corregge la **pubblicità**, che nell'APK v2 non compariva mai (vedi §6).

## 1. Bagagli

Caselle già occupate quando si apre il piano, disegnate come oggetti lasciati in ascensore.

- Stato: `luggage: Array` di `{"cell": Vector2i, "kind": int}`, rigenerato in `new_round()`.
- Quanti: piano 1 → 0; dal piano 2 → `mini(5, 1 + (floor_number - 1) / 2)` (divisione intera), cioè
  1, 2, 2, 3, 3, 4, 4, 5, 5, … Caselle casuali distinte; nessun altro vincolo, la casella singola in
  coda riempie qualsiasi buco.
- Tre oggetti (`kind` 0-2), disegnati a codice come gli animali, ~10 righe ciascuno, inset del 10%
  nella casella: **valigia** (rettangolo marrone `8d5a34`, maniglia, due fermagli `efc66e`), **pianta**
  (vaso corallo trapezoidale, tre foglie menta), **scatola** (cartone `d9b67a` con nastro a croce
  `c58a55`). Palette esistente, contorno `INK`.
- `capacity() -> int` = `SIDE*SIDE - luggage.size()`. `blocked(cell) -> bool`.
- `can_place` rifiuta le caselle bloccate. `occupied()` non conta i bagagli.
- Partenza automatica a `occupied() >= capacity()` (oggi `SIDE*SIDE`).
- Minimo: `target = mini(mini(20, 10 + floor_number - 1), capacity() - 3)`. Restano sempre almeno tre
  caselle libere oltre il minimo. Fino al piano 8 il valore è identico a oggi; dal piano 9 il minimo
  si ferma a 17 (su 20 libere) invece di salire a 18-20.
- `demo_board()` aggiunge una valigia in (4,3) e una pianta in (0,4), così l'anteprima `--screenshot`
  mostra la novità senza sovrapporsi ai tre animali dimostrativi.

## 2. Forme

- `make_piece`: tetto delle forme da `mini(6, 2 + floor_number / 3)` a
  `mini(6, 3 + (floor_number - 1) / 2)` ⇒ L dal piano 1, quadrato dal 3, barra da tre dal 5, T dal 7.
- Coda iniziale (L, domino verticale, singola) e regola "la terza carta è sempre singola" invariate.

## 3. Stelle

Voto del piano, senza parole.

- Alla partenza riuscita: `stars_for(occupied())`: **3** se `>= capacity()`, altrimenti **2** se
  `>= target + (capacity() - target) / 2`, altrimenti **1** (il minimo è raggiunto per definizione).
  Fallimento: 0. Esempi: piano 1 → 1★ a 10, 2★ a 17, 3★ a 25; piano 9 (5 bagagli) → 17, 18, 20.
- `round_stars` (piano corrente) e `run_stars` (somma della partita, azzerata in `start_game()`).
- Transito: tre stelle a dieci punte (raggio esterno 55, interno 25) centrate in
  `(360 + (k-2)*130, 540)` per k = 1..3, grigie `d7cec1` con contorno `INK` 3 px; le guadagnate si
  accendono d'oro `efc66e` una alla volta quando `transit_time >= 0.1 + 0.3*k` (0,4 / 0,7 / 1,0 s),
  ciascuna con un tono di 0,1 s: 700, 900, 1100 Hz. In caso di fallimento le tre sagome grigie
  restano spente.
- Coriandoli: `15 * round_stars` invece di 36 fissi.
- Schermata finale: una stella d'oro (raggio 14) a `(300, 658)` seguita da `× N` (22 px), tra la riga
  del piano (631) e quella del record (692) senza sfiorare nessuna delle due.
- Il punteggio non cambia formula: le stelle sono lo strato leggibile, i punti restano per il record.
- Stringa `hud_goal_done` → "MINIMO RAGGIUNTO! Riempi tutto per tre stelle." /
  "MINIMUM REACHED! Fill it all for three stars." (è la frase che il genitore legge ad alta voce).

## 4. Festa per l'amico nuovo

- `newcomer: int = -1`. In `depart()` riuscito: l'indice dell'animale con `floor == floor_number + 1`,
  se esiste. `new_round()` lo riporta a −1. Oggi scatta al 3 (Elmo) e al 5 (Tea); un animale futuro
  basta che dichiari il suo `floor`.
- `transit_length() -> float`: 3,4 s se `newcomer >= 0`, altrimenti 1,6 s (il valore di oggi).
  `_process` chiude il transito a `transit_time > transit_length()`.
- Da `transit_time >= 1.3`, sopra le porte chiuse: riflettore `CREAM` di raggio 160 in `(360, 545)`
  con bordo `INK` (385-705 in verticale); l'animale con
  `draw_person({"cells": SHAPES[4], "person": newcomer}, origine, 110)` — un 2×2 da 220 px — con
  origine `(250, 445 - rimbalzo)` e `rimbalzo = abs(sin((transit_time - 1.3) * 6)) * 30`; sopra il
  cerchio, `toast_newcomer` a y 372 (26 px); sotto il cerchio, il nome dell'animale a y 745 (28 px),
  dentro il riquadro della griglia (317-767). Raggio 175 e testi a 400/705 si sovrapponevano al bordo:
  corretto il 14/09 guardando gli screenshot per lo store.
- Fanfara: tre toni di 0,12 s a 660 / 880 / 1320 Hz quando `transit_time` supera 1,3 / 1,5 / 1,7.
- Le stelle (§3) sono già tutte accese a 1,0 s: nessuna sovrapposizione.
- Stringa nuova `toast_newcomer`: "Nuovo amico!" / "New friend!".

## 5. Rimbalzo

- In `release_drag`, prima di aggiungere il pezzo a `pieces`: `drag.born = elapsed`.
- In `_draw`, per ogni pezzo: `age = elapsed - p.get("born", -10.0)`; se `age < 0.3` la scala è
  `1 + 0.12 * sin(PI * age / 0.3)`, applicata attorno al centro del rettangolo che contiene le celle
  del pezzo (origine e unità corrette di conseguenza). I pezzi dei test e di `demo_board` non hanno
  `born` e non rimbalzano.

## 6. Pubblicità

### Diagnosi

**Aggiornamento 14/09, dopo la verifica sull'emulatore.** La causa primaria è un'altra: `ads.cfg`
non veniva esportato (`export_filter="all_resources"` esclude i file che non sono risorse Godot;
`include_filter` era vuoto), quindi sul dispositivo `unit("banner")` era vuoto ed `enabled` falso.
L'inizializzazione asincrona descritta sotto è reale e resta corretta, ma sarebbe emersa solo dopo.
Correzione e test nel Task 9 del piano.

Terza causa, emersa dopo la seconda: il wrapper GDScript del plugin passa `Array[String]` dove il nativo
dichiara `String[]` e Godot 4.6 rifiuta la chiamata; patch locale con `PackedStringArray` nel Task 10.

L'APK v2 contiene l'SDK (cinque `classes*.dex`, dieci riferimenti a `com/google/android/gms/ads`,
`APPLICATION_ID` di test nel manifest, tutti i singleton `PoingGodotAdMob*` inizializzati nel log
dell'emulatore). Eppure banner e interstitial non compaiono mai. La causa è nella documentazione del
plugin stesso, `addons/admob/skills/godot-admob-migrate/SKILL.md`, punto 9:

> On Android (GMA Next-Gen SDK), initialization via `MobileAds.initialize()` is strictly asynchronous.
> You must wait for the callback (using `OnInitializationCompleteListener`) to fire before loading any
> ads. Attempting to load ads prior to initialization completion will throw an exception.

`scripts/ads.gd` chiama `MobileAds.initialize()` senza listener in `_ready()` e carica banner e
interstitial in `start_game()`, cioè appena il giocatore tocca ENTRA IN ASCENSORE. Se l'SDK non ha
finito, la load solleva un'eccezione nativa che il gioco non vede: l'`AdView` resta creato ma vuoto
(`_banner != null`, quindi `show_banner()` non lo ricrea più) e `_loading` dell'interstitial resta
`true` per sempre, così nemmeno il game over lo ritenta. Nessun errore GDScript nel log: coerente.

### Correzione (`scripts/ads.gd`)

- `initialized: bool`, `banner_wanted: bool`, `banner_loaded: bool`.
- `_ready()`: come oggi (configurazione child-directed, rating G), ma `MobileAds.initialize(listener)`
  con un `OnInitializationCompleteListener` il cui callback `_on_initialized` imposta
  `initialized = true`, stampa `AdMob: inizializzato`, chiama `preload_interstitial()` e, se
  `banner_wanted`, `show_banner()`.
- `show_banner()`: se non `enabled` esce; `banner_wanted = true`; se non `initialized` esce (verrà
  richiamata dal callback). Se `_banner == null` lo crea con un `AdListener`: `on_ad_loaded` →
  `banner_loaded = true`, stampa `AdMob: banner caricato`; `on_ad_failed_to_load(err)` → stampa
  `AdMob: banner fallito codice N: messaggio`, `_banner.destroy()`, `_banner = null`, così la partita
  successiva ritenta. Altrimenti `_banner.show()`.
- `preload_interstitial()`: esce anche se non `initialized`; stampa esito e codice in caso di errore.
- `show_interstitial()`: invariato nella logica, stampa `AdMob: interstitial mostrato`.
- Tutte le stampe iniziano con `AdMob:` perché `tools/logcat.ps1` già filtra su quella parola.
- `enabled` = unit ID presente **e** (`Engine.has_singleton("PoingGodotAdMob")` **oppure**
  `OS.has_feature("editor")`). Il secondo caso è il *mock* del plugin, che esiste solo nei binari
  editor: sul telefono senza plugin e nell'`AncoraUno.exe` esportato il layer resta spento come oggi.
  Conseguenza voluta: lanciando il gioco con `tools/run.ps1` compaiono il banner finto (rettangolo
  bianco in basso) e l'interstitial finto al game over, così il layout con la fascia da 90 unità si
  vede anche su PC.

### Verifica in headless (`tests/game_test.gd`)

Il mock risponde a `initialize()` dopo 0,5 s e alle load dopo 0,5 s, quindi `run()` diventa una
coroutine che aspetta con `await create_timer(...).timeout`:

- subito dopo `_ready()`: `enabled` vero (mock presente), `initialized` falso;
- `show_banner()` prima dell'inizializzazione: `_banner == null`, `banner_wanted` vero — nessuna load
  prematura;
- dopo 0,7 s: `initialized` vero, `_banner != null`; dopo altri 0,7 s `banner_loaded` vero e
  `_interstitial != null` (precaricato dal callback);
- `show_interstitial()` restituisce `true`, e subito dopo `_interstitial == null`;
- `banner_reserve()` vale 90 quando il layer è acceso.

Le due asserzioni odierne "ads stay disabled where the native plugin is absent" e "no space is
reserved" descrivevano il vecchio comportamento in headless e vengono sostituite da queste. Rischio:
il mock costruisce controlli UI; se in headless non reggesse, il layer si accende solo quando
`DisplayServer.get_name() != "headless"` e i test di sequenza si spostano su un doppio minimo.

### Verifica sul telefono

1. `tools/build.ps1 -Target Android`, poi `adb install -r artifacts/AncoraUno-debug.apk`.
2. `tools/logcat.ps1 -Seconds 150`; entro venti secondi toccare ENTRA IN ASCENSORE, poi lasciar
   scadere i tre piani fino al game over.
3. In `artifacts/logcat.txt` devono comparire, in ordine: `AdMob: inizializzato`,
   `AdMob: banner caricato`, `AdMob: interstitial caricato`, `AdMob: interstitial mostrato`.
4. Sullo schermo: banner con la scritta *Test Ad* in basso durante la partita, annuncio a tutto
   schermo al game over prima di "Bella squadra!".
5. Se compare `AdMob: banner fallito codice N`: 0 errore interno, 1 richiesta non valida (unit ID),
   2 rete, 3 nessun annuncio disponibile. Se dopo la correzione l'inizializzazione non arriva mai,
   provare **Disable Initialization Optimization** in Impostazioni progetto → Admob → General → Android,
   come suggerisce la guida di migrazione del plugin (punto 7).

## 7. Test del gioco

Da scrivere prima del codice, come il resto di `tests/game_test.gd`:

- bagagli per piano: 1→0, 2→1, 3→2, 5→3, 7→4, 9→5, 20→5; caselle distinte e dentro la griglia;
- `can_place` rifiuta una casella con bagaglio; `occupied()` li ignora; `capacity() == 25 - bagagli`;
- `target <= capacity() - 3` per i piani 1-39 (accanto al test "bounded difficulty" esistente);
- con bagagli presenti, la partenza automatica scatta a `occupied() == capacity()`;
- tetto forme: al piano 1 esce la forma 3 e mai la 4; al 3 esce la 4 e mai la 5; al 5 la 5; al 7 la 6;
- `stars_for`: minimo → 1, metà strada → 2, pieno → 3, sotto il minimo → 0; `run_stars` somma e si
  azzera in `start_game()`;
- partenza riuscita dal piano 2 → `newcomer == 5`, `transit_length() == 3.4`, dopo `_process(2)` si è
  ancora in transito, dopo altri 1,5 s si è al piano 3; dal piano 1 → `newcomer == -1`, 1,6 s;
- un pezzo piazzato con `release_drag` ha `born`;
- i 139 controlli esistenti restano verdi. Nessuno di loro attraversa il piano 3 o 5 in transito,
  quindi la durata variabile non li tocca; i due sulla pubblicità cambiano come detto in §6.

## 8. Documentazione

- `README.md`, sezione "Giocare": bagagli, stelle, festa dell'amico nuovo, forme; sezione
  "Pubblicità": inizializzazione asincrona e procedura di verifica con `logcat.ps1`.
- `MIGLIORIE.md`: §8 "La pubblicità non compariva" (diagnosi e correzione), §9 "Piani diversi"
  (questo design in breve, con i numeri).

## 9. Fuori perimetro

Vite, timer, formula del punteggio, musica (compreso lo spostamento di `build_music()` fuori dal
primo frame, che resta un lavoro separato), nuovi animali. Tutto il codice di gioco resta in
`scripts/game.gd`, come il resto del progetto: circa 150 righe in più.

## 10. Accettazione

- `tools/test.ps1`: tutti i controlli verdi, compresi i nuovi.
- Anteprima `--screenshot` con due bagagli visibili.
- Sul telefono: piani visibilmente diversi dal secondo in su, stelle e fanfara al piano 3, banner
  *Test Ad* in partita e interstitial al game over, con le quattro righe `AdMob:` nel logcat.
