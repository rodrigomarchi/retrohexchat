# RetroHexChat — Italian Rooms — `it`

Ten channels, twelve bots, nineteen verified feeds. Documentation in English for
the operator; everything a user reads is in Italian.

Italian publishes more technology than anything else that survived the feed
check — eight of the nineteen sources — so the tech block is split three ways
rather than crammed into one room: `#digitale` for the consumer press,
`#tecnologie` for the trade press, `#telefonini` for phones. A single room fed by
eight sources scrolls faster than anyone reads.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Installazione it
#  10 canali · 12 bot · feed verificati uno per uno
# ══════════════════════════════════════════════════════════

# ── 1. Canali ────────────────────────────────────────────

/join #italia
/cs register
/topic Canale italiano — entra, siediti, si chiacchiera. Il caffè lo offre la casa.
/mode +tn

/join #cronaca
/cs register
/topic Cronaca — Corriere e Adnkronos, direttamente dal feed. !Vittorio fonti mostra l'elenco.
/mode +tn

/join #attualita
/cs register
/topic Attualità — Il Fatto Quotidiano e Open. Il commento, dopo che la cronaca è passata.
/mode +tn

/join #digitale
/cs register
/topic Digitale — DDay, HDblog e Wired Italia. Prodotti, servizi e il mondo che ci gira intorno.
/mode +tn

/join #tecnologie
/cs register
/topic Tecnologie — Punto Informatico, Il Software e Tom's Hardware. Il supporto di un progetto sta nel progetto; qui si parla.
/mode +tn

/join #telefonini
/cs register
/topic Telefonini — AndroidWorld e SmartWorld. Telefoni, orologi e caricabatterie che non entrano da nessuna parte.
/mode +tn

/join #videogiochi
/cs register
/topic Videogiochi — Everyeye e SpazioGames. Per giocare davvero apri il menu Games: 18 classici nel browser.
/mode +tn

/join #calcio
/cs register
/topic Calcio — la Gazzetta sul filo. Classifica, mercato e la discussione di sempre.
/mode +tn

/join #spazio
/cs register
/topic Spazio — Media INAF. Astrofisica, missioni e cielo osservato per mestiere.
/mode +tn

/join #finanza
/cs register
/topic Finanza — Il Sole 24 Ore. Un titolo non è un consiglio.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Guardiano — moderazione, tutti i canali
# ══════════════════════════════════════════════════════════
# Ogni lingua ha il suo moderatore: un avviso che nessuno legge non è un avviso.
# Muto all'entrata e all'uscita — sta in tutti e dieci i canali, e un buttafuori
# che saluta due volte sembra un difetto, non un personaggio.
/bot create Guardiano Capo della quiete e della buona creanza
/bot set Guardiano prefix !
/bot set Guardiano cooldown 1000
/bot set Guardiano mod_action warn
/bot set Guardiano mod_spam 5
/bot set Guardiano mod_flood 8
/bot set Guardiano mod_warn \c04\b[Guardiano]\o Piano, {nickname}. \c05Con educazione\o si sta meglio, e io ho tutto il tempo del mondo.
/bot set Guardiano greeting none
/bot set Guardiano farewell none
/bot set Guardiano mention_response \c04\b[Guardiano]\o Guardo. \c05Guardo sempre\o. Comportati bene e andremo d'accordo.

/bot addcmd Guardiano regole \c04\b[Guardiano]\o Versione breve: \c05non fare il cretino\o. Versione lunga: non esiste.
/bot addcmd Guardiano segnala \c04\b[Guardiano]\o Visto qualcosa di strano? \c05Avvisa un admin\o. Io curo l'automatico, le persone il resto.

/bot join Guardiano #italia
/bot join Guardiano #cronaca
/bot join Guardiano #attualita
/bot join Guardiano #digitale
/bot join Guardiano #tecnologie
/bot join Guardiano #telefonini
/bot join Guardiano #videogiochi
/bot join Guardiano #calcio
/bot join Guardiano #spazio
/bot join Guardiano #finanza

# ══════════════════════════════════════════════════════════
#  3. Rita — padrona di casa in #italia
# ══════════════════════════════════════════════════════════
# Benvenuto in notice privato: chi arriva si orienta dentro il canale senza
# riempire la cronologia di tutti gli altri.
/bot create Rita Padrona di casa del canale italiano
/bot set Rita prefix !
/bot set Rita cooldown 1000
/bot set Rita dice_default 1d20
/bot set Rita greeting \c03\b[Rita]\o Ciao {nickname}! Sono Rita. \c02Prova !canali\o, !buongiorno o !inglese. Mettiti comodo.
/bot set Rita greeting_delivery private_notice
/bot set Rita greeter_repeat_window 43200
/bot set Rita farewell none
/bot set Rita mention_response \c03\b[Rita]\o Mi hai chiamata? Sono qui. \c02Prova !canali\o.

/bot addcmd Rita canali \c03\b[Rita]\o #italia #cronaca #attualita #digitale #tecnologie #telefonini #videogiochi #calcio #spazio #finanza — \c02dieci canali in italiano\o, e in ognuno succede qualcosa.
/bot addcmd Rita buongiorno \c03\b[Rita]\o \c02Buongiorno\o, {nickname}. Caffè fatto, tastiera pulita, giornata avviata.
/bot addcmd Rita inglese \c03\b[Rita]\o Ci sono anche canali in inglese, {nickname}: \c02#lobby, #tech, #news\o e altri. La lingua si cambia dalla barra degli strumenti.
/bot addcmd Rita accenti \c03\b[Rita]\o I nomi dei canali vanno senza accento, {nickname} — \c02il client trasforma in link solo l'ASCII\o. Dentro al canale scrivi come si deve.

/bot join Rita #italia

# ══════════════════════════════════════════════════════════
#  4. Bot di feed — uno per canale
# ══════════════════════════════════════════════════════════
# Ogni indirizzo qui sotto è stato scaricato dal fetcher di produzione e letto
# dal parser dell'applicazione prima di essere scritto. Il primo controllo
# pubblica la pagina ricevuta e la registra; poi esce solo ciò che è nuovo.

# ── Enzo — #italia ───────────────────────────────────────
# Nessun benvenuto: in questo canale accoglie Rita.
/bot create Enzo Cronista di turno
/bot set Enzo prefix !
/bot set Enzo cooldown 1000
/bot set Enzo rss_interval 20
/bot set Enzo rss_max_items 10000
/bot set Enzo greeting none
/bot set Enzo farewell none
/bot set Enzo mention_response \c03\b[Enzo]\o Leggo ANSA e Rai News. \c02!fonti\o elenca i feed.
/bot addcmd Enzo fonti \c03\b[Enzo]\o ANSA e Rai News, controllati \c02ogni venti minuti\o.
/bot join Enzo #italia
/bot rss add Enzo https://www.ansa.it/sito/ansait_rss.xml #italia
/bot rss add Enzo https://www.rainews.it/rss/tutti #italia

# ── Vittorio — #cronaca ──────────────────────────────────
/bot create Vittorio Capo della cronaca
/bot set Vittorio prefix !
/bot set Vittorio cooldown 1000
/bot set Vittorio rss_interval 20
/bot set Vittorio rss_max_items 10000
/bot set Vittorio greeting \c02\b[Vittorio]\o Benvenuto in #cronaca, {nickname}. \c14I titoli arrivano da soli\o — !fonti dice da dove.
/bot set Vittorio greeting_delivery private_notice
/bot set Vittorio greeter_repeat_window 43200
/bot set Vittorio farewell none
/bot set Vittorio mention_response \c02\b[Vittorio]\o Pubblico quello che manda il feed. \c14!fonti\o per l'elenco, !primo per il resto.
/bot addcmd Vittorio fonti \c02\b[Vittorio]\o Corriere della Sera e Adnkronos, controllati \c14ogni venti minuti\o.
/bot addcmd Vittorio primo \c02\b[Vittorio]\o Il primo scaricamento di un feed pubblica la pagina attuale e la registra. Dopo, \c14esce solo il nuovo\o.
/bot join Vittorio #cronaca
/bot rss add Vittorio https://xml2.corriereobjects.it/rss/homepage.xml #cronaca
/bot rss add Vittorio https://www.adnkronos.com/RSS_Cronaca.xml #cronaca

# ── Franca — #attualita ──────────────────────────────────
/bot create Franca Commentatrice di attualita
/bot set Franca prefix !
/bot set Franca cooldown 1000
/bot set Franca rss_interval 30
/bot set Franca rss_max_items 10000
/bot set Franca greeting \c07\b[Franca]\o Benvenuto, {nickname}. \c11Il Fatto Quotidiano e Open\o arrivano qui da soli. !fonti per l'elenco.
/bot set Franca greeting_delivery private_notice
/bot set Franca greeter_repeat_window 43200
/bot set Franca farewell none
/bot set Franca mention_response \c07\b[Franca]\o Due testate, due tagli diversi. \c11!fonti\o le elenca.
/bot addcmd Franca fonti \c07\b[Franca]\o Il Fatto Quotidiano e Open, controllati \c11ogni mezz'ora\o.
/bot join Franca #attualita
/bot rss add Franca https://www.ilfattoquotidiano.it/feed/ #attualita
/bot rss add Franca https://www.open.online/feed/ #attualita

# ── Gianni — #digitale ───────────────────────────────────
/bot create Gianni Curioso di cose digitali
/bot set Gianni prefix !
/bot set Gianni cooldown 1000
/bot set Gianni rss_interval 30
/bot set Gianni rss_max_items 10000
/bot set Gianni greeting \c12\b[Gianni]\o Ciao {nickname}. \c10DDay, HDblog e Wired Italia\o cadono qui da soli. !fonti per l'elenco.
/bot set Gianni greeting_delivery private_notice
/bot set Gianni greeter_repeat_window 43200
/bot set Gianni farewell none
/bot set Gianni mention_response \c12\b[Gianni]\o Tre feed sul filo. \c10!fonti\o dice quali.
/bot addcmd Gianni fonti \c12\b[Gianni]\o DDay, HDblog e Wired Italia, controllati \c10ogni mezz'ora\o.
/bot join Gianni #digitale
/bot rss add Gianni https://www.dday.it/rss #digitale
/bot rss add Gianni https://www.hdblog.it/feed/ #digitale
/bot rss add Gianni https://www.wired.it/feed/rss #digitale

# ── Nilde — #tecnologie ──────────────────────────────────
/bot create Nilde Lettrice della stampa tecnica
/bot set Nilde prefix !
/bot set Nilde cooldown 1000
/bot set Nilde rss_interval 45
/bot set Nilde rss_max_items 10000
/bot set Nilde greeting \c10\b[Nilde]\o Benvenuto, {nickname}. \c06Punto Informatico, Il Software e Tom's Hardware\o sul filo. !fonti per l'elenco, !supporto prima di chiedere.
/bot set Nilde greeting_delivery private_notice
/bot set Nilde greeter_repeat_window 43200
/bot set Nilde farewell none
/bot set Nilde mention_response \c10\b[Nilde]\o Stampa tecnica, non assistenza. \c06!fonti\o elenca il filo.
/bot addcmd Nilde fonti \c10\b[Nilde]\o Punto Informatico, Il Software e Tom's Hardware Italia, controllati \c06ogni 45 minuti\o.
/bot addcmd Nilde supporto \c10\b[Nilde]\o Il supporto di un progetto sta nel progetto, {nickname} — lì risponde chi lo mantiene. \c06Qui si chiacchiera\o.
/bot join Nilde #tecnologie
/bot rss add Nilde https://www.punto-informatico.it/feed/ #tecnologie
/bot rss add Nilde https://www.ilsoftware.it/feed/ #tecnologie
/bot rss add Nilde https://www.tomshw.it/feed/ #tecnologie

# ── Bruno — #telefonini ──────────────────────────────────
/bot create Bruno Provinista di telefoni
/bot set Bruno prefix !
/bot set Bruno cooldown 1000
/bot set Bruno rss_interval 45
/bot set Bruno rss_max_items 10000
/bot set Bruno greeting \c13\b[Bruno]\o Entra, {nickname}. \c11AndroidWorld e SmartWorld\o sul filo — !fonti per l'elenco.
/bot set Bruno greeting_delivery private_notice
/bot set Bruno greeter_repeat_window 43200
/bot set Bruno farewell none
/bot set Bruno mention_response \c13\b[Bruno]\o Telefoni, orologi e caricabatterie. \c11!fonti\o elenca il filo.
/bot addcmd Bruno fonti \c13\b[Bruno]\o AndroidWorld e SmartWorld, controllati \c11ogni 45 minuti\o.
/bot join Bruno #telefonini
/bot rss add Bruno https://www.androidworld.it/feed/ #telefonini
/bot rss add Bruno https://www.smartworld.it/feed #telefonini

# ── Ciccio — #videogiochi ────────────────────────────────
/bot create Ciccio Gestore della sala giochi
/bot set Ciccio prefix !
/bot set Ciccio cooldown 1000
/bot set Ciccio rss_interval 45
/bot set Ciccio rss_max_items 10000
/bot set Ciccio greeting \c12\b[Ciccio]\o Dentro, {nickname}! \c10Everyeye e SpazioGames\o sul filo, e il menu Games apre 18 classici nel browser. !fonti, !giocare.
/bot set Ciccio greeting_delivery private_notice
/bot set Ciccio greeter_repeat_window 43200
/bot set Ciccio farewell none
/bot set Ciccio mention_response \c12\b[Ciccio]\o Le notizie sui giochi le porto io. \c10!giocare\o spiega come si gioca qui.
/bot addcmd Ciccio fonti \c12\b[Ciccio]\o Everyeye e SpazioGames, controllati \c10ogni 45 minuti\o.
/bot addcmd Ciccio giocare \c12\b[Ciccio]\o Apri il menu \c10Games\o in alto, {nickname}: DOOM, Quake, Wolfenstein e sei avventure ScummVM, tutto nel browser.
/bot join Ciccio #videogiochi
/bot rss add Ciccio https://www.everyeye.it/rss/news.xml #videogiochi
/bot rss add Ciccio https://www.spaziogames.it/feed #videogiochi

# ── Toto — #calcio ───────────────────────────────────────
/bot create Toto Cronista da tribuna
/bot set Toto prefix !
/bot set Toto cooldown 1000
/bot set Toto rss_interval 20
/bot set Toto rss_max_items 10000
/bot set Toto greeting \c09\b[Toto]\o Ciao {nickname}! \c03La Gazzetta dello Sport\o sul filo. !fonti per l'elenco, !squadra se proprio insisti.
/bot set Toto greeting_delivery private_notice
/bot set Toto greeter_repeat_window 43200
/bot set Toto farewell none
/bot set Toto mention_response \c09\b[Toto]\o Palla al centro. \c03!fonti\o dice cosa leggo.
/bot addcmd Toto fonti \c09\b[Toto]\o La Gazzetta dello Sport, controllata \c03ogni venti minuti\o.
/bot addcmd Toto squadra \c09\b[Toto]\o La mia non te la dico, {nickname}. \c03Un bot con la squadra\o perde mezzo canale al primo derby.
/bot join Toto #calcio
/bot rss add Toto https://www.gazzetta.it/rss/home.xml #calcio

# ── Galileo — #spazio ────────────────────────────────────
/bot create Galileo Osservatore del cielo
/bot set Galileo prefix !
/bot set Galileo cooldown 1000
/bot set Galileo rss_interval 60
/bot set Galileo rss_max_items 10000
/bot set Galileo greeting \c11\b[Galileo]\o Benvenuto, {nickname}. \c02Media INAF\o arriva ogni ora — astrofisica fatta da chi la fa. !fonti per l'elenco.
/bot set Galileo greeting_delivery private_notice
/bot set Galileo greeter_repeat_window 43200
/bot set Galileo farewell none
/bot set Galileo mention_response \c11\b[Galileo]\o Pubblico Media INAF. \c02!fonti\o per l'elenco.
/bot addcmd Galileo fonti \c11\b[Galileo]\o Media INAF, l'istituto nazionale di astrofisica, controllato \c02ogni ora\o.
/bot join Galileo #spazio
/bot rss add Galileo https://www.media.inaf.it/feed/ #spazio

# ── Piero — #finanza ─────────────────────────────────────
/bot create Piero Osservatore dei mercati
/bot set Piero prefix !
/bot set Piero cooldown 1000
/bot set Piero rss_interval 30
/bot set Piero rss_max_items 10000
/bot set Piero greeting \c07\b[Piero]\o Buongiorno, {nickname}. \c14Il Sole 24 Ore\o sul filo — !fonti per l'elenco, !avviso prima di crederci.
/bot set Piero greeting_delivery private_notice
/bot set Piero greeter_repeat_window 43200
/bot set Piero farewell none
/bot set Piero mention_response \c07\b[Piero]\o Leggo Il Sole 24 Ore. \c14!fonti\o per l'elenco.
/bot addcmd Piero fonti \c07\b[Piero]\o Il Sole 24 Ore, sezione economia, controllato \c14ogni mezz'ora\o.
/bot addcmd Piero avviso \c07\b[Piero]\o Un titolo non è un consiglio, {nickname}. \c14Io leggo feed\o, non sfere di cristallo.
/bot join Piero #finanza
/bot rss add Piero https://www.ilsole24ore.com/rss/economia.xml #finanza
```

---

## Verification

```
/bot list
/bot info Guardiano
/admin channel list
```

`!Enzo rss list` in `#italia` shows what a bot actually stored — the check that
matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#italia` | **Rita**, Enzo | ANSA, Rai News |
| `#cronaca` | **Vittorio** | Corriere, Adnkronos |
| `#attualita` | **Franca** | Il Fatto Quotidiano, Open |
| `#digitale` | **Gianni** | DDay, HDblog, Wired Italia |
| `#tecnologie` | **Nilde** | Punto Informatico, Il Software, Tom's Hardware |
| `#telefonini` | **Bruno** | AndroidWorld, SmartWorld |
| `#videogiochi` | **Ciccio** | Everyeye, SpazioGames |
| `#calcio` | **Toto** | Gazzetta dello Sport |
| `#spazio` | **Galileo** | Media INAF |
| `#finanza` | **Piero** | Il Sole 24 Ore |

**Guardiano** stands in all ten and greets in none of them. All channels are `+tn`.
