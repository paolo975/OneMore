# Ancora uno!

Prototipo Godot 4.6 di un puzzle verticale per Android. Un ascensore da 5×5 caselle e una banda originale di animali: Dino Bronto, Panda Pip, Cocco Crunch, Giraffa Gigi e Triceratò, raggiunti da Elefante Elmo al terzo piano e da Tartaruga Tea al quinto. Palette crema, corallo, menta e viola; disegni vettoriali procedurali e suoni sintetizzati originali, senza dipendenze artistiche esterne.

## Giocare

- Apri `artifacts/AncoraUno.exe` su Windows, oppure installa `artifacts/AncoraUno-debug.apk` su Android.
- **Tocca** un animale nella coda per girarlo, **trascinalo** nella griglia per farlo salire. Due gesti, nessun pulsante: la distinzione è la distanza percorsa dal dito. Su PC funziona anche il tasto R.
- Un animale già salito non si sposta più: una volta in ascensore è sistemato. Un rilascio fuori dalla griglia non lo fa salire e lo lascia in coda.
- Il conto alla rovescia parte appena si apre il piano, anche se non tocchi niente: restare fermi costa una vita come sbagliare. Raggiungi il minimo indicato da **CELLE / MIN**; ogni animale in più vale punti.
- Le porte si chiudono da sole: sono già socchiuse quando il piano si apre e avanzano verso il centro man mano che il tempo scende, fermandosi a metà corsa così ogni casella resta raggiungibile fino all'ultimo. Allo scadere del timer **PORTE** l'ascensore parte e le porte finiscono di chiudersi. Se non hai raggiunto l'obiettivo perdi una delle tre vite. Gli ultimi cinque secondi lampeggiano e producono un breve suono, disattivabile.
- Se riempi tutte le caselle libere l'ascensore parte subito, senza aspettare il timer.
- Dal secondo piano alcune caselle sono già occupate da **bagagli** lasciati in ascensore — valigie, piante, scatole: uno al piano 2, poi uno in più ogni due piani fino a cinque dal piano 9. Gli animali non ci salgono sopra e il minimo lascia sempre almeno tre caselle libere oltre l'obiettivo.
- A ogni partenza riuscita le porte chiuse mostrano da una a tre **stelle**: una per il minimo, due a metà strada tra minimo e ascensore pieno, tre per l'ascensore pieno. Il totale della partita è sulla schermata finale, accanto al punteggio.
- Quando un animale nuovo entra nel cast il transito si allunga e lo presenta sotto un riflettore, con rimbalzo e fanfara: Elefante Elmo alla partenza dal piano 2, Tartaruga Tea da quello 4.
- Il cast cresce salendo: i primi cinque animali ci sono da subito, Elefante Elmo entra in coda dal piano 3 e Tartaruga Tea dal piano 5. Crescono anche le forme: la L c'è dal primo piano, il quadrato dal terzo, la barra da tre dal quinto, la T dal settimo.
- Ogni partenza riuscita vale 10 punti per casella più 2 per secondo residuo. L'obiettivo aumenta da 10 a 17 caselle, il tempo cala di tre secondi a piano: 34 al primo, 31 al secondo, 28 al terzo, fino al minimo di 16 al settimo.
- Il pulsante pausa o Esc sospende la partita. L'app si mette in pausa quando perde il focus. La nota musicale attiva e disattiva audio e musica.
- Il tema di sottofondo è generato dal gioco stesso all'avvio — melodia pentatonica su un giro I-V-vi-IV, ciclo di otto secondi — quindi non esiste come file e non porta licenze con sé. Il buffer ha 256 campioni di silenzio oltre il punto di loop: senza, il mixer WAV di Godot legge un campione fuori dai dati e i telefoni ARM chiudono il processo (vedi `MIGLIORIE.md`, punto 7).
- Il gioco parla italiano sui dispositivi in italiano e inglese su tutti gli altri: la lingua si sceglie da sola all'avvio dal locale del sistema. Tutte le frasi stanno in `scripts/strings.gd`, una riga per frase con le due colonne `it` e `en`.
- Record e preferenza audio restano sul dispositivo. Nessun account. L'unico traffico di rete è quello degli annunci AdMob, vedi sotto.
- Pubblicità: un banner adattivo ancorato in basso durante la partita e un interstitial a tutto schermo al game over, prima della schermata finale. Gli annunci sono configurati come **child-directed** con classificazione **G**, quindi non personalizzati. Gli ID stanno in `ads.cfg`: ogni build di debug (editor, test, APK di prova) usa quelli di test di Google, solo la build release usa quelli del conto AdMob del gioco.

La terza carta propone sempre un animale da una casella: evita situazioni impossibili e rende il primo prototipo accessibile. Bilanciamento e frequenza dei pezzi sono da valutare con playtest reali.

## Sviluppo e build

Godot, Temurin JDK 17 e Android SDK sono installati per questo utente in `%LOCALAPPDATA%/AncoraUnoTools`. I template di export 4.6 sono in `%APPDATA%/Godot/export_templates/4.6.stable`. Non è stato modificato il PATH di sistema.

```powershell
powershell -ExecutionPolicy Bypass -File tools/run.ps1
powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Editor
powershell -ExecutionPolicy Bypass -File tools/test.ps1
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target All
powershell -ExecutionPolicy Bypass -File tools/store.ps1
```

Su un altro PC installare [Godot 4.6](https://godotengine.org/download/archive/4.6-stable/) con template corrispondenti e seguire la [configurazione Android ufficiale](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). Configurare Java SDK Path e Android SDK Path nelle impostazioni dell'editor. Per l'APK servono platform-tools, build-tools 35.0.1 e le piattaforme android-35 e **android-36**: le librerie AdMob 5.x richiedono `compileSdk 36`, che il template di Godot 4.6 non ha (porta 35). `tools/build.ps1` alza il valore in `android/build/config.gradle` a ogni build, così sopravvive alla reinstallazione del template. L'export Android usa la **build Gradle** (`gradle_build/use_gradle_build=true`, con `compress_native_libraries=true` perché altrimenti l'APK triplica), obbligatoria per il plugin AdMob: il template Android è installato in `android/build/` (escluso da Git, si rigenera dall'editor con *Project → Install Android Build Template*) e la prima build scarica Gradle e le dipendenze, quindi richiede rete e qualche minuto. Nessun NDK/CMake.

### Pubblicità (AdMob)

Il plugin è [Godot AdMob Plugin di Poing Studios](https://github.com/poingstudios/godot-admob-plugin) v5.0.0, in `addons/admob/`, con i binari Android in `addons/admob/android/bin/` (esclusi da Git dal plugin stesso: in modalità headless li riscarica da solo). Configurazione:

- `project.godot`, sezione `[admob]`: `general/android/app_id` è l'**App ID** (quello con la tilde `~`). Attenzione: Godot, quando salva le impostazioni, **omette le voci uguali al valore predefinito**, e il predefinito del plugin è proprio l'App ID di test di Google — quindi finché si resta in test la sezione `[admob]` può non comparire affatto nel file, ed è normale. Appena si scrive un App ID di produzione la voce resta.
- `ads.cfg`: la sezione `[production]` contiene gli unit ID del conto AdMob del gioco, la sezione `[test]` quelli ufficiali di Google. La scelta è **automatica per tipo di build**: `OS.is_debug_build()` (editor, test, ogni APK prodotta da `tools/build.ps1`, che esporta in debug) → ID di test; build release → ID di produzione. `test=true` forza gli ID di test anche in release; se `[production]` è vuota il gioco ricade sui test e lo scrive nel log (`AdMob: sezione [production] vuota`). Un test pretende che gli ID di produzione appartengano al conto `ca-app-pub-1563447385855068` e che una build di debug resti sui test: mai annunci veri sul proprio telefono. La build release si ottiene con `tools/build.ps1 -Target Android -Release`, firmata con la chiave in `keystore/`.
- `scripts/ads.gd`: lo strato che parla col plugin. Senza il plugin nativo (test, Windows, editor) ogni chiamata non fa nulla, così il gioco non dipende mai da un annuncio.
- `ads.cfg` non è una risorsa Godot: con `export_filter="all_resources"` finisce nell'APK solo perché `include_filter` lo nomina — senza, gli unit ID restano vuoti e il gioco spegne la pubblicità in silenzio (è successo: nessun APK fino al 14/09 lo conteneva; ora un test lo pretende e `ads.gd` lo dice nel log). L'SDK Next-Gen di AdMob si inizializza in modo **asincrono** e solleva un'eccezione se si carica un annuncio prima del callback: `ads.gd` aspetta `OnInitializationCompleteListener` prima di qualsiasi load, ritenta un banner fallito alla partita successiva e stampa ogni esito con prefisso `AdMob:`. Per verificare sul telefono: `tools/build.ps1 -Target Android`, `adb install -r artifacts/AncoraUno-debug.apk`, poi `tools/logcat.ps1 -Seconds 150` toccando ENTRA IN ASCENSORE entro venti secondi e lasciando scadere i tre piani. In `artifacts/logcat.txt` devono comparire, in ordine, `AdMob: inizializzato`, `AdMob: banner caricato`, `AdMob: interstitial caricato`, `AdMob: interstitial mostrato`; un `AdMob: banner fallito codice N` si legge con la tabella del plugin (0 interno, 1 richiesta non valida, 2 rete, 3 nessun annuncio). In editor il layer gira sul mock del plugin: un banner finto bianco e un interstitial finto nero, utili per vedere il layout.
- Il wrapper GDScript del plugin v5.0.0 passa `Array[String]` a tre metodi nativi che dichiarano `String[]` (`set_request_configuration`, `AdView.load_ad`, `InterstitialAdLoader.load`) e Godot 4.6 li rifiuta con `Invalid type … JNISingleton`: nessun annuncio si caricava. Le tre chiamate in `addons/admob/gdscript/src/api/` sono **patchate in locale** con `PackedStringArray(...)` e un test lo pretende — reinstallando l'addon la patch va riapplicata o va verificato che la v5.1.0 (13/09/2026) l'abbia risolto.

Il pubblico è di bambini: prima di pubblicare vanno verificati la Families Policy di Google Play e la COPPA, serve una privacy policy pubblicata (il testo bilingue è `docs/privacy.html`, da servire con GitHub Pages: istruzioni in `store/README.md`), e l'interstitial al game over va confrontato con le regole sugli annunci a tutto schermo per gli under 13 in vigore al momento.

I download di Godot e dei template sono stati confrontati con SHA512-SUMS ufficiale; JDK e strumenti SDK con i checksum pubblicati dalle rispettive fonti.

La chiave Android **debug** è fuori dal repository, in `%APPDATA%/Godot/keystores/debug.keystore`. La chiave di **release** è in `keystore/` (cartella esclusa da Git): `release.keystore` più `release.properties` con alias e password, che `tools/build.ps1 -Release` legge e passa a Godot tramite le variabili `GODOT_ANDROID_KEYSTORE_RELEASE_*`. **Farne una copia di sicurezza fuori dal PC**: senza quella chiave non si può più aggiornare l'app pubblicata. Package: `com.neomobile.onemore`. Include ARM64 per telefoni e x86_64 per emulatore. Nessun AAB ancora: il preset esporta APK.

## File

- `scripts/game.gd`: regole, interfaccia, personaggi, input e audio. La costante `ANIMALS` è una riga per animale: colori, tratti del corpo e della testa, e il campo `floor` che decide da quale piano compare. Aggiungere un personaggio significa aggiungere una riga e, se serve, un nuovo caso in `draw_person`.
- `tests/game_test.gd`: regressioni su incastri, timer, vite, punteggio, pausa e salvataggio, con record di test separato.
- `export_presets.cfg`: preset Android e Windows.
- `store/`: la scheda Play Store — testi in `listing.cfg` (italiano e inglese, con un test sui limiti della console) e `README.md` con dove va cosa e la checklist per un gioco per bambini. Icona 512, grafica in evidenza e quindici screenshot con didascalia per lingua (telefono, tablet 7" e 10") si generano con `tools/store.ps1` in `artifacts/store/`, dallo stesso codice che disegna il gioco; la stessa corsa scrive `assets/icon.png`, l'icona dell'app.
- `artifacts/`: eseguibili, anteprima e log locali (esclusi da Git).
- `MONETIZZAZIONE.md`: valutazione dell'integrazione futura, senza annunci nel prototipo.

Le forme e i personaggi sono un'interpretazione semplificata per validare il gameplay, non illustrazioni definitive da store. Mancano ancora playtest su telefoni reali con bambini, rifinitura artistica, accessibilità con lettore schermo e lingue oltre a italiano e inglese.
