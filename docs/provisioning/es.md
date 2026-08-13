# RetroHexChat — Spanish Rooms — `es`

Twelve channels, fourteen bots, twenty-five verified feeds. Documentation in
English for the operator; everything a user reads is in Spanish.

Spanish is the only language here that gets twelve rooms instead of ten, and the
reason is geography rather than size: `#noticias` and `#latinoamerica` carry
different newsrooms because a reader in Buenos Aires and a reader in Madrid do
not share a front page. Both feed into `#hispano`, which is the room where the
conversation actually happens.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Instalación es
#  12 canales · 14 bots · feeds verificados uno por uno
# ══════════════════════════════════════════════════════════

# ── 1. Canales ───────────────────────────────────────────

/join #hispano
/cs register
/topic Sala en español — de Madrid a Montevideo. Pasa, siéntate, aquí se charla.
/mode +tn

/join #noticias
/cs register
/topic Noticias de España — 20minutos, elDiario.es y El Mundo, directo del feed. !Elena fuentes para la lista.
/mode +tn

/join #latinoamerica
/cs register
/topic Latinoamérica — Clarín, La Nación e Infobae. La portada de allá, que no es la de aquí.
/mode +tn

/join #internacional
/cs register
/topic Internacional — BBC Mundo, ABC, El Confidencial y La Vanguardia. El mundo, en español.
/mode +tn

/join #tecno
/cs register
/topic Tecnología — Xataka, Genbeta, Hipertextual, Microsiervos y Applesfera. !Nacho fuentes para la lista.
/mode +tn

/join #videojuegos
/cs register
/topic Videojuegos — Vida Extra en el cable. Para jugar de verdad, abre el menú Games: 18 clásicos en el navegador.
/mode +tn

/join #deportes
/cs register
/topic Deportes — Marca y Mundo Deportivo. Liga, fichajes y la discusión de siempre.
/mode +tn

/join #cine
/cs register
/topic Cine y series — Espinof en el cable. Estrenos, temporadas y spoilers avisados.
/mode +tn

/join #divulgacion
/cs register
/topic Divulgación — Muy Interesante. Preguntas tontas no hay; hay preguntas sin hacer.
/mode +tn

/join #cocina
/cs register
/topic Cocina — Directo al Paladar. Recetas, técnica y discusiones sobre la tortilla.
/mode +tn

/join #motor
/cs register
/topic Motor — Motorpasión. Coches, motos y opiniones de quien va en metro.
/mode +tn

/join #mercados
/cs register
/topic Mercados — Expansión en el cable. Un titular no es una recomendación.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Cerbero — moderación, todos los canales
# ══════════════════════════════════════════════════════════
# Cada idioma trae su moderador: un aviso que nadie entiende no es un aviso.
# Callado al entrar y al salir — está en las doce salas, y un portero que
# saluda dos veces parece un fallo, no un personaje.
/bot create Cerbero Jefe de seguridad y paz en las salas
/bot set Cerbero prefix !
/bot set Cerbero cooldown 1000
/bot set Cerbero mod_action warn
/bot set Cerbero mod_spam 5
/bot set Cerbero mod_flood 8
/bot set Cerbero mod_warn \c04\b[Cerbero]\o Tranquilo, {nickname}. \c05Con respeto\o se está mejor, y yo tengo tres cabezas para recordarlo.
/bot set Cerbero greeting none
/bot set Cerbero farewell none
/bot set Cerbero mention_response \c04\b[Cerbero]\o Estoy mirando. \c05Siempre mirando\o. Pórtate bien y nos llevaremos de maravilla.

/bot addcmd Cerbero reglas \c04\b[Cerbero]\o Versión corta: \c05no seas idiota\o. Versión larga: no hay versión larga.
/bot addcmd Cerbero denuncia \c04\b[Cerbero]\o ¿Has visto algo raro? \c05Avisa a un admin\o. Yo llevo lo automático, las personas llevan el resto.

/bot join Cerbero #hispano
/bot join Cerbero #noticias
/bot join Cerbero #latinoamerica
/bot join Cerbero #internacional
/bot join Cerbero #tecno
/bot join Cerbero #videojuegos
/bot join Cerbero #deportes
/bot join Cerbero #cine
/bot join Cerbero #divulgacion
/bot join Cerbero #cocina
/bot join Cerbero #motor
/bot join Cerbero #mercados

# ══════════════════════════════════════════════════════════
#  3. Lucia — anfitriona de #hispano
# ══════════════════════════════════════════════════════════
# Bienvenida por notice privado: el recién llegado se orienta dentro de la sala
# sin llenar el historial de los demás.
/bot create Lucia Anfitriona de la sala en espanol
/bot set Lucia prefix !
/bot set Lucia cooldown 1000
/bot set Lucia dice_default 1d20
/bot set Lucia greeting \c03\b[Lucia]\o ¡Hola, {nickname}! Soy Lucia. \c02Prueba !salas\o, !buenosdias o !ingles. Estás en tu casa.
/bot set Lucia greeting_delivery private_notice
/bot set Lucia greeter_repeat_window 43200
/bot set Lucia farewell none
/bot set Lucia mention_response \c03\b[Lucia]\o ¿Me llamabas? Aquí estoy. \c02Prueba !salas\o.

/bot addcmd Lucia salas \c03\b[Lucia]\o #hispano #noticias #latinoamerica #internacional #tecno #videojuegos #deportes #cine #divulgacion #cocina #motor #mercados — \c02doce salas en español\o, y en todas pasa algo.
/bot addcmd Lucia buenosdias \c03\b[Lucia]\o \c02Buenos días\o, {nickname}. Café hecho, teclado limpio, el día empieza.
/bot addcmd Lucia ingles \c03\b[Lucia]\o También hay salas en inglés, {nickname}: \c02#lobby, #tech, #news\o y más. El idioma se cambia en la barra de herramientas.
/bot addcmd Lucia acentos \c03\b[Lucia]\o Los nombres de sala van sin acento ni ñ, {nickname} — \c02el cliente solo enlaza los que son ASCII\o. Dentro de la sala escribe como quieras.

/bot join Lucia #hispano

# ══════════════════════════════════════════════════════════
#  4. Bots de feed — uno por canal
# ══════════════════════════════════════════════════════════
# Cada dirección de aquí abajo se descargó con el fetcher de producción y la
# leyó el parser de la aplicación antes de escribirse. El primer sondeo publica
# la página que recibe y la registra; a partir de ahí solo sale lo nuevo.

# ── Paco — #hispano ──────────────────────────────────────
# Sin saludo: a los recién llegados los recibe Lucia.
/bot create Paco Reportero de guardia
/bot set Paco prefix !
/bot set Paco cooldown 1000
/bot set Paco rss_interval 20
/bot set Paco rss_max_items 10000
/bot set Paco greeting none
/bot set Paco farewell none
/bot set Paco mention_response \c03\b[Paco]\o Leo El País y RTVE. \c02!fuentes\o lista los feeds.
/bot addcmd Paco fuentes \c03\b[Paco]\o El País y RTVE, revisados \c02cada veinte minutos\o.
/bot join Paco #hispano
/bot rss add Paco https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada #hispano
/bot rss add Paco https://api2.rtve.es/rss/temas_noticias.xml #hispano

# ── Elena — #noticias ────────────────────────────────────
/bot create Elena Editora de la mesa nacional
/bot set Elena prefix !
/bot set Elena cooldown 1000
/bot set Elena rss_interval 20
/bot set Elena rss_max_items 10000
/bot set Elena greeting \c02\b[Elena]\o Bienvenido a #noticias, {nickname}. \c14Los titulares llegan solos\o — !fuentes dice de dónde.
/bot set Elena greeting_delivery private_notice
/bot set Elena greeter_repeat_window 43200
/bot set Elena farewell none
/bot set Elena mention_response \c02\b[Elena]\o Publico lo que manda el feed. \c14!fuentes\o para la lista, !primera para lo demás.
/bot addcmd Elena fuentes \c02\b[Elena]\o 20minutos, elDiario.es y El Mundo, revisados \c14cada veinte minutos\o.
/bot addcmd Elena primera \c02\b[Elena]\o La primera descarga de un feed publica la página actual y la registra. Después \c14solo sale lo nuevo\o.
/bot join Elena #noticias
/bot rss add Elena https://www.20minutos.es/rss/ #noticias
/bot rss add Elena https://www.eldiario.es/rss/ #noticias
/bot rss add Elena https://e00-elmundo.uecdn.es/elmundo/rss/portada.xml #noticias

# ── Diego — #latinoamerica ───────────────────────────────
/bot create Diego Corresponsal del cono sur
/bot set Diego prefix !
/bot set Diego cooldown 1000
/bot set Diego rss_interval 20
/bot set Diego rss_max_items 10000
/bot set Diego greeting \c07\b[Diego]\o Bienvenido, {nickname}. \c11Clarín, La Nación e Infobae\o caen acá solos. !fuentes para la lista.
/bot set Diego greeting_delivery private_notice
/bot set Diego greeter_repeat_window 43200
/bot set Diego farewell none
/bot set Diego mention_response \c07\b[Diego]\o Tres diarios del otro lado del charco. \c11!fuentes\o los lista.
/bot addcmd Diego fuentes \c07\b[Diego]\o Clarín, La Nación e Infobae, revisados \c11cada veinte minutos\o.
/bot join Diego #latinoamerica
/bot rss add Diego https://www.clarin.com/rss/lo-ultimo/ #latinoamerica
/bot rss add Diego https://www.lanacion.com.ar/arcio/rss/ #latinoamerica
/bot rss add Diego https://www.infobae.com/arc/outboundfeeds/rss/?outputType=xml #latinoamerica

# ── Marisol — #internacional ─────────────────────────────
/bot create Marisol Jefa de la mesa internacional
/bot set Marisol prefix !
/bot set Marisol cooldown 1000
/bot set Marisol rss_interval 30
/bot set Marisol rss_max_items 10000
/bot set Marisol greeting \c10\b[Marisol]\o Hola, {nickname}. \c06BBC Mundo, ABC, El Confidencial y La Vanguardia\o en el cable. !fuentes para la lista.
/bot set Marisol greeting_delivery private_notice
/bot set Marisol greeter_repeat_window 43200
/bot set Marisol farewell none
/bot set Marisol mention_response \c10\b[Marisol]\o El mundo, en español. \c06!fuentes\o lista los cuatro feeds.
/bot addcmd Marisol fuentes \c10\b[Marisol]\o BBC Mundo, ABC, El Confidencial y La Vanguardia, revisados \c06cada media hora\o.
/bot join Marisol #internacional
/bot rss add Marisol https://www.bbc.com/mundo/index.xml #internacional
/bot rss add Marisol https://www.abc.es/rss/2.0/portada/ #internacional
/bot rss add Marisol https://rss.elconfidencial.com/espana/ #internacional
/bot rss add Marisol https://www.lavanguardia.com/rss/home.xml #internacional

# ── Nacho — #tecno ───────────────────────────────────────
# Cinco feeds es el máximo por bot; este llega justo al tope.
/bot create Nacho Cacharreador profesional
/bot set Nacho prefix !
/bot set Nacho cooldown 1000
/bot set Nacho rss_interval 30
/bot set Nacho rss_max_feeds 5
/bot set Nacho rss_max_items 10000
/bot set Nacho greeting \c12\b[Nacho]\o ¡Hola, {nickname}! \c10Cinco feeds de tecnología\o caen aquí solos. !fuentes para la lista, !soporte antes de preguntar.
/bot set Nacho greeting_delivery private_notice
/bot set Nacho greeter_repeat_window 43200
/bot set Nacho farewell none
/bot set Nacho mention_response \c12\b[Nacho]\o Xataka, Genbeta, Hipertextual, Microsiervos y Applesfera. \c10!fuentes\o los lista.
/bot addcmd Nacho fuentes \c12\b[Nacho]\o Xataka, Genbeta, Hipertextual, Microsiervos y Applesfera, revisados \c10cada media hora\o.
/bot addcmd Nacho soporte \c12\b[Nacho]\o El soporte de un proyecto está en el proyecto, {nickname} — quien contesta bien es quien lo mantiene. \c10Esto es la barra\o.
/bot join Nacho #tecno
/bot rss add Nacho https://www.xataka.com/index.xml #tecno
/bot rss add Nacho https://www.genbeta.com/index.xml #tecno
/bot rss add Nacho https://hipertextual.com/feed #tecno
/bot rss add Nacho https://www.microsiervos.com/index.xml #tecno
/bot rss add Nacho https://www.applesfera.com/index.xml #tecno

# ── Rocio — #videojuegos ─────────────────────────────────
/bot create Rocio Operadora del salon recreativo
/bot set Rocio prefix !
/bot set Rocio cooldown 1000
/bot set Rocio rss_interval 45
/bot set Rocio rss_max_items 10000
/bot set Rocio greeting \c13\b[Rocio]\o ¡Dentro, {nickname}! \c06Vida Extra\o en el cable, y el menú Games abre 18 clásicos en el navegador. !fuentes, !jugar.
/bot set Rocio greeting_delivery private_notice
/bot set Rocio greeter_repeat_window 43200
/bot set Rocio farewell none
/bot set Rocio mention_response \c13\b[Rocio]\o Noticias de juegos las traigo yo. \c06!jugar\o explica cómo se juega aquí mismo.
/bot addcmd Rocio fuentes \c13\b[Rocio]\o Vida Extra, revisado \c06cada 45 minutos\o.
/bot addcmd Rocio jugar \c13\b[Rocio]\o Abre el menú \c06Games\o de la barra superior, {nickname}: DOOM, Quake, Wolfenstein y seis aventuras ScummVM, todo en el navegador.
/bot join Rocio #videojuegos
/bot rss add Rocio https://www.vidaextra.com/index.xml #videojuegos

# ── Ramon — #deportes ────────────────────────────────────
/bot create Ramon Cronista de grada
/bot set Ramon prefix !
/bot set Ramon cooldown 1000
/bot set Ramon rss_interval 20
/bot set Ramon rss_max_items 10000
/bot set Ramon greeting \c09\b[Ramon]\o ¡Buenas, {nickname}! \c03Marca y Mundo Deportivo\o en el cable. !fuentes para la lista, !equipo si insistes.
/bot set Ramon greeting_delivery private_notice
/bot set Ramon greeter_repeat_window 43200
/bot set Ramon farewell none
/bot set Ramon mention_response \c09\b[Ramon]\o Balón rodando. \c03!fuentes\o dice qué leo.
/bot addcmd Ramon fuentes \c09\b[Ramon]\o Marca y Mundo Deportivo, revisados \c03cada veinte minutos\o.
/bot addcmd Ramon equipo \c09\b[Ramon]\o No digo el mío, {nickname}. \c03Un bot con equipo\o pierde media sala en el primer derbi.
/bot join Ramon #deportes
/bot rss add Ramon https://www.marca.com/rss/portada.xml #deportes
/bot rss add Ramon https://www.mundodeportivo.com/feed/rss/home #deportes

# ── Carmen — #cine ───────────────────────────────────────
/bot create Carmen Acomodadora de la sala oscura
/bot set Carmen prefix !
/bot set Carmen cooldown 1000
/bot set Carmen rss_interval 60
/bot set Carmen rss_max_items 10000
/bot set Carmen greeting \c06\b[Carmen]\o Pasa, {nickname}. \c13Espinof\o en el cable — estrenos, series y temporadas. !fuentes para la lista.
/bot set Carmen greeting_delivery private_notice
/bot set Carmen greeter_repeat_window 43200
/bot set Carmen farewell none
/bot set Carmen mention_response \c06\b[Carmen]\o Cine y series. \c13!fuentes\o dice de dónde.
/bot addcmd Carmen fuentes \c06\b[Carmen]\o Espinof, revisado \c13cada hora\o.
/bot join Carmen #cine
/bot rss add Carmen https://www.espinof.com/index.xml #cine

# ── Teresa — #divulgacion ────────────────────────────────
/bot create Teresa Divulgadora de guardia
/bot set Teresa prefix !
/bot set Teresa cooldown 1000
/bot set Teresa rss_interval 60
/bot set Teresa rss_max_items 10000
/bot set Teresa greeting \c11\b[Teresa]\o Hola, {nickname}. \c02Muy Interesante\o llega cada hora. !fuentes para la lista.
/bot set Teresa greeting_delivery private_notice
/bot set Teresa greeter_repeat_window 43200
/bot set Teresa farewell none
/bot set Teresa mention_response \c11\b[Teresa]\o Divulgación sin muro de pago. \c02!fuentes\o lista el cable.
/bot addcmd Teresa fuentes \c11\b[Teresa]\o Muy Interesante, revisado \c02cada hora\o.
/bot join Teresa #divulgacion
/bot rss add Teresa https://www.muyinteresante.es/feed/ #divulgacion

# ── Pepa — #cocina ───────────────────────────────────────
/bot create Pepa Jefa de cocina del canal
/bot set Pepa prefix !
/bot set Pepa cooldown 1000
/bot set Pepa rss_interval 90
/bot set Pepa rss_max_items 10000
/bot set Pepa greeting \c05\b[Pepa]\o Adelante, {nickname}. \c08Directo al Paladar\o en el cable. !fuentes para la lista, !tortilla bajo tu responsabilidad.
/bot set Pepa greeting_delivery private_notice
/bot set Pepa greeter_repeat_window 43200
/bot set Pepa farewell none
/bot set Pepa mention_response \c05\b[Pepa]\o Recetas y técnica. \c08!fuentes\o dice de dónde salen.
/bot addcmd Pepa fuentes \c05\b[Pepa]\o Directo al Paladar, revisado \c08cada hora y media\o.
/bot addcmd Pepa tortilla \c05\b[Pepa]\o Con cebolla, {nickname}. \c08Y ya está\o.
/bot join Pepa #cocina
/bot rss add Pepa https://www.directoalpaladar.com/index.xml #cocina

# ── Manolo — #motor ──────────────────────────────────────
/bot create Manolo Mecanico de guardia
/bot set Manolo prefix !
/bot set Manolo cooldown 1000
/bot set Manolo rss_interval 90
/bot set Manolo rss_max_items 10000
/bot set Manolo greeting \c14\b[Manolo]\o Buenas, {nickname}. \c04Motorpasión\o en el cable. !fuentes para la lista.
/bot set Manolo greeting_delivery private_notice
/bot set Manolo greeter_repeat_window 43200
/bot set Manolo farewell none
/bot set Manolo mention_response \c14\b[Manolo]\o Coches, motos y averías. \c04!fuentes\o lista el cable.
/bot addcmd Manolo fuentes \c14\b[Manolo]\o Motorpasión, revisado \c04cada hora y media\o.
/bot join Manolo #motor
/bot rss add Manolo https://www.motorpasion.com/index.xml #motor

# ── Alonso — #mercados ───────────────────────────────────
/bot create Alonso Observador de los mercados
/bot set Alonso prefix !
/bot set Alonso cooldown 1000
/bot set Alonso rss_interval 30
/bot set Alonso rss_max_items 10000
/bot set Alonso greeting \c07\b[Alonso]\o Hola, {nickname}. \c14Expansión\o en el cable — !fuentes para la lista, !aviso antes de creerte nada.
/bot set Alonso greeting_delivery private_notice
/bot set Alonso greeter_repeat_window 43200
/bot set Alonso farewell none
/bot set Alonso mention_response \c07\b[Alonso]\o Leo Expansión. \c14!fuentes\o para la lista.
/bot addcmd Alonso fuentes \c07\b[Alonso]\o Expansión, revisado \c14cada media hora\o.
/bot addcmd Alonso aviso \c07\b[Alonso]\o Un titular no es una recomendación, {nickname}. \c14Yo leo feeds\o, no bolas de cristal.
/bot join Alonso #mercados
/bot rss add Alonso https://www.expansion.com/rss/portada.xml #mercados
```

---

## Verification

```
/bot list
/bot info Cerbero
/bot info Nacho
/admin channel list
```

`!Nacho rss list` is the one worth checking: it is the only bot at the five-feed
ceiling, so a sixth address silently refused would show up there first.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#hispano` | **Lucia**, Paco | El País, RTVE |
| `#noticias` | **Elena** | 20minutos, elDiario.es, El Mundo |
| `#latinoamerica` | **Diego** | Clarín, La Nación, Infobae |
| `#internacional` | **Marisol** | BBC Mundo, ABC, El Confidencial, La Vanguardia |
| `#tecno` | **Nacho** | Xataka, Genbeta, Hipertextual, Microsiervos, Applesfera |
| `#videojuegos` | **Rocio** | Vida Extra |
| `#deportes` | **Ramon** | Marca, Mundo Deportivo |
| `#cine` | **Carmen** | Espinof |
| `#divulgacion` | **Teresa** | Muy Interesante |
| `#cocina` | **Pepa** | Directo al Paladar |
| `#motor` | **Manolo** | Motorpasión |
| `#mercados` | **Alonso** | Expansión |

**Cerbero** stands in all twelve and greets in none of them. All channels are `+tn`.

Channel names carry no accents and no `ñ`: the client only turns `#ordenadores`
into a link when it matches `[a-zA-Z][a-zA-Z0-9_-]*`. Inside a room, nothing is
restricted — topics, greetings and messages are written properly.
