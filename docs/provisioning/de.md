# RetroHexChat — German Rooms — `de`

Ten channels, twelve bots, twenty verified feeds. Documentation in English for
the operator; everything a user reads is in German.

`#dach` is the room that would not exist in a naive translation of the English
script. German-language news is not one newsroom: Der Standard and the NZZ write
for Vienna and Zurich, and putting them in `#nachrichten` next to the Tagesschau
would bury both. One room for Germany, one for the rest of the German-speaking
world.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Einrichtung de
#  10 Räume · 12 Bots · Feeds einzeln geprüft
# ══════════════════════════════════════════════════════════

# ── 1. Räume ─────────────────────────────────────────────

/join #deutschland
/cs register
/topic Deutschsprachiger Raum — reinkommen, hinsetzen, reden. Der Kaffee geht aufs Haus.
/mode +tn

/join #nachrichten
/cs register
/topic Nachrichten — Spiegel, SZ, FAZ und Deutschlandfunk, direkt aus dem Feed. !Greta quellen zeigt die Liste.
/mode +tn

/join #dach
/cs register
/topic Österreich und Schweiz — Der Standard und NZZ. Deutschsprachig ist nicht dasselbe wie deutsch.
/mode +tn

/join #technik
/cs register
/topic Technik — heise und Golem. Projekt-Support gehört zum Projekt; hier wird geredet.
/mode +tn

/join #netz
/cs register
/topic Netz — netzpolitik.org und t3n. Digitalpolitik, Plattformen, das Kleingedruckte.
/mode +tn

/join #computer
/cs register
/topic Computer — ComputerBase am Draht. Hardware, Bauteile, Bastelei.
/mode +tn

/join #wirtschaft
/cs register
/topic Wirtschaft — Handelsblatt und WirtschaftsWoche. Eine Schlagzeile ist keine Empfehlung.
/mode +tn

/join #wissenschaft
/cs register
/topic Wissenschaft — Spektrum und wissenschaft.de. Dumme Fragen gibt es nicht, nur ungestellte.
/mode +tn

/join #sport
/cs register
/topic Sport — kicker und Sportschau. Tabelle, Transfers und die übliche Diskussion.
/mode +tn

/join #spiele
/cs register
/topic Spiele — Eurogamer.de am Draht. Wer wirklich spielen will: Menü Games, 18 Klassiker im Browser.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Wachtmeister — Moderation, alle Räume
# ══════════════════════════════════════════════════════════
# Jede Sprache bekommt ihren eigenen Moderator: eine Verwarnung, die niemand
# liest, ist keine. Still beim Kommen und Gehen — er steht in allen zehn Räumen,
# und ein Türsteher, der zweimal Hallo sagt, wirkt wie ein Fehler.
/bot create Wachtmeister Chef fuer Ordnung und Ruhe
/bot set Wachtmeister prefix !
/bot set Wachtmeister cooldown 1000
/bot set Wachtmeister mod_action warn
/bot set Wachtmeister mod_spam 5
/bot set Wachtmeister mod_flood 8
/bot set Wachtmeister mod_warn \c04\b[Wachtmeister]\o Immer langsam, {nickname}. \c05Bleib höflich\o, dann bleibt der Wachtmeister es auch.
/bot set Wachtmeister greeting none
/bot set Wachtmeister farewell none
/bot set Wachtmeister mention_response \c04\b[Wachtmeister]\o Ich schaue zu. \c05Immer\o. Benimm dich, dann kommen wir bestens klar.

/bot addcmd Wachtmeister regeln \c04\b[Wachtmeister]\o Kurzfassung: \c05sei kein Idiot\o. Langfassung: gibt es nicht.
/bot addcmd Wachtmeister melden \c04\b[Wachtmeister]\o Etwas Merkwürdiges gesehen? \c05Sag einem Admin Bescheid\o. Ich mache das Automatische, Menschen den Rest.

/bot join Wachtmeister #deutschland
/bot join Wachtmeister #nachrichten
/bot join Wachtmeister #dach
/bot join Wachtmeister #technik
/bot join Wachtmeister #netz
/bot join Wachtmeister #computer
/bot join Wachtmeister #wirtschaft
/bot join Wachtmeister #wissenschaft
/bot join Wachtmeister #sport
/bot join Wachtmeister #spiele

# ══════════════════════════════════════════════════════════
#  3. Fritzi — Gastgeberin in #deutschland
# ══════════════════════════════════════════════════════════
# Begrüßung als private Notice: Neuankömmlinge bekommen die Orientierung im
# Raum, ohne dass der Verlauf aller anderen vollläuft.
/bot create Fritzi Gastgeberin des deutschsprachigen Raums
/bot set Fritzi prefix !
/bot set Fritzi cooldown 1000
/bot set Fritzi dice_default 1d20
/bot set Fritzi greeting \c03\b[Fritzi]\o Servus {nickname}! Ich bin Fritzi. \c02Probier !raeume\o, !moin oder !englisch. Fühl dich wie zu Hause.
/bot set Fritzi greeting_delivery private_notice
/bot set Fritzi greeter_repeat_window 43200
/bot set Fritzi farewell none
/bot set Fritzi mention_response \c03\b[Fritzi]\o Gerufen? Bin da. \c02Probier !raeume\o.

/bot addcmd Fritzi raeume \c03\b[Fritzi]\o #deutschland #nachrichten #dach #technik #netz #computer #wirtschaft #wissenschaft #sport #spiele — \c02zehn Räume auf Deutsch\o, und in jedem passiert etwas.
/bot addcmd Fritzi moin \c03\b[Fritzi]\o \c02Moin\o, {nickname}. Kaffee läuft, Tastatur sauber, der Tag fängt an.
/bot addcmd Fritzi englisch \c03\b[Fritzi]\o Es gibt auch englische Räume, {nickname}: \c02#lobby, #tech, #news\o und mehr. Die Sprache stellst du in der Werkzeugleiste um.
/bot addcmd Fritzi umlaute \c03\b[Fritzi]\o Raumnamen haben keine Umlaute, {nickname} — \c02der Client verlinkt nur ASCII\o. Im Raum selbst schreibst du normal.

/bot join Fritzi #deutschland

# ══════════════════════════════════════════════════════════
#  4. Feed-Bots — einer pro Raum
# ══════════════════════════════════════════════════════════
# Jede Adresse hier unten wurde vom Produktions-Fetcher geholt und vom Parser
# der Anwendung gelesen, bevor sie hier stand. Der erste Abruf veröffentlicht
# die empfangene Seite und merkt sie sich; danach kommt nur noch Neues.

# ── Klaus — #deutschland ─────────────────────────────────
# Ohne Begrüßung: In diesem Raum empfängt Fritzi.
/bot create Klaus Reporter im Bereitschaftsdienst
/bot set Klaus prefix !
/bot set Klaus cooldown 1000
/bot set Klaus rss_interval 20
/bot set Klaus rss_max_items 10000
/bot set Klaus greeting none
/bot set Klaus farewell none
/bot set Klaus mention_response \c03\b[Klaus]\o Ich lese Tagesschau und Zeit. \c02!quellen\o zeigt die Feeds.
/bot addcmd Klaus quellen \c03\b[Klaus]\o Tagesschau und Die Zeit, \c02alle zwanzig Minuten\o abgerufen.
/bot join Klaus #deutschland
/bot rss add Klaus https://www.tagesschau.de/xml/rss2/ #deutschland
/bot rss add Klaus https://newsfeed.zeit.de/index #deutschland

# ── Greta — #nachrichten ─────────────────────────────────
/bot create Greta Leiterin des Nachrichtentisches
/bot set Greta prefix !
/bot set Greta cooldown 1000
/bot set Greta rss_interval 20
/bot set Greta rss_max_items 10000
/bot set Greta greeting \c02\b[Greta]\o Willkommen in #nachrichten, {nickname}. \c14Die Schlagzeilen kommen von allein\o — !quellen sagt woher.
/bot set Greta greeting_delivery private_notice
/bot set Greta greeter_repeat_window 43200
/bot set Greta farewell none
/bot set Greta mention_response \c02\b[Greta]\o Ich poste, was der Feed schickt. \c14!quellen\o für die Liste, !erster für den Rest.
/bot addcmd Greta quellen \c02\b[Greta]\o Spiegel, Süddeutsche, FAZ und Deutschlandfunk, \c14alle zwanzig Minuten\o abgerufen.
/bot addcmd Greta erster \c02\b[Greta]\o Der erste Abruf eines Feeds veröffentlicht die aktuelle Seite und merkt sie sich. Danach \c14kommt nur noch Neues\o.
/bot join Greta #nachrichten
/bot rss add Greta https://www.spiegel.de/schlagzeilen/tops/index.rss #nachrichten
/bot rss add Greta https://rss.sueddeutsche.de/rss/Topthemen #nachrichten
/bot rss add Greta https://www.faz.net/rss/aktuell/ #nachrichten
/bot rss add Greta https://www.deutschlandfunk.de/nachrichten-100.rss #nachrichten

# ── Heidi — #dach ────────────────────────────────────────
/bot create Heidi Korrespondentin aus Wien und Zuerich
/bot set Heidi prefix !
/bot set Heidi cooldown 1000
/bot set Heidi rss_interval 30
/bot set Heidi rss_max_items 10000
/bot set Heidi greeting \c10\b[Heidi]\o Grüß dich, {nickname}. \c06Der Standard und die NZZ\o landen hier von allein. !quellen für die Liste.
/bot set Heidi greeting_delivery private_notice
/bot set Heidi greeter_repeat_window 43200
/bot set Heidi farewell none
/bot set Heidi mention_response \c10\b[Heidi]\o Wien und Zürich, nicht Berlin. \c06!quellen\o zeigt die beiden Feeds.
/bot addcmd Heidi quellen \c10\b[Heidi]\o Der Standard und NZZ, \c06jede halbe Stunde\o abgerufen.
/bot join Heidi #dach
/bot rss add Heidi https://www.derstandard.at/rss #dach
/bot rss add Heidi https://www.nzz.ch/recent.rss #dach

# ── Werner — #technik ────────────────────────────────────
/bot create Werner Techniktisch mit Kaffeefleck
/bot set Werner prefix !
/bot set Werner cooldown 1000
/bot set Werner rss_interval 30
/bot set Werner rss_max_items 10000
/bot set Werner greeting \c12\b[Werner]\o Moin {nickname}. \c10heise und Golem\o kommen hier von allein. !quellen für die Liste, !support vor dem Fragen.
/bot set Werner greeting_delivery private_notice
/bot set Werner greeter_repeat_window 43200
/bot set Werner farewell none
/bot set Werner mention_response \c12\b[Werner]\o Zwei Technik-Feeds am Draht. \c10!quellen\o sagt welche.
/bot addcmd Werner quellen \c12\b[Werner]\o heise und Golem, \c10jede halbe Stunde\o abgerufen.
/bot addcmd Werner support \c12\b[Werner]\o Support für ein Projekt gehört zum Projekt, {nickname} — dort antworten die, die es bauen. \c10Hier ist die Kneipe\o.
/bot join Werner #technik
/bot rss add Werner https://www.heise.de/rss/heise-atom.xml #technik
/bot rss add Werner https://www.golem.de/rss.php?feed=RSS2.0 #technik

# ── Lotte — #netz ────────────────────────────────────────
/bot create Lotte Beobachterin der Netzpolitik
/bot set Lotte prefix !
/bot set Lotte cooldown 1000
/bot set Lotte rss_interval 45
/bot set Lotte rss_max_items 10000
/bot set Lotte greeting \c13\b[Lotte]\o Hallo {nickname}. \c11netzpolitik.org und t3n\o am Draht — !quellen für die Liste.
/bot set Lotte greeting_delivery private_notice
/bot set Lotte greeter_repeat_window 43200
/bot set Lotte farewell none
/bot set Lotte mention_response \c13\b[Lotte]\o Digitalpolitik und Plattformen. \c11!quellen\o zeigt den Draht.
/bot addcmd Lotte quellen \c13\b[Lotte]\o netzpolitik.org und t3n, \c11alle 45 Minuten\o abgerufen.
/bot join Lotte #netz
/bot rss add Lotte https://netzpolitik.org/feed/ #netz
/bot rss add Lotte https://t3n.de/rss.xml #netz

# ── Konrad — #computer ───────────────────────────────────
/bot create Konrad Schrauber am Gehaeuse
/bot set Konrad prefix !
/bot set Konrad cooldown 1000
/bot set Konrad rss_interval 60
/bot set Konrad rss_max_items 10000
/bot set Konrad greeting \c11\b[Konrad]\o Willkommen, {nickname}. \c14ComputerBase\o am Draht. !quellen für die Liste, !aufruesten bevor du kaufst.
/bot set Konrad greeting_delivery private_notice
/bot set Konrad greeter_repeat_window 43200
/bot set Konrad farewell none
/bot set Konrad mention_response \c11\b[Konrad]\o Hardware, Bauteile, Bastelei. \c14!quellen\o zeigt den Draht.
/bot addcmd Konrad quellen \c11\b[Konrad]\o ComputerBase, \c14stündlich\o abgerufen.
/bot addcmd Konrad aufruesten \c11\b[Konrad]\o Vor dem Aufrüsten \c14misst man den Engpass\o, {nickname}. Eine neue Grafikkarte wegen eines schlecht optimierten Spiels ist weggeworfenes Geld.
/bot join Konrad #computer
/bot rss add Konrad https://www.computerbase.de/rss/news.xml #computer

# ── Ilse — #wirtschaft ───────────────────────────────────
/bot create Ilse Beobachterin der Maerkte
/bot set Ilse prefix !
/bot set Ilse cooldown 1000
/bot set Ilse rss_interval 30
/bot set Ilse rss_max_items 10000
/bot set Ilse greeting \c07\b[Ilse]\o Hallo {nickname}. \c02Handelsblatt und WirtschaftsWoche\o am Draht — !quellen für die Liste, !hinweis vorm Glauben.
/bot set Ilse greeting_delivery private_notice
/bot set Ilse greeter_repeat_window 43200
/bot set Ilse farewell none
/bot set Ilse mention_response \c07\b[Ilse]\o Zwei Wirtschafts-Feeds. \c02!quellen\o sagt welche.
/bot addcmd Ilse quellen \c07\b[Ilse]\o Handelsblatt und WirtschaftsWoche, \c02jede halbe Stunde\o abgerufen.
/bot addcmd Ilse hinweis \c07\b[Ilse]\o Eine Schlagzeile ist keine Empfehlung, {nickname}. \c02Ich lese Feeds\o, keine Kristallkugel.
/bot join Ilse #wirtschaft
/bot rss add Ilse https://www.handelsblatt.com/contentexport/feed/schlagzeilen #wirtschaft
/bot rss add Ilse https://www.wiwo.de/contentexport/feed/rss/schlagzeilen #wirtschaft

# ── Otto — #wissenschaft ─────────────────────────────────
/bot create Otto Huter der Beobachtungen
/bot set Otto prefix !
/bot set Otto cooldown 1000
/bot set Otto rss_interval 60
/bot set Otto rss_max_items 10000
/bot set Otto greeting \c06\b[Otto]\o Willkommen, {nickname}. \c13Spektrum und wissenschaft.de\o kommen stündlich. !quellen für die Liste.
/bot set Otto greeting_delivery private_notice
/bot set Otto greeter_repeat_window 43200
/bot set Otto farewell none
/bot set Otto mention_response \c06\b[Otto]\o Wissenschaft ohne Bezahlschranke. \c13!quellen\o zeigt den Draht.
/bot addcmd Otto quellen \c06\b[Otto]\o Spektrum und wissenschaft.de, \c13stündlich\o abgerufen.
/bot join Otto #wissenschaft
/bot rss add Otto https://www.spektrum.de/alias/rss/spektrum-de-rss-feed/996406 #wissenschaft
/bot rss add Otto https://www.wissenschaft.de/feed/ #wissenschaft

# ── Uwe — #sport ─────────────────────────────────────────
/bot create Uwe Chronist von der Tribuene
/bot set Uwe prefix !
/bot set Uwe cooldown 1000
/bot set Uwe rss_interval 20
/bot set Uwe rss_max_items 10000
/bot set Uwe greeting \c09\b[Uwe]\o Servus {nickname}! \c03kicker und Sportschau\o am Draht. !quellen für die Liste, !verein wenn du drauf bestehst.
/bot set Uwe greeting_delivery private_notice
/bot set Uwe greeter_repeat_window 43200
/bot set Uwe farewell none
/bot set Uwe mention_response \c09\b[Uwe]\o Der Ball rollt. \c03!quellen\o sagt, was ich lese.
/bot addcmd Uwe quellen \c09\b[Uwe]\o kicker und Sportschau, \c03alle zwanzig Minuten\o abgerufen.
/bot addcmd Uwe verein \c09\b[Uwe]\o Meinen sage ich nicht, {nickname}. \c03Ein Bot mit Verein\o verliert beim ersten Derby den halben Raum.
/bot join Uwe #sport
/bot rss add Uwe https://newsfeed.kicker.de/news/aktuell #sport
/bot rss add Uwe https://www.sportschau.de/index~rss2.xml #sport

# ── Jonas — #spiele ──────────────────────────────────────
/bot create Jonas Betreiber der Spielhalle
/bot set Jonas prefix !
/bot set Jonas cooldown 1000
/bot set Jonas rss_interval 45
/bot set Jonas rss_max_items 10000
/bot set Jonas greeting \c12\b[Jonas]\o Rein mit dir, {nickname}! \c10Eurogamer.de\o am Draht, und das Menü Games öffnet 18 Klassiker im Browser. !quellen, !spielen.
/bot set Jonas greeting_delivery private_notice
/bot set Jonas greeter_repeat_window 43200
/bot set Jonas farewell none
/bot set Jonas mention_response \c12\b[Jonas]\o Spielenachrichten bringe ich. \c10!spielen\o erklärt, wie hier gespielt wird.
/bot addcmd Jonas quellen \c12\b[Jonas]\o Eurogamer.de, \c10alle 45 Minuten\o abgerufen.
/bot addcmd Jonas spielen \c12\b[Jonas]\o Oben im Menü \c10Games\o, {nickname}: DOOM, Quake, Wolfenstein und sechs ScummVM-Abenteuer, alles im Browser.
/bot join Jonas #spiele
/bot rss add Jonas https://www.eurogamer.de/feed #spiele
```

---

## Verification

```
/bot list
/bot info Wachtmeister
/admin channel list
```

`!Klaus rss list` in `#deutschland` shows what a bot actually stored — the check
that matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#deutschland` | **Fritzi**, Klaus | Tagesschau, Die Zeit |
| `#nachrichten` | **Greta** | Spiegel, SZ, FAZ, Deutschlandfunk |
| `#dach` | **Heidi** | Der Standard, NZZ |
| `#technik` | **Werner** | heise, Golem |
| `#netz` | **Lotte** | netzpolitik.org, t3n |
| `#computer` | **Konrad** | ComputerBase |
| `#wirtschaft` | **Ilse** | Handelsblatt, WirtschaftsWoche |
| `#wissenschaft` | **Otto** | Spektrum, wissenschaft.de |
| `#sport` | **Uwe** | kicker, Sportschau |
| `#spiele` | **Jonas** | Eurogamer.de |

**Wachtmeister** stands in all ten and greets in none of them. All channels are `+tn`.

Room names carry no umlauts: the client only linkifies `[a-zA-Z][a-zA-Z0-9_-]*`,
so `#räume` would be typed and never clickable. Everything inside a room is
written properly.
