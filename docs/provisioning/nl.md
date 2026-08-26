# RetroHexChat — Dutch Rooms — `nl`

Ten channels, twelve bots, twenty-one verified feeds. Documentation in English
for the operator; everything a user reads is in Dutch.

`#vlaanderen` exists for the same reason `#dach` does in German: VRT, De Morgen
and HLN are a different country's front page, and mixing them into `#nieuws`
serves neither side. `#beveiliging` is the odd one out — Security.NL has no
equivalent in any other language here, and a security wire in your own language
is worth a room even on one feed.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Installatie nl
#  10 kanalen · 12 bots · feeds stuk voor stuk gecontroleerd
# ══════════════════════════════════════════════════════════

# ── 1. Kanalen ───────────────────────────────────────────

/join #nederland
/cs register
/topic Nederlandstalig kanaal — kom binnen, ga zitten, er wordt gepraat. Koffie van het huis.
/mode +tn

/join #nieuws
/cs register
/topic Nieuws — AD, Volkskrant en Trouw, rechtstreeks uit de feed. !Sanne bronnen toont de lijst.
/mode +tn

/join #vlaanderen
/cs register
/topic Vlaanderen — VRT NWS, De Morgen en HLN. Andere voorpagina, zelfde taal.
/mode +tn

/join #achtergrond
/cs register
/topic Achtergrond — NRC, Het Parool en RTL Nieuws. Het verhaal achter de kop.
/mode +tn

/join #techniek
/cs register
/topic Techniek — Tweakers en Bright. Support voor een project hoort bij het project; hier wordt gepraat.
/mode +tn

/join #beveiliging
/cs register
/topic Beveiliging — Security.NL aan de lijn. Lezen voordat je patcht, niet erna.
/mode +tn

/join #voetbal
/cs register
/topic Voetbal — VI, VoetbalPrimeur en HLN Sport. Stand, transfers en het gebruikelijke gelijk.
/mode +tn

/join #wetenschap
/cs register
/topic Wetenschap — Scientias en New Scientist. Domme vragen bestaan niet, ongestelde wel.
/mode +tn

/join #ondernemen
/cs register
/topic Ondernemen — Emerce aan de lijn. Een kop is geen advies.
/mode +tn

/join #auto
/cs register
/topic Auto — Autoblog aan de lijn. Rijden, sleutelen en meningen van wie de trein neemt.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Poortwachter — moderatie, alle kanalen
# ══════════════════════════════════════════════════════════
# Elke taal krijgt zijn eigen moderator: een waarschuwing die niemand leest is
# er geen. Stil bij binnenkomst en vertrek — hij staat in alle tien de kanalen,
# en een uitsmijter die twee keer hallo zegt lijkt een storing.
/bot create Poortwachter Chef rust en fatsoen
/bot set Poortwachter prefix !
/bot set Poortwachter cooldown 1000
/bot set Poortwachter mod_action warn
/bot set Poortwachter mod_spam 5
/bot set Poortwachter mod_flood 8
/bot set Poortwachter mod_warn \c04\b[Poortwachter]\o Rustig aan, {nickname}. \c05Blijf beleefd\o, dan blijf ik dat ook.
/bot set Poortwachter greeting none
/bot set Poortwachter farewell none
/bot set Poortwachter mention_response \c04\b[Poortwachter]\o Ik kijk mee. \c05Altijd\o. Gedraag je en het komt helemaal goed.

/bot addcmd Poortwachter regels \c04\b[Poortwachter]\o Korte versie: \c05doe niet vervelend\o. Lange versie: die is er niet.
/bot addcmd Poortwachter melden \c04\b[Poortwachter]\o Iets raars gezien? \c05Waarschuw een admin\o. Ik doe het automatische werk, mensen de rest.

/bot join Poortwachter #nederland
/bot join Poortwachter #nieuws
/bot join Poortwachter #vlaanderen
/bot join Poortwachter #achtergrond
/bot join Poortwachter #techniek
/bot join Poortwachter #beveiliging
/bot join Poortwachter #voetbal
/bot join Poortwachter #wetenschap
/bot join Poortwachter #ondernemen
/bot join Poortwachter #auto

# ══════════════════════════════════════════════════════════
#  3. Fenna — gastvrouw in #nederland
# ══════════════════════════════════════════════════════════
# Welkom als privé-notice: wie binnenkomt krijgt de weg gewezen in het kanaal,
# zonder de geschiedenis van alle anderen vol te zetten.
/bot create Fenna Gastvrouw van het Nederlandstalige kanaal
/bot set Fenna prefix !
/bot set Fenna cooldown 1000
/bot set Fenna dice_default 1d20
/bot set Fenna greeting \c03\b[Fenna]\o Hoi {nickname}! Ik ben Fenna. \c02Probeer !kanalen\o, !goedemorgen of !engels. Doe alsof je thuis bent.
/bot set Fenna greeting_delivery private_notice
/bot set Fenna greeter_repeat_window 43200
/bot set Fenna public_greeting \c03\b[Fenna]\o \b{nickname}\o is net binnengekomen. Ga zitten.
/bot set Fenna onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Fenna onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Fenna farewell none
/bot set Fenna mention_response \c03\b[Fenna]\o Geroepen? Ik ben er. \c02Probeer !kanalen\o.

/bot addcmd Fenna kanalen \c03\b[Fenna]\o #nederland #nieuws #vlaanderen #achtergrond #techniek #beveiliging #voetbal #wetenschap #ondernemen #auto — \c02tien Nederlandstalige kanalen\o, en in elk gebeurt iets.
/bot addcmd Fenna goedemorgen \c03\b[Fenna]\o \c02Goedemorgen\o, {nickname}. Koffie gezet, toetsenbord schoon, de dag begint.
/bot addcmd Fenna engels \c03\b[Fenna]\o Er zijn ook Engelstalige kanalen, {nickname}: \c02#lobby, #tech, #news\o en meer. De taal wissel je in de werkbalk.
/bot addcmd Fenna belgie \c03\b[Fenna]\o Vlaanderen heeft een eigen kanaal, {nickname}: \c02#vlaanderen\o. Andere voorpagina, zelfde taal — daarom apart.

/bot join Fenna #nederland

# ══════════════════════════════════════════════════════════
#  4. Feed-bots — één per kanaal
# ══════════════════════════════════════════════════════════
# Elk adres hieronder is opgehaald met de productie-fetcher en gelezen door de
# parser van de applicatie voordat het hier stond. De eerste ronde publiceert
# de ontvangen pagina en onthoudt die; daarna komt alleen wat nieuw is.
#
# Een eerste ronde komt in porties, niet in één keer: de floodbescherming zit in
# de sessie van elke lezer en negeert automatisch wie eroverheen gaat. Er gaat
# niets verloren — een feed met achterstand komt binnen een minuut terug.

# ── Joop — #nederland ────────────────────────────────────
# Zonder welkom: in dit kanaal ontvangt Fenna.
/bot create Joop Verslaggever van dienst
/bot set Joop prefix !
/bot set Joop cooldown 1000
/bot set Joop rss_interval 20
/bot set Joop greeting none
/bot set Joop farewell none
/bot set Joop mention_response \c03\b[Joop]\o Ik lees NOS en NU.nl. \c02!bronnen\o toont de feeds.
/bot addcmd Joop bronnen \c03\b[Joop]\o NOS en NU.nl, \c02elke twintig minuten\o opgehaald.
/bot join Joop #nederland
/bot rss add Joop https://feeds.nos.nl/nosnieuwsalgemeen #nederland
/bot rss add Joop https://www.nu.nl/rss #nederland

# ── Sanne — #nieuws ──────────────────────────────────────
/bot create Sanne Chef van de nieuwsdesk
/bot set Sanne prefix !
/bot set Sanne cooldown 1000
/bot set Sanne rss_interval 20
/bot set Sanne greeting \c02\b[Sanne]\o Welkom in #nieuws, {nickname}. \c14De koppen komen vanzelf\o — !bronnen zegt waarvandaan.
/bot set Sanne greeting_delivery private_notice
/bot set Sanne greeter_repeat_window 43200
/bot set Sanne public_greeting \c02\b[Sanne]\o \b{nickname}\o komt de redactie binnen.
/bot set Sanne onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Sanne onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Sanne farewell none
/bot set Sanne mention_response \c02\b[Sanne]\o Ik plaats wat de feed stuurt. \c14!bronnen\o voor de lijst, !eerste voor de rest.
/bot addcmd Sanne bronnen \c02\b[Sanne]\o AD, de Volkskrant en Trouw, \c14elke twintig minuten\o opgehaald.
/bot addcmd Sanne eerste \c02\b[Sanne]\o De eerste ronde van een feed plaatst de huidige pagina en onthoudt die. Daarna \c14komt alleen het nieuwe\o.
/bot join Sanne #nieuws
/bot rss add Sanne https://www.ad.nl/rss.xml #nieuws
/bot rss add Sanne https://www.volkskrant.nl/voorpagina/rss.xml #nieuws
/bot rss add Sanne https://www.trouw.nl/rss.xml #nieuws

# ── Wout — #vlaanderen ───────────────────────────────────
/bot create Wout Correspondent in Brussel
/bot set Wout prefix !
/bot set Wout cooldown 1000
/bot set Wout rss_interval 20
/bot set Wout greeting \c07\b[Wout]\o Welkom, {nickname}. \c11VRT NWS, De Morgen en HLN\o landen hier vanzelf. !bronnen voor de lijst.
/bot set Wout greeting_delivery private_notice
/bot set Wout greeter_repeat_window 43200
/bot set Wout public_greeting \c07\b[Wout]\o \b{nickname}\o is er. Welkom.
/bot set Wout onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Wout onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Wout farewell none
/bot set Wout mention_response \c07\b[Wout]\o Vlaanderen, niet Nederland. \c11!bronnen\o toont de drie feeds.
/bot addcmd Wout bronnen \c07\b[Wout]\o VRT NWS, De Morgen en Het Laatste Nieuws, \c11elke twintig minuten\o opgehaald.
/bot join Wout #vlaanderen
/bot rss add Wout https://www.vrt.be/vrtnws/nl.rss.articles.xml #vlaanderen
/bot rss add Wout https://www.demorgen.be/rss.xml #vlaanderen
/bot rss add Wout https://www.hln.be/rss.xml #vlaanderen

# ── Bram — #achtergrond ──────────────────────────────────
/bot create Bram Lezer van lange stukken
/bot set Bram prefix !
/bot set Bram cooldown 1000
/bot set Bram rss_interval 30
/bot set Bram greeting \c10\b[Bram]\o Hallo {nickname}. \c06NRC, Het Parool en RTL Nieuws\o komen hier binnen. !bronnen voor de lijst.
/bot set Bram greeting_delivery private_notice
/bot set Bram greeter_repeat_window 43200
/bot set Bram public_greeting \c10\b[Bram]\o \b{nickname}\o sluit aan.
/bot set Bram onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Bram onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Bram farewell none
/bot set Bram mention_response \c10\b[Bram]\o Het verhaal achter de kop. \c06!bronnen\o toont de lijn.
/bot addcmd Bram bronnen \c10\b[Bram]\o NRC, Het Parool en RTL Nieuws, \c06elk half uur\o opgehaald.
/bot join Bram #achtergrond
/bot rss add Bram https://www.nrc.nl/rss/ #achtergrond
/bot rss add Bram https://www.parool.nl/rss.xml #achtergrond
/bot rss add Bram https://www.rtlnieuws.nl/rss.xml #achtergrond

# ── Tijs — #techniek ─────────────────────────────────────
/bot create Tijs Vaste klant van de techniekhoek
/bot set Tijs prefix !
/bot set Tijs cooldown 1000
/bot set Tijs rss_interval 30
/bot set Tijs greeting \c12\b[Tijs]\o Hoi {nickname}. \c10Tweakers en Bright\o vallen hier binnen. !bronnen voor de lijst, !support voor je iets vraagt.
/bot set Tijs greeting_delivery private_notice
/bot set Tijs greeter_repeat_window 43200
/bot set Tijs public_greeting \c12\b[Tijs]\o \b{nickname}\o is binnen. Welkom.
/bot set Tijs onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Tijs onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Tijs farewell none
/bot set Tijs mention_response \c12\b[Tijs]\o Twee techniekfeeds aan de lijn. \c10!bronnen\o zegt welke.
/bot addcmd Tijs bronnen \c12\b[Tijs]\o Tweakers en Bright, \c10elk half uur\o opgehaald.
/bot addcmd Tijs support \c12\b[Tijs]\o Support voor een project hoort bij dat project, {nickname} — daar antwoorden de mensen die het bouwen. \c10Hier is het café\o.
/bot join Tijs #techniek
/bot rss add Tijs https://tweakers.net/feeds/mixed.xml #techniek
/bot rss add Tijs https://www.bright.nl/rss #techniek

# ── Marijke — #beveiliging ───────────────────────────────
/bot create Marijke Draagster van adviezen die niemand op tijd leest
/bot set Marijke prefix !
/bot set Marijke cooldown 1000
/bot set Marijke rss_interval 30
/bot set Marijke greeting \c04\b[Marijke]\o {nickname}, welkom. \c05Security.NL\o aan de lijn. Je leest het later alsnog, dus lees het nu. !bronnen, !patch.
/bot set Marijke greeting_delivery private_notice
/bot set Marijke greeter_repeat_window 43200
/bot set Marijke public_greeting \c04\b[Marijke]\o \b{nickname}\o is er. Lees de adviezen.
/bot set Marijke onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Marijke onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Marijke farewell none
/bot set Marijke mention_response \c04\b[Marijke]\o Ik waarschuw; dat is het hele werk. \c05!bronnen\o zegt waarvandaan.
/bot addcmd Marijke bronnen \c04\b[Marijke]\o Security.NL, \c05elk half uur\o opgehaald.
/bot addcmd Marijke patch \c04\b[Marijke]\o Een advies is niet de oplossing. \c05Lees het, zoek je versie, patch dan\o. In die volgorde, {nickname}.
/bot join Marijke #beveiliging
/bot rss add Marijke https://www.security.nl/rss/headlines.xml #beveiliging

# ── Johan — #voetbal ─────────────────────────────────────
/bot create Johan Chroniqueur op de tribune
/bot set Johan prefix !
/bot set Johan cooldown 1000
/bot set Johan rss_interval 20
/bot set Johan greeting \c09\b[Johan]\o Hoi {nickname}! \c03VI, VoetbalPrimeur en HLN Sport\o aan de lijn. !bronnen voor de lijst, !club als je aandringt.
/bot set Johan greeting_delivery private_notice
/bot set Johan greeter_repeat_window 43200
/bot set Johan public_greeting \c09\b[Johan]\o \b{nickname}\o komt het veld op.
/bot set Johan onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Johan onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Johan farewell none
/bot set Johan mention_response \c09\b[Johan]\o De bal rolt. \c03!bronnen\o zegt wat ik lees.
/bot addcmd Johan bronnen \c09\b[Johan]\o Voetbal International, VoetbalPrimeur en HLN Sport, \c03elke twintig minuten\o opgehaald.
/bot addcmd Johan club \c09\b[Johan]\o De mijne zeg ik niet, {nickname}. \c03Een bot met een club\o is de halve zaal kwijt bij de eerste derby.
/bot join Johan #voetbal
/bot rss add Johan https://www.vi.nl/rss #voetbal
/bot rss add Johan https://www.voetbalprimeur.nl/rss.xml #voetbal
/bot rss add Johan https://www.hln.be/sport/rss.xml #voetbal

# ── Lieke — #wetenschap ──────────────────────────────────
/bot create Lieke Hoedster van de waarnemingen
/bot set Lieke prefix !
/bot set Lieke cooldown 1000
/bot set Lieke rss_interval 60
/bot set Lieke greeting \c06\b[Lieke]\o Welkom, {nickname}. \c13Scientias en New Scientist\o komen elk uur langs. !bronnen voor de lijst.
/bot set Lieke greeting_delivery private_notice
/bot set Lieke greeter_repeat_window 43200
/bot set Lieke public_greeting \c06\b[Lieke]\o \b{nickname}\o sluit aan. Welkom.
/bot set Lieke onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Lieke onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Lieke farewell none
/bot set Lieke mention_response \c06\b[Lieke]\o Wetenschap zonder betaalmuur. \c13!bronnen\o toont de lijn.
/bot addcmd Lieke bronnen \c06\b[Lieke]\o Scientias en New Scientist NL, \c13elk uur\o opgehaald.
/bot join Lieke #wetenschap
/bot rss add Lieke https://www.scientias.nl/feed/ #wetenschap
/bot rss add Lieke https://www.newscientist.nl/feed/ #wetenschap

# ── Daan — #ondernemen ───────────────────────────────────
/bot create Daan Volger van de handel
/bot set Daan prefix !
/bot set Daan cooldown 1000
/bot set Daan rss_interval 45
/bot set Daan greeting \c07\b[Daan]\o Hallo {nickname}. \c14Emerce\o aan de lijn — !bronnen voor de lijst, !waarschuwing voor je iets gelooft.
/bot set Daan greeting_delivery private_notice
/bot set Daan greeter_repeat_window 43200
/bot set Daan public_greeting \c07\b[Daan]\o \b{nickname}\o is er. Welkom.
/bot set Daan onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Daan onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Daan farewell none
/bot set Daan mention_response \c07\b[Daan]\o Ik lees Emerce. \c14!bronnen\o voor de lijst.
/bot addcmd Daan bronnen \c07\b[Daan]\o Emerce, \c14elke 45 minuten\o opgehaald.
/bot addcmd Daan waarschuwing \c07\b[Daan]\o Een kop is geen advies, {nickname}. \c14Ik lees feeds\o, geen glazen bol.
/bot join Daan #ondernemen
/bot rss add Daan https://www.emerce.nl/rss #ondernemen

# ── Kees — #auto ─────────────────────────────────────────
/bot create Kees Sleutelaar van dienst
/bot set Kees prefix !
/bot set Kees cooldown 1000
/bot set Kees rss_interval 90
/bot set Kees greeting \c11\b[Kees]\o Kom erin, {nickname}. \c04Autoblog\o aan de lijn. !bronnen voor de lijst.
/bot set Kees greeting_delivery private_notice
/bot set Kees greeter_repeat_window 43200
/bot set Kees public_greeting \c11\b[Kees]\o \b{nickname}\o rijdt binnen.
/bot set Kees onboarding_1 \c14\b[{botname}]\o \c10/join #nederland\o gaat een kamer binnen · \c10/msg nick\o praat privé · \c10/nick naam\o verandert de jouwe.
/bot set Kees onboarding_2 \c14\b[{botname}]\o \c10/part\o verlaat een kamer · \c10/help\o toont alle opdrachten.
/bot set Kees farewell none
/bot set Kees mention_response \c11\b[Kees]\o Rijden en sleutelen. \c04!bronnen\o toont de lijn.
/bot addcmd Kees bronnen \c11\b[Kees]\o Autoblog, \c04elk anderhalf uur\o opgehaald.
/bot join Kees #auto
/bot rss add Kees https://www.autoblog.nl/feed #auto
```

---

## Verification

```
/bot list
/bot info Poortwachter
/admin channel list
```

`!Joop rss list` in `#nederland` shows what a bot actually stored — the check
that matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#nederland` | **Fenna**, Joop | NOS, NU.nl |
| `#nieuws` | **Sanne** | AD, Volkskrant, Trouw |
| `#vlaanderen` | **Wout** | VRT NWS, De Morgen, HLN |
| `#achtergrond` | **Bram** | NRC, Het Parool, RTL Nieuws |
| `#techniek` | **Tijs** | Tweakers, Bright |
| `#beveiliging` | **Marijke** | Security.NL |
| `#voetbal` | **Johan** | VI, VoetbalPrimeur, HLN Sport |
| `#wetenschap` | **Lieke** | Scientias, New Scientist NL |
| `#ondernemen` | **Daan** | Emerce |
| `#auto` | **Kees** | Autoblog |

**Poortwachter** stands in all ten and greets in none of them. All channels are `+tn`.
