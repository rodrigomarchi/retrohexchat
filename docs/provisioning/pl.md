# RetroHexChat — Polish Rooms — `pl`

Ten channels, twelve bots, twenty-three verified feeds. Documentation in English
for the operator; everything a user reads is in Polish.

Polish is the only language here with two independent security newsrooms —
Niebezpiecznik and Sekurak — so `#bezpieczenstwo` is a room rather than a corner
of `#technologie`. The English census put security at the highest p90 of any
subject measured: few rooms, but the people who arrive stay.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Instalacja pl
#  10 kanałów · 12 botów · kanały RSS sprawdzone po kolei
# ══════════════════════════════════════════════════════════

# ── 1. Kanały ────────────────────────────────────────────

/join #polska
/cs register
/topic Kanał polski — wchodź, siadaj, rozmawiamy. Kawa na koszt firmy.
/mode +tn

/join #wiadomosci
/cs register
/topic Wiadomości — Interia, Polsat News i Wprost, prosto z kanału RSS. !Zofia zrodla pokazuje listę.
/mode +tn

/join #technologie
/cs register
/topic Technologie — Spider's Web i Antyweb. Wsparcie projektu jest w projekcie; tutaj się rozmawia.
/mode +tn

/join #komputery
/cs register
/topic Komputery — Benchmark, PurePC i Komputer Świat. Podzespoły, składanie i modyfikacje.
/mode +tn

/join #bezpieczenstwo
/cs register
/topic Bezpieczeństwo — Niebezpiecznik i Sekurak. Czytaj przed łataniem, nie po.
/mode +tn

/join #gry
/cs register
/topic Gry — CD-Action i Eurogamer Polska. Żeby naprawdę zagrać, otwórz menu Games: 18 klasyków w przeglądarce.
/mode +tn

/join #kibic
/cs register
/topic Kibic — Przegląd Sportowy, Sportowe Fakty i TVP Sport. Tabela, transfery i wiadomo co.
/mode +tn

/join #nauka
/cs register
/topic Nauka — Crazy Nauka i National Geographic Polska. Głupich pytań nie ma, są niezadane.
/mode +tn

/join #gospodarka
/cs register
/topic Gospodarka — Bankier, Money.pl i Business Insider Polska. Nagłówek to nie rekomendacja.
/mode +tn

/join #film
/cs register
/topic Film — Filmweb na łączach. Premiery, seriale i spory o zakończenia.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Stroz — moderacja, wszystkie kanały
# ══════════════════════════════════════════════════════════
# Każdy język ma własnego moderatora: ostrzeżenie, którego nikt nie czyta, nie
# jest ostrzeżeniem. Milczy przy wejściu i wyjściu — stoi we wszystkich dziesięciu
# kanałach, a bramkarz witający dwa razy wygląda na usterkę.
/bot create Stroz Szef spokoju i dobrych manier
/bot set Stroz prefix !
/bot set Stroz cooldown 1000
/bot set Stroz mod_action warn
/bot set Stroz mod_spam 5
/bot set Stroz mod_flood 8
/bot set Stroz mod_warn \c04\b[Stroz]\o Spokojnie, {nickname}. \c05Kulturalnie\o jest przyjemniej, a ja mam dużo czasu.
/bot set Stroz greeting none
/bot set Stroz farewell none
/bot set Stroz mention_response \c04\b[Stroz]\o Patrzę. \c05Zawsze patrzę\o. Zachowuj się, a będzie dobrze.

/bot addcmd Stroz zasady \c04\b[Stroz]\o Wersja krótka: \c05nie bądź palantem\o. Wersji długiej nie ma.
/bot addcmd Stroz zglos \c04\b[Stroz]\o Widzisz coś dziwnego? \c05Napisz do admina\o. Ja robię automat, ludzie resztę.

/bot join Stroz #polska
/bot join Stroz #wiadomosci
/bot join Stroz #technologie
/bot join Stroz #komputery
/bot join Stroz #bezpieczenstwo
/bot join Stroz #gry
/bot join Stroz #kibic
/bot join Stroz #nauka
/bot join Stroz #gospodarka
/bot join Stroz #film

# ══════════════════════════════════════════════════════════
#  3. Kasia — gospodyni #polska
# ══════════════════════════════════════════════════════════
# Powitanie prywatnym notice: nowy dostaje wskazówki w kanale, nie zaśmiecając
# historii wszystkim pozostałym.
/bot create Kasia Gospodyni kanalu polskiego
/bot set Kasia prefix !
/bot set Kasia cooldown 1000
/bot set Kasia dice_default 1d20
/bot set Kasia greeting \c03\b[Kasia]\o Cześć {nickname}! Jestem Kasia. \c02Spróbuj !kanaly\o, !dziendobry albo !angielski. Czuj się jak u siebie.
/bot set Kasia greeting_delivery private_notice
/bot set Kasia greeter_repeat_window 43200
/bot set Kasia farewell none
/bot set Kasia mention_response \c03\b[Kasia]\o Wołałeś? Jestem. \c02Spróbuj !kanaly\o.

/bot addcmd Kasia kanaly \c03\b[Kasia]\o #polska #wiadomosci #technologie #komputery #bezpieczenstwo #gry #kibic #nauka #gospodarka #film — \c02dziesięć kanałów po polsku\o, i w każdym coś się dzieje.
/bot addcmd Kasia dziendobry \c03\b[Kasia]\o \c02Dzień dobry\o, {nickname}. Kawa zaparzona, klawiatura czysta, dzień się zaczyna.
/bot addcmd Kasia angielski \c03\b[Kasia]\o Są też kanały po angielsku, {nickname}: \c02#lobby, #tech, #news\o i więcej. Język zmienia się na pasku narzędzi.
/bot addcmd Kasia ogonki \c03\b[Kasia]\o Nazwy kanałów są bez polskich znaków, {nickname} — \c02klient robi odnośnik tylko z ASCII\o. W środku pisz normalnie.

/bot join Kasia #polska

# ══════════════════════════════════════════════════════════
#  4. Boty RSS — jeden na kanał
# ══════════════════════════════════════════════════════════
# Każdy adres poniżej został pobrany produkcyjnym fetcherem i odczytany parserem
# aplikacji, zanim tu trafił. Pierwsze odpytanie publikuje otrzymaną stronę i
# zapamiętuje ją; potem wychodzi tylko to, co nowe.

# ── Marek — #polska ──────────────────────────────────────
# Bez powitania: w tym kanale wita Kasia.
/bot create Marek Reporter na dyzurze
/bot set Marek prefix !
/bot set Marek cooldown 1000
/bot set Marek rss_interval 20
/bot set Marek rss_max_items 10000
/bot set Marek greeting none
/bot set Marek farewell none
/bot set Marek mention_response \c03\b[Marek]\o Czytam RMF24 i Onet. \c02!zrodla\o pokazuje kanały RSS.
/bot addcmd Marek zrodla \c03\b[Marek]\o RMF24 i Onet, sprawdzane \c02co dwadzieścia minut\o.
/bot join Marek #polska
/bot rss add Marek https://www.rmf24.pl/feed #polska
/bot rss add Marek https://wiadomosci.onet.pl/.feed #polska

# ── Zofia — #wiadomosci ──────────────────────────────────
/bot create Zofia Szefowa dzialu wiadomosci
/bot set Zofia prefix !
/bot set Zofia cooldown 1000
/bot set Zofia rss_interval 20
/bot set Zofia rss_max_items 10000
/bot set Zofia greeting \c02\b[Zofia]\o Witaj w #wiadomosci, {nickname}. \c14Nagłówki przychodzą same\o — !zrodla mówi skąd.
/bot set Zofia greeting_delivery private_notice
/bot set Zofia greeter_repeat_window 43200
/bot set Zofia farewell none
/bot set Zofia mention_response \c02\b[Zofia]\o Publikuję to, co przyśle kanał RSS. \c14!zrodla\o po listę, !pierwsze po resztę.
/bot addcmd Zofia zrodla \c02\b[Zofia]\o Interia, Polsat News i Wprost, sprawdzane \c14co dwadzieścia minut\o.
/bot addcmd Zofia pierwsze \c02\b[Zofia]\o Pierwsze pobranie publikuje bieżącą stronę i ją zapamiętuje. Potem \c14wychodzi tylko nowe\o.
/bot join Zofia #wiadomosci
/bot rss add Zofia https://fakty.interia.pl/feed #wiadomosci
/bot rss add Zofia https://www.polsatnews.pl/rss/wszystkie.xml #wiadomosci
/bot rss add Zofia https://www.wprost.pl/rss #wiadomosci

# ── Jacek — #technologie ─────────────────────────────────
/bot create Jacek Obserwator branzy
/bot set Jacek prefix !
/bot set Jacek cooldown 1000
/bot set Jacek rss_interval 30
/bot set Jacek rss_max_items 10000
/bot set Jacek greeting \c12\b[Jacek]\o Cześć {nickname}. \c10Spider's Web i Antyweb\o wpadają tu same. !zrodla po listę, !wsparcie zanim zapytasz.
/bot set Jacek greeting_delivery private_notice
/bot set Jacek greeter_repeat_window 43200
/bot set Jacek farewell none
/bot set Jacek mention_response \c12\b[Jacek]\o Dwa kanały technologiczne na łączach. \c10!zrodla\o mówi które.
/bot addcmd Jacek zrodla \c12\b[Jacek]\o Spider's Web i Antyweb, sprawdzane \c10co pół godziny\o.
/bot addcmd Jacek wsparcie \c12\b[Jacek]\o Wsparcie projektu jest w projekcie, {nickname} — tam odpowiadają ci, którzy go utrzymują. \c10Tu jest knajpa\o.
/bot join Jacek #technologie
/bot rss add Jacek https://spidersweb.pl/feed #technologie
/bot rss add Jacek https://antyweb.pl/feed #technologie

# ── Bogdan — #komputery ──────────────────────────────────
/bot create Bogdan Skladacz komputerow
/bot set Bogdan prefix !
/bot set Bogdan cooldown 1000
/bot set Bogdan rss_interval 45
/bot set Bogdan rss_max_items 10000
/bot set Bogdan greeting \c11\b[Bogdan]\o Witaj, {nickname}. \c14Benchmark, PurePC i Komputer Świat\o na łączach. !zrodla po listę, !upgrade przed zakupem.
/bot set Bogdan greeting_delivery private_notice
/bot set Bogdan greeter_repeat_window 43200
/bot set Bogdan farewell none
/bot set Bogdan mention_response \c11\b[Bogdan]\o Podzespoły i składanie. \c14!zrodla\o pokazuje łącza.
/bot addcmd Bogdan zrodla \c11\b[Bogdan]\o Benchmark, PurePC i Komputer Świat, sprawdzane \c14co 45 minut\o.
/bot addcmd Bogdan upgrade \c11\b[Bogdan]\o Przed wymianą \c14zmierz wąskie gardło\o, {nickname}. Nowa karta z powodu źle zoptymalizowanej gry to wyrzucone pieniądze.
/bot join Bogdan #komputery
/bot rss add Bogdan https://www.benchmark.pl/rss/aktualnosci-pliki.xml #komputery
/bot rss add Bogdan https://www.purepc.pl/rss #komputery
/bot rss add Bogdan https://www.komputerswiat.pl/.feed #komputery

# ── Iwona — #bezpieczenstwo ──────────────────────────────
/bot create Iwona Nosicielka ostrzezen czytanych za pozno
/bot set Iwona prefix !
/bot set Iwona cooldown 1000
/bot set Iwona rss_interval 30
/bot set Iwona rss_max_items 10000
/bot set Iwona greeting \c04\b[Iwona]\o {nickname}, witaj. \c05Niebezpiecznik i Sekurak\o na łączach. I tak przeczytasz później, więc przeczytaj teraz. !zrodla, !latka.
/bot set Iwona greeting_delivery private_notice
/bot set Iwona greeter_repeat_window 43200
/bot set Iwona farewell none
/bot set Iwona mention_response \c04\b[Iwona]\o Ostrzegam; to cała moja praca. \c05!zrodla\o mówi skąd.
/bot addcmd Iwona zrodla \c04\b[Iwona]\o Niebezpiecznik i Sekurak, sprawdzane \c05co pół godziny\o.
/bot addcmd Iwona latka \c04\b[Iwona]\o Ostrzeżenie to nie poprawka. \c05Przeczytaj, znajdź swoją wersję, potem łataj\o. W tej kolejności, {nickname}.
/bot join Iwona #bezpieczenstwo
/bot rss add Iwona https://niebezpiecznik.pl/feed/ #bezpieczenstwo
/bot rss add Iwona https://sekurak.pl/feed/ #bezpieczenstwo

# ── Rafal — #gry ─────────────────────────────────────────
/bot create Rafal Operator salonu gier
/bot set Rafal prefix !
/bot set Rafal cooldown 1000
/bot set Rafal rss_interval 45
/bot set Rafal rss_max_items 10000
/bot set Rafal greeting \c12\b[Rafal]\o Wchodź, {nickname}! \c10CD-Action i Eurogamer Polska\o na łączach, a menu Games otwiera 18 klasyków w przeglądarce. !zrodla, !zagraj.
/bot set Rafal greeting_delivery private_notice
/bot set Rafal greeter_repeat_window 43200
/bot set Rafal farewell none
/bot set Rafal mention_response \c12\b[Rafal]\o Newsy o grach przynoszę ja. \c10!zagraj\o mówi, jak zagrać tutaj.
/bot addcmd Rafal zrodla \c12\b[Rafal]\o CD-Action i Eurogamer Polska, sprawdzane \c10co 45 minut\o.
/bot addcmd Rafal zagraj \c12\b[Rafal]\o Otwórz menu \c10Games\o na górnym pasku, {nickname}: DOOM, Quake, Wolfenstein i sześć przygodówek ScummVM, wszystko w przeglądarce.
/bot join Rafal #gry
/bot rss add Rafal https://www.cdaction.pl/rss #gry
/bot rss add Rafal https://www.eurogamer.pl/feed #gry

# ── Lech — #kibic ────────────────────────────────────────
/bot create Lech Kronikarz z trybuny
/bot set Lech prefix !
/bot set Lech cooldown 1000
/bot set Lech rss_interval 20
/bot set Lech rss_max_items 10000
/bot set Lech greeting \c09\b[Lech]\o Cześć {nickname}! \c03Przegląd Sportowy, Sportowe Fakty i TVP Sport\o na łączach. !zrodla po listę, !klub jeśli nalegasz.
/bot set Lech greeting_delivery private_notice
/bot set Lech greeter_repeat_window 43200
/bot set Lech farewell none
/bot set Lech mention_response \c09\b[Lech]\o Piłka w grze. \c03!zrodla\o mówi, co czytam.
/bot addcmd Lech zrodla \c09\b[Lech]\o Przegląd Sportowy, Sportowe Fakty i TVP Sport, sprawdzane \c03co dwadzieścia minut\o.
/bot addcmd Lech klub \c09\b[Lech]\o Swojego nie zdradzę, {nickname}. \c03Bot z klubem\o traci pół kanału przy pierwszych derbach.
/bot join Lech #kibic
/bot rss add Lech https://przegladsportowy.onet.pl/.feed #kibic
/bot rss add Lech https://sportowefakty.wp.pl/rss.xml #kibic
/bot rss add Lech https://sport.tvp.pl/rss #kibic

# ── Kopernik — #nauka ────────────────────────────────────
/bot create Kopernik Straznik obserwacji
/bot set Kopernik prefix !
/bot set Kopernik cooldown 1000
/bot set Kopernik rss_interval 60
/bot set Kopernik rss_max_items 10000
/bot set Kopernik greeting \c06\b[Kopernik]\o Witaj, {nickname}. \c13Crazy Nauka i National Geographic Polska\o przychodzą co godzinę. !zrodla po listę.
/bot set Kopernik greeting_delivery private_notice
/bot set Kopernik greeter_repeat_window 43200
/bot set Kopernik farewell none
/bot set Kopernik mention_response \c06\b[Kopernik]\o Nauka bez płatnej bramki. \c13!zrodla\o pokazuje łącza.
/bot addcmd Kopernik zrodla \c06\b[Kopernik]\o Crazy Nauka i National Geographic Polska, sprawdzane \c13co godzinę\o.
/bot join Kopernik #nauka
/bot rss add Kopernik https://www.crazynauka.pl/feed/ #nauka
/bot rss add Kopernik https://www.national-geographic.pl/rss #nauka

# ── Halina — #gospodarka ─────────────────────────────────
/bot create Halina Obserwatorka rynkow
/bot set Halina prefix !
/bot set Halina cooldown 1000
/bot set Halina rss_interval 30
/bot set Halina rss_max_items 10000
/bot set Halina greeting \c07\b[Halina]\o Witaj, {nickname}. \c02Bankier, Money.pl i Business Insider Polska\o na łączach — !zrodla po listę, !uwaga zanim uwierzysz.
/bot set Halina greeting_delivery private_notice
/bot set Halina greeter_repeat_window 43200
/bot set Halina farewell none
/bot set Halina mention_response \c07\b[Halina]\o Trzy kanały gospodarcze. \c02!zrodla\o mówi które.
/bot addcmd Halina zrodla \c07\b[Halina]\o Bankier, Money.pl i Business Insider Polska, sprawdzane \c02co pół godziny\o.
/bot addcmd Halina uwaga \c07\b[Halina]\o Nagłówek to nie rekomendacja, {nickname}. \c02Czytam kanały RSS\o, nie szklaną kulę.
/bot join Halina #gospodarka
/bot rss add Halina https://www.bankier.pl/rss/wiadomosci.xml #gospodarka
/bot rss add Halina https://www.money.pl/rss/wszystkie/ #gospodarka
/bot rss add Halina https://businessinsider.com.pl/.feed #gospodarka

# ── Ewa — #film ──────────────────────────────────────────
/bot create Ewa Bileterka sali kinowej
/bot set Ewa prefix !
/bot set Ewa cooldown 1000
/bot set Ewa rss_interval 60
/bot set Ewa rss_max_items 10000
/bot set Ewa greeting \c05\b[Ewa]\o Wchodź, {nickname}. \c13Filmweb\o na łączach — premiery, seriale, sezony. !zrodla po listę.
/bot set Ewa greeting_delivery private_notice
/bot set Ewa greeter_repeat_window 43200
/bot set Ewa farewell none
/bot set Ewa mention_response \c05\b[Ewa]\o Kino i seriale. \c13!zrodla\o mówi skąd.
/bot addcmd Ewa zrodla \c05\b[Ewa]\o Filmweb, sprawdzany \c13co godzinę\o.
/bot join Ewa #film
/bot rss add Ewa https://www.filmweb.pl/rss/news #film
```

---

## Verification

```
/bot list
/bot info Stroz
/admin channel list
```

`!Marek rss list` in `#polska` shows what a bot actually stored — the check that
matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#polska` | **Kasia**, Marek | RMF24, Onet |
| `#wiadomosci` | **Zofia** | Interia, Polsat News, Wprost |
| `#technologie` | **Jacek** | Spider's Web, Antyweb |
| `#komputery` | **Bogdan** | Benchmark, PurePC, Komputer Świat |
| `#bezpieczenstwo` | **Iwona** | Niebezpiecznik, Sekurak |
| `#gry` | **Rafal** | CD-Action, Eurogamer Polska |
| `#kibic` | **Lech** | Przegląd Sportowy, Sportowe Fakty, TVP Sport |
| `#nauka` | **Kopernik** | Crazy Nauka, National Geographic Polska |
| `#gospodarka` | **Halina** | Bankier, Money.pl, Business Insider Polska |
| `#film` | **Ewa** | Filmweb |

**Stroz** stands in all ten and greets in none of them. All channels are `+tn`.

Room names drop the Polish diacritics — `#wiadomosci`, `#bezpieczenstwo` — because
the client only turns ASCII channel mentions into links. Topics, greetings and
messages keep them.
