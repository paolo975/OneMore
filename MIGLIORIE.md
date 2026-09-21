# Migliorie da playtest

Raccolte dopo la prima prova su telefono, 12/09/2026, build `AncoraUno-telefono.apk`.
Tutte e sei risolte nella build successiva della stessa sera.

## 1. I piani non cambiavano ritmo — fatto

`new_round()` toglieva 1,5 secondi per piano: 35 s al primo, 33,5 al secondo, 32 al terzo. Sotto il
10% di differenza nei piani che si raggiungono davvero, quindi salire non si *sentiva*.

Ora il tempo cala di **3 secondi a piano**: 34, 31, 28, fino al minimo di 16 raggiunto al settimo.

## 2. Non si vedeva quando le porte cominciavano a chiudersi — fatto

Le porte partivano da larghezza zero al 55% di opacità: l'inizio della chiusura passava inosservato.

Ora l'opacità è **82%** e i battenti sono **già socchiusi** quando il conto alla rovescia parte, così
il movimento si nota dal primo secondo. Il primo animale piazzato fa suonare una nota grave e
comparire la scritta "Le porte si chiudono!".

## 3. Il pulsante SI PARTE non aveva senso — fatto

Tolto, insieme alla scorciatoia con la barra spaziatrice. Con lui è sparito anche RUOTA: i quasi 200
pixel liberati sono andati alle carte in coda, che ora sono bersagli molto più generosi per un dito
piccolo.

## 4. La rotazione col pulsante RUOTA era scomoda — fatto

Ora **un tocco gira l'animale, un trascinamento lo porta dentro**. I due gesti si distinguono dalla
distanza percorsa dal dito: sotto i 14 pixel è un tocco.

## 5. Mancava la musica di sottofondo — fatto

Tema originale generato dal gioco all'avvio: melodia pentatonica e basso su un giro I-V-vi-IV, ciclo
di otto secondi, con dissolvenza sulla giuntura perché il loop non faccia clic. Nessun file audio,
nessuna licenza. Si spegne con la nota musicale e tace in pausa.

## 6. Spostare un animale già piazzato — fatto

Deciso di togliere la possibilità, come in Tetris: una volta in ascensore l'animale è sistemato.
Con quella regola è sparito anche `cancel_drag()`, che serviva solo a rimettere a posto un pezzo
ripescato dalla griglia.

## 7. Crash su Android dopo qualche secondo nel menu — fatto (13/09/2026)

Il gioco si chiudeva da solo pochi secondi dopo l'avvio, senza toccare nulla, su telefono ARM;
mai su Windows né sull'emulatore x86. Bisezione: la build senza AdMob crashava uguale; col suono
silenziato dal pulsante ♪ non crashava. Colpevole: **il tema musicale in loop**. Il mixer WAV di
Godot 4.6 non limita `loop_end` alla lunghezza dei dati e, in loop, legge fino a `loop_end`
compreso — un campione oltre la fine del buffer, che avevo dimensionato esatto. Su x86 la lettura
fuori buffer è innocua; sui telefoni ARM l'allocatore protetto la intercetta e uccide il processo.
I suoni brevi non sono in loop e non passano di lì: per questo funzionavano dal primo giorno.

Correzione: 256 campioni di silenzio dopo il punto di loop (`MUSIC_PAD` in `build_music()`), con
test che pretende l'imbottitura. Rimane il fatto che generare il tema costa ~0,5 s su PC e qualche
secondo su telefono, tutti passati sullo splash: da spostare fuori dal primo frame.

## 8. La pubblicità non compariva — fatto (14/09/2026)

L'APK del 13/09 conteneva l'SDK (cinque `classes.dex`, App ID di test nel manifest, tutti i
singleton `PoingGodotAdMob*` inizializzati nel log) ma né il banner né l'interstitial si vedevano
mai. Tre cause, una dietro l'altra. La prima, trovata solo il 14/09 sull'emulatore: **`ads.cfg` non
veniva esportato**. Con `export_filter="all_resources"` Godot mette nell'APK solo le risorse che
riconosce, e un `.cfg` non lo è finché `include_filter` non lo nomina (il plugin aggiunge il proprio
`plugin.cfg` a mano per lo stesso motivo). Senza il file gli unit ID restano vuoti e `ads.gd` spegne
tutto in silenzio: nessun APK costruito fino ad allora lo conteneva. La seconda, latente dietro la
prima, la dice la guida di migrazione del plugin: con l'SDK Next-Gen `MobileAds.initialize()` è
asincrono e caricare prima del callback **solleva un'eccezione**; `ads.gd` caricava appena si toccava
ENTRA IN ASCENSORE. La terza, dietro le prime due: il wrapper GDScript del plugin passa `Array[String]` a metodi nativi che
vogliono `String[]` (`set_request_configuration`, `load_ad`, `load`) e Godot 4.6 li rifiuta con
`Invalid type … JNISingleton` — lo stesso difetto che upstream dichiara di aver corretto solo per il
`RewardedAdLoader`.

Correzione: `include_filter="ads.cfg"` nei due preset, un test che lo pretende e una riga
`AdMob: ads.cfg non trovato` nel log se dovesse mancare di nuovo; le tre chiamate del wrapper patchate in locale con `PackedStringArray(...)` (test di guardia, da riverificare aggiornando l'addon alla 5.1.0); ogni load aspetta
`OnInitializationCompleteListener`; un banner fallito viene distrutto e ritentato alla partita dopo;
ogni esito è stampato con prefisso `AdMob:` così `tools/logcat.ps1` lo cattura. In editor il layer
gira sul mock del plugin e la sequenza è coperta dai test headless.

Resta un avviso innocuo: con il mock acceso, il log dei test termina con `ObjectDB instances leaked
at exit` e `3 resources still in use`, dopo `ALL … CHECKS PASSED`. Il verbose li attribuisce a
`InterstitialAdLoader` del plugin, che tiene il conto dei riferimenti a mano (`reference()` /
`unreference()`) e resta con conteggio zero senza essere liberato: non è raggiungibile da
`ads.gd` né dai test, non tocca l'exit code, e si sceglie di conviverci piuttosto che perdere i test
della sequenza init → load.

Verificato sull'emulatore x86_64 (Android 15) il 14/09/2026: le quattro righe `AdMob:` compaiono nel logcat e il banner di test (etichetta «Test Ad», creatività promozionale del canale YouTube di AdMob) è visibile in partita; la prova sul telefono ARM resta da fare.

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

---

## Da valutare al prossimo playtest

- L'opacità delle porte al 72% (`PLAY_DOOR_ALPHA`, scesa dall'82% il 17/09) e la corsa che si ferma
  a metà griglia: numeri scelti a tavolino, vanno confermati da un bambino vero.
- La garanzia della terza carta che sfuma salendo: certa fino al piano 4 (`HELPER_SURE_FLOOR`),
  spenta dal 16 (`HELPER_GONE_FLOOR`). È l'unica leva ancora in movimento oltre il piano 9, quindi
  decide da sola dove finisce una partita lunga — e nessuno l'ha ancora vista in mano a un bambino.
- La soglia di 14 pixel che separa tocco e trascinamento, su dita piccole e schermi diversi.
- Bilanciamento dei pezzi e frequenza delle forme, mai verificati con un pubblico reale.
- Quantità di bagagli per piano e soglia delle due stelle: numeri a tavolino, da guardare in mano a
  un bambino. Se il riflettore che copre le stelle al piano 3 confonde, spostare le stelle in alto.
