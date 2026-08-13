# RetroHexChat — Portuguese (Portugal) Rooms — `pt_PT`

Ten channels, twelve bots, eighteen verified feeds. Documentation in English for
the operator; every line a user reads is in European Portuguese.

Separate from `pt_BR` on purpose. The two variants share a grammar and almost no
newsroom: a Brazilian reading `#portugal` gets Lisbon municipal politics, a
Portuguese reader in `#brasil` gets the Brazilian league. Splitting the rooms
costs nothing here — the feeds were already distinct — and a room whose wire is
foreign to the reader is a room they leave.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Setup pt_PT
#  10 canais · 12 bots · feeds verificados um a um
# ══════════════════════════════════════════════════════════

# ── 1. Canais ────────────────────────────────────────────

/join #portugal
/cs register
/topic Canal português — conversa à portuguesa. Entra, senta-te, o café é por conta da casa.
/mode +tn

/join #actualidade
/cs register
/topic Actualidade — Observador e SAPO 24 directamente do feed. !Duarte fontes mostra de onde vem.
/mode +tn

/join #ultimahora
/cs register
/topic Última hora — Notícias ao Minuto e TVI. Chega primeiro aqui, contexto vem depois no #actualidade.
/mode +tn

/join #informatica
/cs register
/topic Informática — SAPO Tek e Pplware no fio. Suporte de projecto é com o projecto; aqui é conversa.
/mode +tn

/join #gadgets
/cs register
/topic Gadgets — 4gnews e Leak. Telemóveis, relógios e coisas que não precisas mas queres.
/mode +tn

/join #negocios
/cs register
/topic Negócios — ECO e Jornal de Negócios. !Afonso fontes lista os feeds.
/mode +tn

/join #bolsa
/cs register
/topic Bolsa — Dinheiro Vivo no fio. Manchete não é conselho de investimento.
/mode +tn

/join #desporto
/cs register
/topic Desporto — Record e Mais Futebol. Bola, tabela e a discussão do costume.
/mode +tn

/join #cultura
/cs register
/topic Cultura — Visão e Sábado. Livros, cinema, exposições e o que anda a dar.
/mode +tn

/join #natureza
/cs register
/topic Natureza — Wilder no fio. Aves, plantas, bichos e o território que os aguenta.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Sentinela — moderação, todos os canais
# ══════════════════════════════════════════════════════════
/bot create Sentinela Responsavel pela ordem nas salas
/bot set Sentinela prefix !
/bot set Sentinela cooldown 1000
/bot set Sentinela mod_action warn
/bot set Sentinela mod_spam 5
/bot set Sentinela mod_flood 8
/bot set Sentinela mod_warn \c04\b[Sentinela]\o Calma, {nickname}. \c05Educação primeiro\o — isto aqui é uma sala, não um comício.
/bot set Sentinela greeting none
/bot set Sentinela farewell none
/bot set Sentinela mention_response \c04\b[Sentinela]\o Estou atento. \c05Sempre atento\o. Porta-te bem e damo-nos lindamente.

/bot addcmd Sentinela regras \c04\b[Sentinela]\o Versão curta: \c05não sejas parvo\o. Versão longa: não há versão longa.
/bot addcmd Sentinela denuncia \c04\b[Sentinela]\o Viste algo estranho? \c05Fala com um admin\o. Eu trato do automático, as pessoas tratam do resto.

/bot join Sentinela #portugal
/bot join Sentinela #actualidade
/bot join Sentinela #ultimahora
/bot join Sentinela #informatica
/bot join Sentinela #gadgets
/bot join Sentinela #negocios
/bot join Sentinela #bolsa
/bot join Sentinela #desporto
/bot join Sentinela #cultura
/bot join Sentinela #natureza

# ══════════════════════════════════════════════════════════
#  3. Fernao — anfitrião do #portugal
# ══════════════════════════════════════════════════════════
/bot create Fernao Anfitriao do canal portugues
/bot set Fernao prefix !
/bot set Fernao cooldown 1000
/bot set Fernao dice_default 1d20
/bot set Fernao greeting \c03\b[Fernao]\o Viva, {nickname}! Sou o Fernao. \c02Experimenta !salas\o, !bomdia ou !ingles. Fica à vontade.
/bot set Fernao greeting_delivery private_notice
/bot set Fernao greeter_repeat_window 43200
/bot set Fernao farewell none
/bot set Fernao mention_response \c03\b[Fernao]\o Chamaste? Estou cá. \c02Tenta !salas\o.

/bot addcmd Fernao salas \c03\b[Fernao]\o #portugal #actualidade #ultimahora #informatica #gadgets #negocios #bolsa #desporto #cultura #natureza — \c02dez salas em português\o, todas com alguma coisa a acontecer.
/bot addcmd Fernao bomdia \c03\b[Fernao]\o \c02Bom dia\o, {nickname}. Café tirado, teclado limpo, dia a começar.
/bot addcmd Fernao ingles \c03\b[Fernao]\o Há também salas em inglês, {nickname}: \c02#lobby, #tech, #news\o e mais. O idioma muda-se na barra de ferramentas.
/bot addcmd Fernao brasil \c03\b[Fernao]\o O #brasil existe e é bem-vindo, {nickname} — \c02separámos as salas\o porque as fontes são outras, não porque a conversa é.

/bot join Fernao #portugal

# ══════════════════════════════════════════════════════════
#  4. Bots de feed — um por canal
# ══════════════════════════════════════════════════════════
# Cada endereço abaixo foi buscado pelo fetcher de produção e lido pelo parser
# da aplicação antes de entrar aqui. O primeiro poll publica a página que recebe
# e regista-a; a partir daí só sai o que chega de novo.
#
# A primeira leitura sai em lotes, não de uma vez: a protecção de flood vive na
# sessão de cada leitor e auto-ignora quem excede o limite. Nada é descartado —
# um feed com fila volta em menos de um minuto para o resto.

# ── Vasco — #portugal ────────────────────────────────────
# Sem saudação: quem recebe os recém-chegados nesta sala é o Fernao.
/bot create Vasco Jornalista de servico
/bot set Vasco prefix !
/bot set Vasco cooldown 1000
/bot set Vasco rss_interval 20
/bot set Vasco greeting none
/bot set Vasco farewell none
/bot set Vasco mention_response \c03\b[Vasco]\o Leio o Público e a RTP. \c02!fontes\o lista os feeds.
/bot addcmd Vasco fontes \c03\b[Vasco]\o Público e RTP Notícias, verificados \c02de vinte em vinte minutos\o.
/bot join Vasco #portugal
/bot rss add Vasco https://feeds.feedburner.com/PublicoRSS #portugal
/bot rss add Vasco https://www.rtp.pt/noticias/rss #portugal

# ── Duarte — #actualidade ────────────────────────────────
/bot create Duarte Editor da mesa de actualidade
/bot set Duarte prefix !
/bot set Duarte cooldown 1000
/bot set Duarte rss_interval 20
/bot set Duarte greeting \c02\b[Duarte]\o Bem-vindo à #actualidade, {nickname}. \c14As manchetes chegam sozinhas\o — !fontes mostra de onde.
/bot set Duarte greeting_delivery private_notice
/bot set Duarte greeter_repeat_window 43200
/bot set Duarte farewell none
/bot set Duarte mention_response \c02\b[Duarte]\o Publico o que o feed manda. \c14!fontes\o para a lista, !primeira para o resto.
/bot addcmd Duarte fontes \c02\b[Duarte]\o Observador e SAPO 24, verificados \c14de vinte em vinte minutos\o.
/bot addcmd Duarte primeira \c02\b[Duarte]\o A primeira busca de um feed publica a página actual e regista-a. Depois disso \c14só sai o que é novo\o.
/bot join Duarte #actualidade
/bot rss add Duarte https://observador.pt/feed/ #actualidade
/bot rss add Duarte https://24.sapo.pt/rss #actualidade

# ── Leonor — #ultimahora ─────────────────────────────────
/bot create Leonor Plantao de ultima hora
/bot set Leonor prefix !
/bot set Leonor cooldown 1000
/bot set Leonor rss_interval 20
/bot set Leonor greeting \c04\b[Leonor]\o {nickname}, isto aqui é o fio rápido. \c07Notícias ao Minuto e TVI\o — !fontes para a lista.
/bot set Leonor greeting_delivery private_notice
/bot set Leonor greeter_repeat_window 43200
/bot set Leonor farewell none
/bot set Leonor mention_response \c04\b[Leonor]\o Última hora, sem contexto e sem desculpas. \c07!fontes\o lista o fio.
/bot addcmd Leonor fontes \c04\b[Leonor]\o Notícias ao Minuto e TVI, verificados \c07de vinte em vinte minutos\o.
/bot join Leonor #ultimahora
/bot rss add Leonor https://www.noticiasaominuto.com/rss/ultima-hora #ultimahora
/bot rss add Leonor https://tvi.iol.pt/rss #ultimahora

# ── Gil — #informatica ───────────────────────────────────
/bot create Gil Curioso de informatica
/bot set Gil prefix !
/bot set Gil cooldown 1000
/bot set Gil rss_interval 30
/bot set Gil greeting \c10\b[Gil]\o Olá, {nickname}. \c06SAPO Tek e Pplware\o caem aqui sozinhos. !fontes para a lista, !suporte antes de perguntares.
/bot set Gil greeting_delivery private_notice
/bot set Gil greeter_repeat_window 43200
/bot set Gil farewell none
/bot set Gil mention_response \c10\b[Gil]\o Dois feeds de informática no ar. \c06!fontes\o mostra quais.
/bot addcmd Gil fontes \c10\b[Gil]\o SAPO Tek e Pplware, verificados \c06de meia em meia hora\o.
/bot addcmd Gil suporte \c10\b[Gil]\o Suporte de um projecto é com o projecto, {nickname} — quem responde bem é quem o mantém. \c06Aqui é conversa\o.
/bot join Gil #informatica
/bot rss add Gil https://tek.sapo.pt/feed #informatica
/bot rss add Gil https://pplware.sapo.pt/feed/ #informatica

# ── Mafalda — #gadgets ───────────────────────────────────
/bot create Mafalda Testadora de bugigangas
/bot set Mafalda prefix !
/bot set Mafalda cooldown 1000
/bot set Mafalda rss_interval 45
/bot set Mafalda greeting \c13\b[Mafalda]\o Entra, {nickname}. \c11 4gnews e Leak\o no fio — !fontes para a lista.
/bot set Mafalda greeting_delivery private_notice
/bot set Mafalda greeter_repeat_window 43200
/bot set Mafalda farewell none
/bot set Mafalda mention_response \c13\b[Mafalda]\o Telemóveis, relógios e carregadores que não servem em nada. \c11!fontes\o lista o fio.
/bot addcmd Mafalda fontes \c13\b[Mafalda]\o 4gnews e Leak, verificados \c11de 45 em 45 minutos\o.
/bot join Mafalda #gadgets
/bot rss add Mafalda https://4gnews.pt/feed/ #gadgets
/bot rss add Mafalda https://leak.pt/feed/ #gadgets

# ── Afonso — #negocios ───────────────────────────────────
/bot create Afonso Cronista de economia
/bot set Afonso prefix !
/bot set Afonso cooldown 1000
/bot set Afonso rss_interval 30
/bot set Afonso greeting \c11\b[Afonso]\o Bem-vindo, {nickname}. \c02ECO e Jornal de Negócios\o chegam aqui sozinhos. !fontes para a lista.
/bot set Afonso greeting_delivery private_notice
/bot set Afonso greeter_repeat_window 43200
/bot set Afonso farewell none
/bot set Afonso mention_response \c11\b[Afonso]\o Dois feeds de economia no ar. \c02!fontes\o mostra quais.
/bot addcmd Afonso fontes \c11\b[Afonso]\o ECO e Jornal de Negócios, verificados \c02de meia em meia hora\o.
/bot join Afonso #negocios
/bot rss add Afonso https://eco.sapo.pt/feed/ #negocios
/bot rss add Afonso https://www.jornaldenegocios.pt/rss #negocios

# ── Beatriz — #bolsa ─────────────────────────────────────
/bot create Beatriz Observadora dos mercados
/bot set Beatriz prefix !
/bot set Beatriz cooldown 1000
/bot set Beatriz rss_interval 30
/bot set Beatriz greeting \c07\b[Beatriz]\o Olá, {nickname}. \c14Dinheiro Vivo\o no fio — !fontes para a lista, !aviso antes de acreditares.
/bot set Beatriz greeting_delivery private_notice
/bot set Beatriz greeter_repeat_window 43200
/bot set Beatriz farewell none
/bot set Beatriz mention_response \c07\b[Beatriz]\o Leio o Dinheiro Vivo. \c14!fontes\o para a lista.
/bot addcmd Beatriz fontes \c07\b[Beatriz]\o Dinheiro Vivo, verificado \c14de meia em meia hora\o.
/bot addcmd Beatriz aviso \c07\b[Beatriz]\o Manchete não é conselho, {nickname}. \c14Eu leio feeds\o, não bolas de cristal.
/bot join Beatriz #bolsa
/bot rss add Beatriz https://www.dinheirovivo.pt/feed/ #bolsa

# ── Eusebio — #desporto ──────────────────────────────────
/bot create Eusebio Cronista de bancada
/bot set Eusebio prefix !
/bot set Eusebio cooldown 1000
/bot set Eusebio rss_interval 20
/bot set Eusebio greeting \c03\b[Eusebio]\o Viva, {nickname}! \c09Record e Mais Futebol\o no fio. !fontes para a lista, !clube se insistires.
/bot set Eusebio greeting_delivery private_notice
/bot set Eusebio greeter_repeat_window 43200
/bot set Eusebio farewell none
/bot set Eusebio mention_response \c03\b[Eusebio]\o Bola a rolar. \c09!fontes\o lista o que leio.
/bot addcmd Eusebio fontes \c03\b[Eusebio]\o Record e Mais Futebol, verificados \c09de vinte em vinte minutos\o.
/bot addcmd Eusebio clube \c03\b[Eusebio]\o Não digo o meu, {nickname}. \c09Um bot com clube\o perde metade da sala ao primeiro dérbi.
/bot join Eusebio #desporto
/bot rss add Eusebio https://www.record.pt/rss #desporto
/bot rss add Eusebio https://maisfutebol.iol.pt/rss #desporto

# ── Amalia — #cultura ────────────────────────────────────
/bot create Amalia Guardia da agenda cultural
/bot set Amalia prefix !
/bot set Amalia cooldown 1000
/bot set Amalia rss_interval 60
/bot set Amalia greeting \c06\b[Amalia]\o Olá, {nickname}. \c13Visão e Sábado\o chegam de hora a hora. !fontes para a lista.
/bot set Amalia greeting_delivery private_notice
/bot set Amalia greeter_repeat_window 43200
/bot set Amalia farewell none
/bot set Amalia mention_response \c06\b[Amalia]\o Livros, cinema e exposições. \c13!fontes\o lista o fio.
/bot addcmd Amalia fontes \c06\b[Amalia]\o Visão e Sábado, verificados \c13de hora a hora\o.
/bot join Amalia #cultura
/bot rss add Amalia https://visao.pt/feed/ #cultura
/bot rss add Amalia https://www.sabado.pt/rss #cultura

# ── Ines — #natureza ─────────────────────────────────────
/bot create Ines Vigilante do territorio
/bot set Ines prefix !
/bot set Ines cooldown 1000
/bot set Ines rss_interval 120
/bot set Ines greeting \c09\b[Ines]\o Bem-vindo, {nickname}. \c03Wilder\o no fio — aves, plantas e o território. !fontes para a lista.
/bot set Ines greeting_delivery private_notice
/bot set Ines greeter_repeat_window 43200
/bot set Ines farewell none
/bot set Ines mention_response \c09\b[Ines]\o Publico o Wilder. \c03!fontes\o para a lista.
/bot addcmd Ines fontes \c09\b[Ines]\o Wilder, verificado \c03de duas em duas horas\o — publica poucas peças por semana e não vale a pena bater à porta mais vezes.
/bot join Ines #natureza
/bot rss add Ines https://www.wilder.pt/feed/ #natureza
```

---

## Verification

```
/bot list
/bot info Sentinela
/admin channel list
```

`!Vasco rss list` in `#portugal` shows what a bot actually stored — the check
that matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#portugal` | **Fernao**, Vasco | Público, RTP |
| `#actualidade` | **Duarte** | Observador, SAPO 24 |
| `#ultimahora` | **Leonor** | Notícias ao Minuto, TVI |
| `#informatica` | **Gil** | SAPO Tek, Pplware |
| `#gadgets` | **Mafalda** | 4gnews, Leak |
| `#negocios` | **Afonso** | ECO, Jornal de Negócios |
| `#bolsa` | **Beatriz** | Dinheiro Vivo |
| `#desporto` | **Eusebio** | Record, Mais Futebol |
| `#cultura` | **Amalia** | Visão, Sábado |
| `#natureza` | **Ines** | Wilder |

**Sentinela** stands in all ten and greets in none of them. All channels are `+tn`.
