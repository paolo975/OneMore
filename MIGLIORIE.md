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

---

## Da valutare al prossimo playtest

- L'opacità delle porte all'82% e la corsa che si ferma a metà griglia: numeri scelti a tavolino,
  vanno confermati da un bambino vero.
- La soglia di 14 pixel che separa tocco e trascinamento, su dita piccole e schermi diversi.
- Bilanciamento dei pezzi e frequenza delle forme, mai verificati con un pubblico reale.
