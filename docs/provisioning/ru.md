# RetroHexChat — Russian Rooms — `ru`

Ten channels, twelve bots, twenty-one verified feeds. Documentation in English
for the operator; everything a user reads is in Russian.

Room names are transliterated rather than translated — `#novosti`, `#zhelezo`,
`#nauchpop`. The client only turns ASCII channel mentions into links, and a Russian
speaker types `zhelezo` far more readily than `hardware`. It is also what the
Russian-speaking corner of IRC has always done.

`#zhelezo` — literally "iron" — is the room the English script has no name for:
iXBT and Overclockers are a hardware press with no English counterpart at that
volume.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Установка ru
#  10 каналов · 12 ботов · ленты проверены по одной
# ══════════════════════════════════════════════════════════

# ── 1. Каналы ────────────────────────────────────────────

/join #russkiy
/cs register
/topic Русскоязычный канал — заходи, садись, разговариваем. Кофе за счёт заведения.
/mode +tn

/join #novosti
/cs register
/topic Новости — ТАСС, «Интерфакс», «Коммерсантъ» и «Медуза», прямо из лент. !Grisha istochniki покажет список.
/mode +tn

/join #tehnologii
/cs register
/topic Технологии — 3DNews и CNews. Поддержка проекта живёт у проекта; здесь просто разговор.
/mode +tn

/join #zhelezo
/cs register
/topic Железо — iXBT и Overclockers. Платы, корпуса, разгон и то, что из этого выходит.
/mode +tn

/join #razrabotka
/cs register
/topic Разработка — «Хабр» и «Код». Байки, разборы и чужие коммиты.
/mode +tn

/join #opensource
/cs register
/topic Открытый код — OpenNET на проводе. Релизы, ядра, дистрибутивы.
/mode +tn

/join #igry
/cs register
/topic Игры — DTF и StopGame. А поиграть по-настоящему — меню Games: 18 классических игр прямо в браузере.
/mode +tn

/join #nauchpop
/cs register
/topic Научпоп — N+1, «Элементы» и Naked Science. Глупых вопросов не бывает, бывают незаданные.
/mode +tn

/join #ekonomika
/cs register
/topic Экономика — РБК и vc.ru. Заголовок — это не рекомендация.
/mode +tn

/join #futbol
/cs register
/topic Футбол — «Чемпионат» на проводе. Таблица, трансферы и обычный спор.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Storozh — модерация, все каналы
# ══════════════════════════════════════════════════════════
# У каждого языка свой модератор: предупреждение, которое не читают, — не
# предупреждение. Молчит на входе и выходе — он стоит во всех десяти каналах, а
# вышибала, здоровающийся дважды, выглядит как сбой.
/bot create Storozh Nachalnik tishiny i vezhlivosti
/bot set Storozh prefix !
/bot set Storozh cooldown 1000
/bot set Storozh mod_action warn
/bot set Storozh mod_spam 5
/bot set Storozh mod_flood 8
/bot set Storozh mod_warn \c04\b[Storozh]\o Полегче, {nickname}. \c05Вежливо\o — приятнее, а времени у меня много.
/bot set Storozh greeting none
/bot set Storozh farewell none
/bot set Storozh mention_response \c04\b[Storozh]\o Смотрю. \c05Всегда смотрю\o. Веди себя прилично — и всё будет хорошо.

/bot addcmd Storozh pravila \c04\b[Storozh]\o Коротко: \c05не будь придурком\o. Длинной версии нет.
/bot addcmd Storozh zhaloba \c04\b[Storozh]\o Увидел странное? \c05Напиши админу\o. Я делаю автоматику, люди — остальное.

/bot join Storozh #russkiy
/bot join Storozh #novosti
/bot join Storozh #tehnologii
/bot join Storozh #zhelezo
/bot join Storozh #razrabotka
/bot join Storozh #opensource
/bot join Storozh #igry
/bot join Storozh #nauchpop
/bot join Storozh #ekonomika
/bot join Storozh #futbol

# ══════════════════════════════════════════════════════════
#  3. Alyona — хозяйка #russkiy
# ══════════════════════════════════════════════════════════
# Приветствие приватным notice: новичок получает подсказки внутри канала, не
# засоряя историю остальным.
/bot create Alyona Hozyayka russkogo kanala
/bot set Alyona prefix !
/bot set Alyona cooldown 1000
/bot set Alyona dice_default 1d20
/bot set Alyona greeting \c03\b[Alyona]\o Привет, {nickname}! Я Alyona. \c02Попробуй !kanaly\o, !dobroeutro или !angliyskiy. Располагайся.
/bot set Alyona greeting_delivery private_notice
/bot set Alyona greeter_repeat_window 43200
/bot set Alyona farewell none
/bot set Alyona mention_response \c03\b[Alyona]\o Звали? Я здесь. \c02Попробуй !kanaly\o.

/bot addcmd Alyona kanaly \c03\b[Alyona]\o #russkiy #novosti #tehnologii #zhelezo #razrabotka #opensource #igry #nauchpop #ekonomika #futbol — \c02десять русскоязычных каналов\o, и в каждом что-то происходит.
/bot addcmd Alyona dobroeutro \c03\b[Alyona]\o \c02Доброе утро\o, {nickname}. Кофе сварен, клавиатура чистая, день начался.
/bot addcmd Alyona angliyskiy \c03\b[Alyona]\o Есть и англоязычные каналы, {nickname}: \c02#lobby, #tech, #news\o и другие. Язык меняется на панели инструментов.
/bot addcmd Alyona translit \c03\b[Alyona]\o Названия каналов латиницей, {nickname} — \c02клиент делает ссылкой только ASCII\o. Внутри канала пиши как обычно.

/bot join Alyona #russkiy

# ══════════════════════════════════════════════════════════
#  4. Ленточные боты — по одному на канал
# ══════════════════════════════════════════════════════════
# Каждый адрес ниже скачан продакшен-фетчером и разобран парсером приложения
# до того, как попал сюда. Первый опрос публикует полученную страницу и
# запоминает её; дальше выходит только новое.

# ── Fedya — #russkiy ─────────────────────────────────────
# Без приветствия: в этом канале встречает Alyona.
/bot create Fedya Reporter na dezhurstve
/bot set Fedya prefix !
/bot set Fedya cooldown 1000
/bot set Fedya rss_interval 20
/bot set Fedya rss_max_items 10000
/bot set Fedya greeting none
/bot set Fedya farewell none
/bot set Fedya mention_response \c03\b[Fedya]\o Читаю «Ленту» и РИА. \c02!istochniki\o покажет ленты.
/bot addcmd Fedya istochniki \c03\b[Fedya]\o «Лента.ру» и РИА Новости, опрос \c02каждые двадцать минут\o.
/bot join Fedya #russkiy
/bot rss add Fedya https://lenta.ru/rss #russkiy
/bot rss add Fedya https://ria.ru/export/rss2/archive/index.xml #russkiy

# ── Grisha — #novosti ────────────────────────────────────
/bot create Grisha Redaktor novostnogo stola
/bot set Grisha prefix !
/bot set Grisha cooldown 1000
/bot set Grisha rss_interval 20
/bot set Grisha rss_max_items 10000
/bot set Grisha greeting \c02\b[Grisha]\o Добро пожаловать в #novosti, {nickname}. \c14Заголовки приходят сами\o — !istochniki скажет откуда.
/bot set Grisha greeting_delivery private_notice
/bot set Grisha greeter_repeat_window 43200
/bot set Grisha farewell none
/bot set Grisha mention_response \c02\b[Grisha]\o Публикую то, что присылает лента. \c14!istochniki\o — список, !pervyy — про остальное.
/bot addcmd Grisha istochniki \c02\b[Grisha]\o ТАСС, «Интерфакс», «Коммерсантъ» и «Медуза», опрос \c14каждые двадцать минут\o.
/bot addcmd Grisha pervyy \c02\b[Grisha]\o Первый опрос ленты публикует текущую страницу и запоминает её. Дальше \c14выходит только новое\o.
/bot join Grisha #novosti
/bot rss add Grisha https://tass.ru/rss/v2.xml #novosti
/bot rss add Grisha https://www.interfax.ru/rss.asp #novosti
/bot rss add Grisha https://www.kommersant.ru/RSS/news.xml #novosti
/bot rss add Grisha https://meduza.io/rss/all #novosti

# ── Semyon — #tehnologii ─────────────────────────────────
/bot create Semyon Obozrevatel tehnologiy
/bot set Semyon prefix !
/bot set Semyon cooldown 1000
/bot set Semyon rss_interval 30
/bot set Semyon rss_max_items 10000
/bot set Semyon greeting \c12\b[Semyon]\o Привет, {nickname}. \c10 3DNews и CNews\o падают сюда сами. !istochniki — список, !podderzhka — до вопроса.
/bot set Semyon greeting_delivery private_notice
/bot set Semyon greeter_repeat_window 43200
/bot set Semyon farewell none
/bot set Semyon mention_response \c12\b[Semyon]\o Две технологические ленты на проводе. \c10!istochniki\o скажет какие.
/bot addcmd Semyon istochniki \c12\b[Semyon]\o 3DNews и CNews, опрос \c10каждые полчаса\o.
/bot addcmd Semyon podderzhka \c12\b[Semyon]\o Поддержка проекта — у проекта, {nickname}: там отвечают те, кто его пишет. \c10Здесь — разговор\o.
/bot join Semyon #tehnologii
/bot rss add Semyon https://3dnews.ru/news/rss/ #tehnologii
/bot rss add Semyon https://www.cnews.ru/inc/rss/news.xml #tehnologii

# ── Zhora — #zhelezo ─────────────────────────────────────
/bot create Zhora Sobiratel sistemnykh blokov
/bot set Zhora prefix !
/bot set Zhora cooldown 1000
/bot set Zhora rss_interval 45
/bot set Zhora rss_max_items 10000
/bot set Zhora greeting \c11\b[Zhora]\o Заходи, {nickname}. \c14iXBT и Overclockers\o на проводе. !istochniki — список, !apgreyd — до покупки.
/bot set Zhora greeting_delivery private_notice
/bot set Zhora greeter_repeat_window 43200
/bot set Zhora farewell none
/bot set Zhora mention_response \c11\b[Zhora]\o Платы, корпуса, разгон. \c14!istochniki\o покажет провод.
/bot addcmd Zhora istochniki \c11\b[Zhora]\o iXBT и Overclockers, опрос \c14каждые 45 минут\o.
/bot addcmd Zhora apgreyd \c11\b[Zhora]\o Перед апгрейдом \c14найди узкое место\o, {nickname}. Новая видеокарта из-за плохо оптимизированной игры — деньги на ветер.
/bot join Zhora #zhelezo
/bot rss add Zhora https://www.ixbt.com/export/articles.rss #zhelezo
/bot rss add Zhora https://overclockers.ru/rss/all.rss #zhelezo

# ── Kolya — #razrabotka ──────────────────────────────────
/bot create Kolya Chitatel chuzhikh kommitov
/bot set Kolya prefix !
/bot set Kolya cooldown 1000
/bot set Kolya rss_interval 30
/bot set Kolya rss_max_items 10000
/bot set Kolya greeting \c06\b[Kolya]\o Привет, {nickname}. \c13«Хабр» и «Код»\o приходят сюда сами. !istochniki — список.
/bot set Kolya greeting_delivery private_notice
/bot set Kolya greeter_repeat_window 43200
/bot set Kolya farewell none
/bot set Kolya mention_response \c06\b[Kolya]\o Читаю «Хабр» и «Код». \c13!istochniki\o — список.
/bot addcmd Kolya istochniki \c06\b[Kolya]\o «Хабр» и «Код», опрос \c13каждые полчаса\o.
/bot join Kolya #razrabotka
/bot rss add Kolya https://habr.com/ru/rss/all/all/?fl=ru #razrabotka
/bot rss add Kolya https://thecode.media/feed/ #razrabotka

# ── Pingvin — #opensource ────────────────────────────────
/bot create Pingvin Hranitel relizov
/bot set Pingvin prefix !
/bot set Pingvin cooldown 1000
/bot set Pingvin rss_interval 30
/bot set Pingvin rss_max_items 10000
/bot set Pingvin greeting \c03\b[Pingvin]\o Добро пожаловать, {nickname}. \c09OpenNET\o на проводе — релизы, ядра, дистрибутивы. !istochniki, !pochemu.
/bot set Pingvin greeting_delivery private_notice
/bot set Pingvin greeter_repeat_window 43200
/bot set Pingvin farewell none
/bot set Pingvin mention_response \c03\b[Pingvin]\o Я ношу новости открытого кода. \c09!istochniki\o — список.
/bot addcmd Pingvin istochniki \c03\b[Pingvin]\o OpenNET, опрос \c09каждые полчаса\o.
/bot addcmd Pingvin pochemu \c03\b[Pingvin]\o Поддержка проекта стоит ровно столько, сколько стоят его мейнтейнеры, {nickname}, а их здесь нет. \c09Новости\o — другое дело: их по-русски никто не носил.
/bot join Pingvin #opensource
/bot rss add Pingvin https://www.opennet.ru/opennews/opennews_all_utf.rss #opensource

# ── Vitya — #igry ────────────────────────────────────────
/bot create Vitya Operator igrovogo zala
/bot set Vitya prefix !
/bot set Vitya cooldown 1000
/bot set Vitya rss_interval 45
/bot set Vitya rss_max_items 10000
/bot set Vitya greeting \c12\b[Vitya]\o Заходи, {nickname}! \c10DTF и StopGame\o на проводе, а меню Games открывает 18 классических игр в браузере. !istochniki, !igrat.
/bot set Vitya greeting_delivery private_notice
/bot set Vitya greeter_repeat_window 43200
/bot set Vitya farewell none
/bot set Vitya mention_response \c12\b[Vitya]\o Новости про игры — это ко мне. \c10!igrat\o расскажет, как поиграть прямо здесь.
/bot addcmd Vitya istochniki \c12\b[Vitya]\o DTF и StopGame, опрос \c10каждые 45 минут\o.
/bot addcmd Vitya igrat \c12\b[Vitya]\o Открой меню \c10Games\o на верхней панели, {nickname}: DOOM, Quake, Wolfenstein и шесть приключений ScummVM — всё в браузере.
/bot join Vitya #igry
/bot rss add Vitya https://dtf.ru/rss #igry
/bot rss add Vitya https://rss.stopgame.ru/rss_news.xml #igry

# ── Sofya — #nauchpop ───────────────────────────────────────
/bot create Sofya Hranitelnitsa nablyudeniy
/bot set Sofya prefix !
/bot set Sofya cooldown 1000
/bot set Sofya rss_interval 60
/bot set Sofya rss_max_items 10000
/bot set Sofya greeting \c13\b[Sofya]\o Здравствуй, {nickname}. \c06N+1, «Элементы» и Naked Science\o приходят каждый час. !istochniki — список.
/bot set Sofya greeting_delivery private_notice
/bot set Sofya greeter_repeat_window 43200
/bot set Sofya farewell none
/bot set Sofya mention_response \c13\b[Sofya]\o Наука без платной стены. \c06!istochniki\o покажет провод.
/bot addcmd Sofya istochniki \c13\b[Sofya]\o N+1, «Элементы» и Naked Science, опрос \c06каждый час\o.
/bot join Sofya #nauchpop
/bot rss add Sofya https://nplus1.ru/rss #nauchpop
/bot rss add Sofya https://elementy.ru/rss/news #nauchpop
/bot rss add Sofya https://naked-science.ru/feed #nauchpop

# ── Larisa — #ekonomika ──────────────────────────────────
/bot create Larisa Nablyudatelnitsa rynkov
/bot set Larisa prefix !
/bot set Larisa cooldown 1000
/bot set Larisa rss_interval 30
/bot set Larisa rss_max_items 10000
/bot set Larisa greeting \c07\b[Larisa]\o Здравствуй, {nickname}. \c02РБК и vc.ru\o на проводе — !istochniki список, !predosterezhenie до того, как поверишь.
/bot set Larisa greeting_delivery private_notice
/bot set Larisa greeter_repeat_window 43200
/bot set Larisa farewell none
/bot set Larisa mention_response \c07\b[Larisa]\o Две экономические ленты. \c02!istochniki\o скажет какие.
/bot addcmd Larisa istochniki \c07\b[Larisa]\o РБК и vc.ru, опрос \c02каждые полчаса\o.
/bot addcmd Larisa predosterezhenie \c07\b[Larisa]\o Заголовок — не рекомендация, {nickname}. \c02Я читаю ленты\o, а не хрустальный шар.
/bot join Larisa #ekonomika
/bot rss add Larisa https://rssexport.rbc.ru/rbcnews/news/30/full.rss #ekonomika
/bot rss add Larisa https://vc.ru/rss #ekonomika

# ── Valera — #futbol ─────────────────────────────────────
/bot create Valera Letopisets s tribuny
/bot set Valera prefix !
/bot set Valera cooldown 1000
/bot set Valera rss_interval 20
/bot set Valera rss_max_items 10000
/bot set Valera greeting \c09\b[Valera]\o Привет, {nickname}! \c03«Чемпионат»\o на проводе. !istochniki — список, !klub если настаиваешь.
/bot set Valera greeting_delivery private_notice
/bot set Valera greeter_repeat_window 43200
/bot set Valera farewell none
/bot set Valera mention_response \c09\b[Valera]\o Мяч в игре. \c03!istochniki\o скажет, что я читаю.
/bot addcmd Valera istochniki \c09\b[Valera]\o «Чемпионат», опрос \c03каждые двадцать минут\o.
/bot addcmd Valera klub \c09\b[Valera]\o Свой не назову, {nickname}. \c03Бот с клубом\o теряет полканала на первом же дерби.
/bot join Valera #futbol
/bot rss add Valera https://www.championat.com/rss/news/ #futbol
```

---

## Verification

```
/bot list
/bot info Storozh
/admin channel list
```

`!Fedya rss list` in `#russkiy` shows what a bot actually stored — the check that
matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#russkiy` | **Alyona**, Fedya | Лента.ру, РИА Новости |
| `#novosti` | **Grisha** | ТАСС, Интерфакс, Коммерсантъ, Медуза |
| `#tehnologii` | **Semyon** | 3DNews, CNews |
| `#zhelezo` | **Zhora** | iXBT, Overclockers |
| `#razrabotka` | **Kolya** | Хабр, Код |
| `#opensource` | **Pingvin** | OpenNET |
| `#igry` | **Vitya** | DTF, StopGame |
| `#nauchpop` | **Sofya** | N+1, Элементы, Naked Science |
| `#ekonomika` | **Larisa** | РБК, vc.ru |
| `#futbol` | **Valera** | Чемпионат |

**Storozh** stands in all ten and greets in none of them. All channels are `+tn`.

Bot nicknames are Latin because the schema requires it — `[a-zA-Z][a-zA-Z0-9_-]*`
— but every line they speak is Cyrillic.
