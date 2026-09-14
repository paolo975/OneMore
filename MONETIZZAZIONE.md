# Pubblicità

Aggiornato il 12/09/2026. Il piano precedente (un solo rewarded per +1 vita, nessun SDK nel
prototipo) è superato: ora il gioco integra il [Godot AdMob Plugin di Poing Studios](https://github.com/poingstudios/godot-admob-plugin)
v5.0.0 con due formati.

## Cosa c'è

- **Banner** adattivo ancorato in basso, visibile durante la partita. Il layout gli riserva una fascia
  di 90 unità (`scripts/ads.gd`, `BANNER_RESERVE`): carte e testi si alzano, niente viene coperto.
- **Interstitial** a tutto schermo al game over, precaricato all'inizio della partita e mostrato prima
  della schermata "Bella squadra!". Se non è pronto si salta senza attese.
- **Child-directed**: `RequestConfiguration` con `tag_for_child_directed_treatment = TRUE` e
  `max_ad_content_rating = G`. Con questo flag Google serve solo annunci non personalizzati.

## Test e produzione

Dal 14/09/2026 gli ID del conto AdMob del gioco sono nel repository e la scelta tra test e
produzione è **automatica per tipo di build** (`OS.is_debug_build()` in `scripts/ads.gd`):

| Dove | Valore | Quando si usa |
|---|---|---|
| `project.godot` → `[admob] general/android/app_id` | `ca-app-pub-1563447385855068~4808739978` | sempre (finisce nel manifest; Google consiglia l'App ID vero anche in sviluppo) |
| `ads.cfg` → `[test] banner` / `interstitial` | ID di test ufficiali di Google | editor, test headless, ogni APK di debug (`tools/build.ps1`) |
| `ads.cfg` → `[production] banner` | `ca-app-pub-1563447385855068/1480256094` | solo build release |
| `ads.cfg` → `[production] interstitial` | `ca-app-pub-1563447385855068/5429530382` | solo build release |
| `ads.cfg` → `[ads] test` | `false` | `true` forza gli ID di test anche in release |

Gli ID di test di Google mostrano annunci veri con la scritta *Test Ad*, non generano ricavi e non
violano le policy. **Un annuncio di produzione mostrato sul proprio telefono è traffico non valido**
e AdMob sospende l'account: per questo la build di debug non può usarli, qualunque cosa dica il
file, e un test lo verifica. La build release (`--export-release`, keystore di rilascio ancora da
creare) è l'unica che mostra annunci veri: provarla solo su un dispositivo registrato come *test
device* nella console AdMob.

## Prima di pubblicare

Il pubblico dichiarato è di bambini. Questo comporta, in ordine:

1. **Google Play Families Policy**: solo SDK certificati (AdMob lo è), annunci adatti all'età,
   nessun annuncio ingannevole o che interrompa il gioco in modo invadente. L'interstitial al game
   over è in zona grigia e va confrontato con la versione della policy in vigore al momento.
2. **COPPA / GDPR-K**: il flag child-directed è impostato nel codice; va dichiarato anche nella
   console AdMob e nella scheda Play Console (sezione *Target audience and content*).
   - `tag_for_under_age_of_consent` (TFUA) in `scripts/ads.gd` è ancora `UNSPECIFIED`: per un pubblico
     di 4-6 anni in UE/UK va impostato a `TRUE` accanto al flag child-directed. Ora che
     `set_request_configuration` viene davvero eseguita (MIGLIORIE §8) l'impostazione ha effetto.
3. **Privacy policy** pubblicata a un URL, obbligatoria sia per AdMob sia per Play Store.
4. **Consenso UMP** per l'Europa: il plugin include `UserMessagingPlatform`; non è ancora
   cablato nel gioco.

Nessuna di queste cose serve per provare la build di test sul telefono.
