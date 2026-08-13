# RetroHexChat — Portuguese (Brazil) Rooms — `pt_BR`

Ten channels, twelve bots, twenty-three verified feeds. Documentation is in
English because the operator reads it; everything a user sees — topics,
greetings, bot answers — is in Brazilian Portuguese, because they read that.

`#brasil` is the room the census argued for and the English script used to carry:
13 live `#brasil` rooms spread over 12 networks, 273 people between them, the
largest holding 57. Distributed demand with no owner. The other nine rooms follow
the same reasoning applied to a language rather than a subject — a wire gives a
room something to show before it has a crowd.

## Prerequisite

Run [`en.md`](en.md) first. It names the server and opens the English rooms; this
script adds rooms and touches no server-wide setting. Paste the block below into
the Admin Console in one shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Setup pt_BR
#  10 canais · 12 bots · feeds verificados um a um
# ══════════════════════════════════════════════════════════

# ── 1. Canais ────────────────────────────────────────────

# #brasil — a sala social. O censo achou 13 canais #brasil vivos em 12 redes,
# 273 pessoas somadas, o maior com 57. Demanda distribuida, sem dono.
/join #brasil
/cs register
/topic Canal brasileiro — bate-papo em português. Chega aí, senta e fica à vontade.
/mode +tn

# #jornal — manchetes por feed, não por opinião.
/join #jornal
/cs register
/topic Jornal — manchetes de Folha, BBC Brasil e Poder360, direto do feed. !Zeca fontes lista tudo.
/mode +tn

/join #tecnologia
/cs register
/topic Tecnologia — Tecnoblog, Canaltech, Olhar Digital e Manual do Usuário. !Bento fontes para a lista.
/mode +tn

/join #hardware
/cs register
/topic Hardware — placa, gabinete, gambiarra e upgrade. Fofoca de silício por conta do !Juca.
/mode +tn

/join #programacao
/cs register
/topic Programação — TabNews e Meio Bit no fio. Dúvida de linguagem é com o projeto dela; aqui é o boteco.
/mode +tn

/join #economia
/cs register
/topic Economia — InfoMoney, Exame e Valor. !Iara fontes mostra de onde vem cada manchete.
/mode +tn

/join #futebol
/cs register
/topic Futebol — ge e Trivela no ar. Tabela, bola rolando e opinião de quem não joga há vinte anos.
/mode +tn

/join #ciencia
/cs register
/topic Ciência — Superinteressante e Galileu. Pergunta idiota não existe, existe pergunta não feita.
/mode +tn

/join #musica
/cs register
/topic Música — POPline e TMDQA no fio. Lançamento, show e briga de fandom.
/mode +tn

/join #jogos
/cs register
/topic Jogos — Adrenaline no fio. Para jogar de verdade, abre o menu Games: 18 clássicos rodando no navegador.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Sansao — moderação, todos os canais
# ══════════════════════════════════════════════════════════
# Cada idioma tem o seu moderador: um aviso que a pessoa não lê não é aviso.
# Calado na entrada e na saída — ele está nas dez salas, e um segurança que
# cumprimenta duas vezes parece defeito, não personalidade.
/bot create Sansao Chefe de seguranca e paz nos canais
/bot set Sansao prefix !
/bot set Sansao cooldown 1000
/bot set Sansao mod_action warn
/bot set Sansao mod_spam 5
/bot set Sansao mod_flood 8
/bot set Sansao mod_warn \c04\b[Sansao]\o Calma lá, {nickname}. \c05Respeito é bom\o e eu gosto. Segura a onda.
/bot set Sansao greeting none
/bot set Sansao farewell none
/bot set Sansao mention_response \c04\b[Sansao]\o Tô de olho. \c05Sempre de olho\o. Se comportar, a gente se dá bem.

/bot addcmd Sansao regras \c04\b[Sansao]\o Versão curta: \c05não seja babaca\o. Versão longa: não tem versão longa.
/bot addcmd Sansao denuncia \c04\b[Sansao]\o Viu algo estranho? \c05Chama um admin\o. Eu cuido do automático, humano cuida do resto.

/bot join Sansao #brasil
/bot join Sansao #jornal
/bot join Sansao #tecnologia
/bot join Sansao #hardware
/bot join Sansao #programacao
/bot join Sansao #economia
/bot join Sansao #futebol
/bot join Sansao #ciencia
/bot join Sansao #musica
/bot join Sansao #jogos

# ══════════════════════════════════════════════════════════
#  3. Tiao — anfitrião do #brasil
# ══════════════════════════════════════════════════════════
# Boas-vindas por notice privado: o recém-chegado recebe orientação dentro da
# sala sem encher o histórico de todo mundo.
/bot create Tiao Anfitriao do canal brasileiro
/bot set Tiao prefix !
/bot set Tiao cooldown 1000
/bot set Tiao dice_default 1d20
/bot set Tiao greeting \c03\b[Tiao]\o Opa, {nickname}! Eu sou o Tiao. \c02Manda um !salas\o, um !causo ou um !bomdia. Fica à vontade.
/bot set Tiao greeting_delivery private_notice
/bot set Tiao greeter_repeat_window 43200
/bot set Tiao farewell none
/bot set Tiao mention_response \c03\b[Tiao]\o Chamou? Tô aqui. \c02Tenta !salas\o ou !causo.

/bot addcmd Tiao salas \c03\b[Tiao]\o #brasil #jornal #tecnologia #hardware #programacao #economia #futebol #ciencia #musica #jogos — \c02dez salas em português\o, e todas com alguma coisa acontecendo.
/bot addcmd Tiao bomdia \c03\b[Tiao]\o \c02Bom dia\o, {nickname}! Café passado, teclado limpo, dia começando.
/bot addcmd Tiao causo \c03\b[Tiao]\o Tem 13 canais #brasil espalhados pelo IRC hoje, {nickname}. Somados dão 273 pessoas. O maior tem 57. \c02Dá pra fazer melhor\o aqui.
/bot addcmd Tiao ingles \c03\b[Tiao]\o Também tem sala em inglês, {nickname}: \c02#lobby, #tech, #news\o e mais. Troca o idioma na barra de ferramentas quando quiser.

/bot join Tiao #brasil

# ══════════════════════════════════════════════════════════
#  4. Bots de feed — um por canal
# ══════════════════════════════════════════════════════════
# Todo feed aqui foi buscado pelo fetcher de produção e lido pelo parser do app
# antes de virar linha de script. O primeiro poll publica a página que recebe e
# a registra; depois disso só sai o que chegou novo. A lista e o histórico ficam
# no bot, então um deploy não repete o dia.

# ── Nina — #brasil ───────────────────────────────────────
# Sem saudação: quem recebe o recém-chegado nesta sala é o Tiao.
/bot create Nina Reporter de plantao do Brasil
/bot set Nina prefix !
/bot set Nina cooldown 1000
/bot set Nina rss_interval 20
/bot set Nina rss_max_items 10000
/bot set Nina greeting none
/bot set Nina farewell none
/bot set Nina mention_response \c03\b[Nina]\o Eu leio G1 e Agência Brasil. \c02!fontes\o lista os feeds.
/bot addcmd Nina fontes \c03\b[Nina]\o G1 e Agência Brasil, checados \c02a cada vinte minutos\o.
/bot join Nina #brasil
/bot rss add Nina https://g1.globo.com/rss/g1/ #brasil
/bot rss add Nina https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml #brasil

# ── Zeca — #jornal ───────────────────────────────────────
/bot create Zeca Editor da mesa de noticias
/bot set Zeca prefix !
/bot set Zeca cooldown 1000
/bot set Zeca rss_interval 20
/bot set Zeca rss_max_items 10000
/bot set Zeca greeting \c02\b[Zeca]\o Bem-vindo ao #jornal, {nickname}. \c14As manchetes chegam sozinhas\o — !fontes mostra de onde.
/bot set Zeca greeting_delivery private_notice
/bot set Zeca greeter_repeat_window 43200
/bot set Zeca farewell none
/bot set Zeca mention_response \c02\b[Zeca]\o Eu publico o que o feed manda. \c14!fontes\o para a lista, !primeira para entender o começo.
/bot addcmd Zeca fontes \c02\b[Zeca]\o Folha, BBC Brasil e Poder360, checados \c14a cada vinte minutos\o.
/bot addcmd Zeca primeira \c02\b[Zeca]\o A primeira busca de um feed publica a página atual e a registra. Depois disso, \c14só sai matéria nova\o.
/bot join Zeca #jornal
/bot rss add Zeca https://feeds.folha.uol.com.br/emcimadahora/rss091.xml #jornal
/bot rss add Zeca https://www.bbc.com/portuguese/index.xml #jornal
/bot rss add Zeca https://www.poder360.com.br/feed/ #jornal

# ── Bento — #tecnologia ──────────────────────────────────
/bot create Bento Curioso de tecnologia em tempo integral
/bot set Bento prefix !
/bot set Bento cooldown 1000
/bot set Bento rss_interval 30
/bot set Bento rss_max_items 10000
/bot set Bento greeting \c10\b[Bento]\o E aí, {nickname}! \c06Tecnoblog, Canaltech, Olhar Digital e Manual do Usuário\o caem aqui sozinhos. !fontes para a lista.
/bot set Bento greeting_delivery private_notice
/bot set Bento greeter_repeat_window 43200
/bot set Bento farewell none
/bot set Bento mention_response \c10\b[Bento]\o Quatro feeds de tecnologia no fio. \c06!fontes\o mostra quais.
/bot addcmd Bento fontes \c10\b[Bento]\o Tecnoblog, Canaltech, Olhar Digital e Manual do Usuário, checados \c06a cada meia hora\o.
/bot join Bento #tecnologia
/bot rss add Bento https://tecnoblog.net/feed/ #tecnologia
/bot rss add Bento https://canaltech.com.br/rss/ #tecnologia
/bot rss add Bento https://olhardigital.com.br/feed/ #tecnologia
/bot rss add Bento https://manualdousuario.net/feed/ #tecnologia

# ── Juca — #hardware ─────────────────────────────────────
/bot create Juca Garimpeiro de silicio e gambiarra
/bot set Juca prefix !
/bot set Juca cooldown 1000
/bot set Juca rss_interval 60
/bot set Juca rss_max_items 10000
/bot set Juca greeting \c12\b[Juca]\o Chegou junto, {nickname}. \c10Hardware.com.br e Mundo Conectado\o caem aqui. !fontes para os feeds.
/bot set Juca greeting_delivery private_notice
/bot set Juca greeter_repeat_window 43200
/bot set Juca farewell none
/bot set Juca mention_response \c12\b[Juca]\o Placa, fonte, gabinete e gambiarra. \c10!fontes\o lista o fio.
/bot addcmd Juca fontes \c12\b[Juca]\o Hardware.com.br e Mundo Conectado, checados \c10de hora em hora\o.
/bot addcmd Juca upgrade \c12\b[Juca]\o Antes do upgrade, {nickname}: \c10mede o gargalo\o. Trocar a placa por causa de um jogo mal otimizado é dinheiro no lixo.
/bot join Juca #hardware
/bot rss add Juca https://www.hardware.com.br/feed #hardware
/bot rss add Juca https://www.mundoconectado.com.br/feed/ #hardware

# ── Dora — #programacao ──────────────────────────────────
/bot create Dora Leitora de commits alheios
/bot set Dora prefix !
/bot set Dora cooldown 1000
/bot set Dora rss_interval 45
/bot set Dora rss_max_items 10000
/bot set Dora greeting \c06\b[Dora]\o Oi, {nickname}. \c13TabNews e Meio Bit\o chegam sozinhos aqui. !fontes para a lista, !suporte antes de perguntar.
/bot set Dora greeting_delivery private_notice
/bot set Dora greeter_repeat_window 43200
/bot set Dora farewell none
/bot set Dora mention_response \c06\b[Dora]\o TabNews e Meio Bit no fio. \c13!fontes\o lista os dois.
/bot addcmd Dora fontes \c06\b[Dora]\o TabNews e Meio Bit, checados \c13a cada 45 minutos\o.
/bot addcmd Dora suporte \c06\b[Dora]\o Suporte de projeto é com o projeto, {nickname} — quem responde bem é quem mantém. \c13Aqui é conversa\o.
/bot join Dora #programacao
/bot rss add Dora https://www.tabnews.com.br/recentes/rss #programacao
/bot rss add Dora https://meiobit.com/feed/ #programacao

# ── Iara — #economia ─────────────────────────────────────
/bot create Iara Plantonista do mercado
/bot set Iara prefix !
/bot set Iara cooldown 1000
/bot set Iara rss_interval 30
/bot set Iara rss_max_items 10000
/bot set Iara greeting \c11\b[Iara]\o Bem-vindo, {nickname}. \c02InfoMoney, Exame e Valor\o caem aqui. !fontes para a lista.
/bot set Iara greeting_delivery private_notice
/bot set Iara greeter_repeat_window 43200
/bot set Iara farewell none
/bot set Iara mention_response \c11\b[Iara]\o Três feeds de economia no ar. \c02!fontes\o mostra quais.
/bot addcmd Iara fontes \c11\b[Iara]\o InfoMoney, Exame e Valor, checados \c02a cada meia hora\o.
/bot addcmd Iara dica \c11\b[Iara]\o Manchete não é recomendação, {nickname}. \c02Eu leio feed\o, não bola de cristal.
/bot join Iara #economia
/bot rss add Iara https://www.infomoney.com.br/feed/ #economia
/bot rss add Iara https://exame.com/feed/ #economia
/bot rss add Iara https://valor.globo.com/rss/valor/ #economia

# ── Chico — #futebol ─────────────────────────────────────
/bot create Chico Cronista de arquibancada
/bot set Chico prefix !
/bot set Chico cooldown 1000
/bot set Chico rss_interval 20
/bot set Chico rss_max_items 10000
/bot set Chico greeting \c03\b[Chico]\o Salve, {nickname}! \c09ge e Trivela\o no fio. !fontes para a lista, !time se quiser discussão.
/bot set Chico greeting_delivery private_notice
/bot set Chico greeter_repeat_window 43200
/bot set Chico farewell none
/bot set Chico mention_response \c03\b[Chico]\o Bola rolando. \c09!fontes\o lista o que eu leio.
/bot addcmd Chico fontes \c03\b[Chico]\o ge e Trivela, checados \c09a cada vinte minutos\o.
/bot addcmd Chico time \c03\b[Chico]\o Não digo o meu, {nickname}. \c09Bot que escolhe time\o perde metade da sala no primeiro clássico.
/bot join Chico #futebol
/bot rss add Chico https://ge.globo.com/rss/ge/ #futebol
/bot rss add Chico https://trivela.com.br/feed/ #futebol

# ── Lila — #ciencia ──────────────────────────────────────
/bot create Lila Guardia das descobertas
/bot set Lila prefix !
/bot set Lila cooldown 1000
/bot set Lila rss_interval 60
/bot set Lila rss_max_items 10000
/bot set Lila greeting \c13\b[Lila]\o Oi, {nickname}. \c06Superinteressante e Galileu\o chegam de hora em hora. !fontes para a lista.
/bot set Lila greeting_delivery private_notice
/bot set Lila greeter_repeat_window 43200
/bot set Lila farewell none
/bot set Lila mention_response \c13\b[Lila]\o Ciência de divulgação, sem paywall. \c06!fontes\o lista os feeds.
/bot addcmd Lila fontes \c13\b[Lila]\o Superinteressante e Galileu, checados \c06de hora em hora\o.
/bot join Lila #ciencia
/bot rss add Lila https://super.abril.com.br/feed/ #ciencia
/bot rss add Lila https://revistagalileu.globo.com/rss/galileu/ #ciencia

# ── Tuca — #musica ───────────────────────────────────────
/bot create Tuca Discotecaria de plantao
/bot set Tuca prefix !
/bot set Tuca cooldown 1000
/bot set Tuca rss_interval 60
/bot set Tuca rss_max_items 10000
/bot set Tuca greeting \c13\b[Tuca]\o Chegou, {nickname}! \c05POPline e TMDQA\o caem aqui. !fontes para a lista.
/bot set Tuca greeting_delivery private_notice
/bot set Tuca greeter_repeat_window 43200
/bot set Tuca farewell none
/bot set Tuca mention_response \c13\b[Tuca]\o Lançamento, show e briga de fandom. \c05!fontes\o lista o fio.
/bot addcmd Tuca fontes \c13\b[Tuca]\o POPline e Tenho Mais Discos Que Amigos, checados \c05de hora em hora\o.
/bot join Tuca #musica
/bot rss add Tuca https://portalpopline.com.br/feed/ #musica
/bot rss add Tuca https://www.tenhomaisdiscosqueamigos.com/feed/ #musica

# ── Vito — #jogos ────────────────────────────────────────
/bot create Vito Operador do fliperama tupiniquim
/bot set Vito prefix !
/bot set Vito cooldown 1000
/bot set Vito rss_interval 60
/bot set Vito rss_max_items 10000
/bot set Vito greeting \c12\b[Vito]\o Fala, {nickname}! \c10Adrenaline\o no fio, e o menu Games abre 18 clássicos no navegador. !fontes, !jogar.
/bot set Vito greeting_delivery private_notice
/bot set Vito greeter_repeat_window 43200
/bot set Vito farewell none
/bot set Vito mention_response \c12\b[Vito]\o Notícia de jogo eu trago. \c10!jogar\o explica como rodar os clássicos aqui mesmo.
/bot addcmd Vito fontes \c12\b[Vito]\o Adrenaline, checado \c10de hora em hora\o.
/bot addcmd Vito jogar \c12\b[Vito]\o Abre o menu \c10Games\o na barra de cima, {nickname}: DOOM, Quake, Wolfenstein e seis aventuras ScummVM rodando no navegador.
/bot join Vito #jogos
/bot rss add Vito https://www.adrenaline.com.br/feed/ #jogos
```

---

## Verification

```
/bot list
/bot info Sansao
/admin channel list
```

`!Nina rss list` in `#brasil` shows the feeds actually stored on a bot, which is
the check that matters after a paste — a feed the guard refused is missing here
and nowhere else.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#brasil` | **Tiao**, Nina | G1, Agência Brasil |
| `#jornal` | **Zeca** | Folha, BBC Brasil, Poder360 |
| `#tecnologia` | **Bento** | Tecnoblog, Canaltech, Olhar Digital, Manual do Usuário |
| `#hardware` | **Juca** | Hardware.com.br, Mundo Conectado |
| `#programacao` | **Dora** | TabNews, Meio Bit |
| `#economia` | **Iara** | InfoMoney, Exame, Valor |
| `#futebol` | **Chico** | ge, Trivela |
| `#ciencia` | **Lila** | Superinteressante, Galileu |
| `#musica` | **Tuca** | POPline, TMDQA |
| `#jogos` | **Vito** | Adrenaline |

**Sansao** stands in all ten and greets in none of them. All channels are `+tn`.

Poll intervals follow the publisher, not a house default: twenty minutes for a
newsroom, an hour for a monthly-paced magazine. A room that repeats itself reads
as broken faster than a room that is quiet.
