# Scheda Play Store

Tutto il materiale grafico si rigenera con un comando, dallo stesso codice che disegna il gioco:

```powershell
powershell -ExecutionPolicy Bypass -File tools/store.ps1
```

Apre per qualche secondo una finestra di Godot (il renderer headless non sa rileggere un viewport) e
scrive in `artifacts/store/` — fuori da Git, come l'APK. I testi stanno in `listing.cfg`, una
sezione per lingua; un test pretende che rispettino i limiti della console.

## Cosa va dove (Play Console → Presenza sullo store → Scheda principale)

| Campo della console | File | Vincolo |
|---|---|---|
| Icona dell'app | `artifacts/store/icon-512.png` | 512×512 PNG, ≤1 MB, senza trasparenza (la maschera arrotondata la applica Google) |
| Grafica in evidenza | `artifacts/store/<lingua>/feature-1024x500.png` | 1024×500 |
| Screenshot telefono | `artifacts/store/<lingua>/phone/01..05.png` | 1080×1920, da 2 a 8 |
| Screenshot tablet 7" | `artifacts/store/<lingua>/tablet7/01..05.png` | 1200×2133 |
| Screenshot tablet 10" | `artifacts/store/<lingua>/tablet10/01..05.png` | 1600×2844 |
| Nome dell'app | `listing.cfg` → `title` | ≤30 caratteri |
| Descrizione breve | `listing.cfg` → `short` | ≤80 |
| Descrizione completa | `listing.cfg` → `full` (gli `\n` sono a capo) | ≤4000 |

Le lingue vanno caricate come **traduzioni della scheda**: `it-IT` (predefinita) e `en-US`. La stessa
icona vale per entrambe.

I cinque screenshot, nell'ordine: menu; piano 2 con i bagagli e gli animali a bordo; transito con tre
stelle; festa di Elefante Elmo; game over. La didascalia di ciascuno è `caption_1..5` in `listing.cfg`.
Per cambiare un momento ritratto: `setup()` in `tools/store_assets.gd`.

## Prima di pubblicare: cosa la console chiede a un gioco per bambini

Non sono asset, ma senza di questi la scheda non passa in revisione:

1. **Privacy policy** pubblicata a un URL raggiungibile (obbligatoria per chi dichiara un pubblico
   di bambini e per chi usa AdMob). Il testo, bilingue, è `docs/privacy.html`: il gioco non tratta
   dati personali, e la pagina descrive onestamente ciò che l'SDK AdMob può trattare per servire
   annunci non personalizzati. Per pubblicarla: su GitHub, *Settings → Pages → Source: Deploy from a
   branch → `main` / `/docs`*; l'URL diventa `https://paolo975.github.io/OneMore/privacy.html` (il
   file `docs/.nojekyll` evita che GitHub trasformi i documenti di progetto in pagine). Prima di
   inviare in revisione sostituire il segnaposto dell'e-mail di contatto, in entrambe le lingue, con
   l'indirizzo che si vuole rendere pubblico. Lo stesso URL va nella scheda e nella sezione
   *Sicurezza dei dati*.
2. **Pubblico di destinazione e contenuti**: dichiarare la fascia 5 e meno / 6-8; il gioco entra nel
   programma *Progettato per le famiglie* e deve rispettarne la policy (AdMob è un SDK certificato;
   gli annunci sono già child-directed e con rating G nel codice — vedi `MONETIZZAZIONE.md`).
3. **Questionario per la classificazione dei contenuti** (IARC).
4. **Sicurezza dei dati**: l'SDK AdMob raccoglie identificatori del dispositivo e dati di
   diagnostica per servire annunci; il gioco in sé non raccoglie nulla e non ha account.
5. **Annunci**: spuntare «l'app contiene annunci».
6. Categoria consigliata: *Puzzle* (o *Educativi*); e-mail di contatto dello sviluppatore.
7. La build da caricare è la **release** firmata: `tools/build.ps1 -Target Android -Release` scrive
   `artifacts/AncoraUno-release.apk` firmata con la chiave in `keystore/` (fuori da Git: farne una
   copia di sicurezza). Solo lei usa gli unit ID di produzione di `ads.cfg`. Il pacchetto è
   `com.neomobile.onemore` e non si può più cambiare dopo la pubblicazione.
