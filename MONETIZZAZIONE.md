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

| Dove | Test (ora) | Produzione |
|---|---|---|
| `project.godot` → `[admob] general/android/app_id` | `ca-app-pub-3940256099942544~3347511713` | il tuo App ID |
| `ads.cfg` → `[ads] test` | `true` | `false` |
| `ads.cfg` → `[production] banner` | vuoto | il tuo unit ID banner |
| `ads.cfg` → `[production] interstitial` | vuoto | il tuo unit ID interstitial |

Gli ID di test di Google mostrano annunci veri con la scritta *Test Ad*, non generano ricavi e non
violano le policy. **Non usare mai gli ID di produzione in una build di debug** o mentre si prova
sul proprio telefono: AdMob rileva il traffico non valido e sospende l'account.

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
