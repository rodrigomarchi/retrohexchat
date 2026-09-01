# Onda 7 — o que a auditoria achou

**Depende de:** ondas 0–6, todas shippadas.

**Entrega:** os achados da auditoria fechados **por consequência, não por
esforço** — começando pelo único que destrói dado do usuário e terminando no que
só envergonha. Menos um: o card ao vivo na conversa é entrega e não conserto, e
sai deste plano com o motivo escrito (§13).

Apagar este arquivo quando a última fase shippar, movendo o que virar regra
durável para os guias **antes**.

---

## 0. De onde isto vem

A auditoria independente está em
[`shareable-surfaces-audit.md`](shareable-surfaces-audit.md), seção **"Resultado
da auditoria"**. Cada item aqui cita o `R.n` de lá, que carrega a evidência
reproduzível — não repito comando que já está escrito.

O desenho contra o qual tudo foi medido foi apagado de propósito no `9620e81b`.
Recupere quando precisar decidir se uma tela está certa:

```sh
mkdir -p /tmp/plan && for f in README ux wave-1-join-resolver wave-5-games-surfaces \
  wave-6-cross-tab-and-bundle; do
  git show 9620e81b^:docs/plans/shareable-surfaces/$f.md > /tmp/plan/$f.md
done
```

`README.md` tem as decisões travadas **P1–P7** e **D1–D6**. Esta onda não reabre
nenhuma delas; ela fecha a distância entre elas e o código.

---

## 1. O que se descobriu escrevendo este plano

A auditoria registrou (R.1) que a reivindicação da vaga é uma escrita dentro do
`mount/3` sem guarda de `connected?/1`, e que o render morto já a executa.
Planejando o conserto, o buraco é maior: **`P2PLive.mount/3` faz duas escritas de
domínio no render morto, não uma.** A segunda é pior que a primeira.

`resolve_session/3` → `enter/4` → `Events.attach_session/5` chama
`Lobby.join_session(token, user_id, takeover: true)`
(`live/p2p_live/events.ex`, `attach_session/5`). Medido:

```
>>> BEFORE: connections: %{peer: nil, creator: nil}, peer_joined: false
>>> AFTER : connections: %{peer: %{pid: #PID<0.644.0>, ref: #Reference<...>}}, peer_joined: true
```

Um `GET` cru de `/p2p/:token` — sem nenhum websocket — **atribui o assento ao
processo da requisição HTTP**, que já morreu quando a resposta saiu. E como o
join é `takeover: true`, isso é o contrato do `ux.md §2.5` disparando:
*"Abrir a mesma sessão em outro lugar a move para lá"*. Ou seja, buscar a URL
desloca a janela que está com a sessão, e o `:DOWN` do processo morto abre em
seguida a janela de graça de reconexão contra ninguém.

Quem busca a URL sem abrir socket: um prefetch especulativo do navegador, uma
extensão, um scanner de link atrás de um proxy autenticado, ou a pessoa
apertando Esc antes do socket abrir.

**Isto move R.1 de "a vaga queima" para "a sessão viva é deslocada por um
prefetch", e é por isso que a Fase A é a primeira.**

Reprodução:

```sh
# ver a seção R.1 da auditoria para o teste da vaga; para o takeover, o mesmo
# molde com Lobby.create_session/2 e :sys.get_state do Lobby.Registry, fazendo
# get(conn, ~p"/p2p/#{token}") e comparando `connections` antes e depois.
```

---

## 2. Fase A — o render morto para de escrever (R.1)

### 2.1 O que muda

`P2PLive.mount/3` passa a ter duas metades explícitas:

* **render morto** — resolve, autoriza e **desenha**. Nenhuma escrita: nem
  `claim_open_session/2`, nem `join_session/3`. É o primeiro paint, e o primeiro
  paint não é um compromisso.
* **mount conectado** — reivindica e entra, exatamente como hoje.

O portão é `connected?(socket)`, e ele vai em `resolve_session/3` (antes de
`take_seat/2`) e em `enter/4` (antes de `attach_session/5`).

### 2.2 A armadilha, que é onde isto dá errado

**`role_of/2` cai em `:peer` por padrão** (`live/app/p2p_live.ex`). Se a
reivindicação for pulada e nada mais mudar, o render morto de um estranho num
lobby aberto desenha a sala como se ele já fosse o par — e o `mount` conectado
depois pode recusá-lo. O primeiro paint estaria mentindo.

Então o render morto precisa de um **terceiro estado**, não de um papel
inventado: "a caminho". Ele desenha a antessala com o assunto (o jogo, o
apelido) e sem os controles que dependem de estar dentro — sem `[Pronto]`, sem
`[Iniciar]`, sem `[Cancelar]`. O mount conectado substitui isso pela sala real
um instante depois, que é exatamente o que um dead render é para fazer.

O mesmo vale para o `CallLive` e o `SpaceLive`: **auditar os três**, porque a
questão não é "este módulo escreve", é "que superfície escreve no `mount/3`".

*Implementado em 2026-08-31 com um desvio: o terceiro estado ficou sendo o
`boot_activity_panel` que o chat já usa no próprio render morto, e não a
antessala com os controles apagados. Motivo e auditoria das quatro superfícies na
Iteração 1 de [`shareable-surfaces-wave-7-progress.md`](shareable-surfaces-wave-7-progress.md).*

### 2.3 E a vaga queimada que já existe

~~`Queries.claim_open_session/3` zera `expires_at` e a varredura só enxerga
`status = "open"`, então uma vaga tomada por engano não volta.~~ **Descartado ao
implementar, 2026-08-31:** a premissa era falsa. `claim_open_session/2` chama
`ensure_session_server/1`, e o `SessionServer` agenda `:pending_expiry` em cinco
minutos no `init` (`lobby/session_server.ex:184`, `:374`) — a linha fecha
sozinha. Pôr um `expires_at` aqui consertaria um problema que não existe e
mexeria numa varredura que está certa.

O que sobra é a consequência real, e ela já está coberta pela §2.1: um prefetch
**mata o link da partida**, porque `open` é o único estado em que ele é seguível
e a máquina só anda para frente. Não sobra linha pendurada; sobra link morto.

---

## 3. Fase B — o read-model para de mentir (R.6)

`Lobby.active_session_for_user/1` devolve a sessão não-terminal mais recente, e
um lobby aberto é não-terminal — então mintar um link de partida enquanto você
está numa sessão P2P viva faz o chat **não reabrir** aquela sessão no próximo
mount (`lobby.ex`, `chat_live/p2p_read_model.ex`).

`active_sessions_for_user/1` tem um único chamador, então a correção é local:
excluir `status = "open"` da query. A cláusula `{"open", _role} -> socket` do
`P2PReadModel.refresh_all/1` fica **morta** e sai junto — deixar as duas é
manter duas respostas para a mesma pergunta.

*Implementado em 2026-08-31, e a cláusula **ficou**: o modo de falha que ela
guarda é silencioso, e duas travas para um erro que não levanta nada são
baratas. Ver a Iteração 2 do diário.*

Teste que prova, e falha se a query voltar: sessão viva + link de partida →
`active_session_for_user/1` devolve a sessão viva. Está escrito em R.6.

---

## 4. Fase C — o que degrada em silêncio (R.10, R.7/R.13)

### 4.1 O `← Chat` diz quando não conseguiu

`back_to_chat/1` monta o `SurfaceTabLinkHook` e não renderiza a nota que o hook
procura, então o primeiro clique com a aba inalcançável não faz nada e não diz
nada (`components/ui/share/surface_tab_link.ex`,
`assets/js/hooks/surfaces/surface_tab_link_hook.js`). A nota entra no
`back_to_chat/1` também.

E o spec que declara cobrir isso asserta `toHaveCount(0)` no caminho em que a aba
**respondeu** (`e2e/tests/surface-cross-tab.spec.ts:53`) — uma asserção que não
pode falhar. Ela é trocada por uma que force o caminho sem resposta: a segunda
aba fecha antes do clique, e o spec espera a nota aparecer.

Sem isso a onda 6 continua com a segunda bullet do "Pronto quando" em aberto:
*"o caso de foco bloqueado degrada com mensagem em vez de silêncio"*.

*Implementado em 2026-08-31, e a nota que faltava era só o primeiro dos quatro
defeitos empilhados nesse clique — o `SurfacePresenceHook` não estava montado em
lugar nenhum, `log.info` não existe, e a nota precisava de `phx-update="ignore"`.
Iteração 3 do [diário](shareable-surfaces-wave-7-progress.md). K5 e K6 verdes.*

### 4.2 A barra de status coberta, e os cinco vermelhos

Dois dos cinco specs vermelhos são o produto: a janela maximizada da chamada
intercepta o ponteiro por cima de `status-bar-group-call` e
`status-bar-p2p-stop`. Com uma chamada aberta no chat, esses controles ficam
visíveis e não clicáveis.

**Esta fase começa por um diagnóstico, não por um conserto.** A auditoria não
determinou se é regressão do plano — `default_maximized` já estava nas duas
janelas antes dele (`git show 3076e54e^:…/chat_live.html.heex`). O primeiro passo
é rodar os dois specs numa revisão pré-plano e saber. Depois:

* se a barra de status pertence ao workspace, ela sai de dentro dele;
* se a janela não pode maximizar sobre ela, o `default_maximized` das duas
  janelas embutidas é o que muda — e aí a §2.6 do `ux.md` (uma janela fixada e
  maximizada) vale para a **satélite**, não para a janela dentro do chat, e isso
  vira uma linha em `guide/windowed-desktop.md`.

*Diagnosticado e resolvido em 2026-08-31, e a §4.2 estava errada: não é
geometria. Os atributos das duas janelas são idênticos antes e depois do plano, e
a barra de status em questão é a do próprio chat, no rodapé da janela do chat —
uma janela maximizada por cima dela é o gerenciador de janelas funcionando. O que
mudou foi o fluxo: o diálogo virou antessala maximizada e abre mais cedo, então o
controle mudou de casa. Os dois specs foram apontados para a casa nova e estão
verdes. A correção está registrada em R.7 da auditoria.*

Os outros três:

| Spec | O que fazer |
|---|---|
| `chat-group-call.spec.ts:1275`, `:1341` | ~~bug de teste~~ — a sondagem morta do `localStorage` saiu, e os dois continuam vermelhos **por produto**: a preferência de dispositivo não sobrevive a cancelar-e-reabrir, e a caixa de aviso de permissão aparece sem texto. Precedem o plano; diagnóstico até onde foi na Iteração 3 do diário |
| `chat-call-fault-injection.spec.ts:355` | **decisão D7.2** — ver §8 |

---

## 5. Fase D — o que vaza (R.3 metade barata, R.4)

### 5.1 A recusa do space para de nomear o canal

`SpaceLive.allowed?/2` responde *"You have to be in %{channel} to enter its
space."* com o nome do canal dentro. O `CallLive` não faz isso — as recusas dele
nunca nomeiam o canal — o que prova que a regra era conhecida e não foi aplicada
aqui. A recusa do space passa a ser a mesma frase sem o nome.

A metade cara — o endereço em si — é a **decisão D7.1** (§8).

### 5.2 As meta tags do `/join/:slug` falam do link

O `JoinLive` atribui só `page_title` e `robots`; o layout monta `og:description`
e `og:image` do texto padrão da landing. O `subject/1` já é exatamente o texto
certo e já respeita a regra de canal privado — ele passa a alimentar também
`page_description`, e o `og:image` ganha uma variante por kind ou fica o padrão.

O teste é o que a onda 1 §2.5 pediu e nunca existiu: abrir `/join/:slug` de uma
sala num canal secreto e asserir que o nome do canal **não** aparece no `<head>`.

*Implementado em 2026-08-31. `listed_channel?/1` virou
`Channels.Visibility.nameable?/1` e os dois lados passaram a chamá-la, em vez de
a regra existir duas vezes. Iteração 4 do diário.*

---

## 6. Fase E — o que apodrece (R.5, A.6, R.8)

### 6.1 Um link por sala, e a `Policy` que a onda 1 pediu

Quatro chamadores de `ShareLinks.create/1`, nenhum com deduplicação nem rate
limit, e `Service.create/1` nunca põe `expires_at`. Recarregar a aba e clicar
Compartilhar de novo cria outro slug para a mesma sala.

* `create/1` passa a **reusar o link vivo** do mesmo `{kind, target, creator}` em
  vez de mintar outro. Isso é o que faz a revogação valer a pena: revogar um
  slug hoje deixaria os irmãos valendo, e ninguém sabe quantos são.
* Nasce `ShareLinks.Policy` — quem pode criar por kind, quem pode revogar. Hoje
  `revoke/2` aceita qualquer `revoked_by` e não verifica nada. A onda 1 §3.1
  pediu `share_links/policy_test.exs` com essas duas perguntas.
* Só então a revogação ganha UI, e **A.6 fecha**: sem a Policy e sem o reuso, um
  botão de revogar seria uma promessa que o domínio não cumpre.

Expiração de link é a **decisão D7.3** (§8).

### 6.2 O convite para de escrever um caminho morto

`lobby_invite.ex` escreve `/lobby/%{token}` em todo convite novo, e
`/lobby/:token` redireciona para `/chat` jogando o token fora. O `@moduledoc`
justifica com *"legacy token resolution"* que **não existe** — ninguém lê aquele
token em lugar nenhum do repositório.

O `msgid` passa a carregar `/p2p/%{token}`, que existe desde a onda 4, e o
controller redireciona para lá em vez de para `/chat`. É um `msgid` traduzido em
13 locales, então o merge é parte da fase e não um depois.

O que **não** entra aqui: `:p2p_invite` virar variante do `:share_card`
(`ux.md §2.1`). Isso depende do card ao vivo existir — §13.

---

## 7. Fase F — o resto, em lote

| Achado | O quê |
|---|---|
| R.9 | ligar `@open_surface_paths` na barra de abas, na zona de status e na nicklist — o mecanismo inteiro já existe e funciona; ver **D7.4** |
| R.14 | `PerfBudgets.html_bytes(:join)` / `dom_nodes(:join)` com o número medido, e o spec "abrir a mesma chamada duas vezes não gera dois participantes" |
| R.12 | os 11 `msgid` do plano traduzidos nos 13 locales; `make i18n.catalog.check` volta a passar |
| R.11 | a frase do `@moduledoc` de `ShareLinks.Slug` para de creditar um rate limit que não existe. Se o rate limit for para existir, é plano próprio |
| R.15 | `check_rate_limit/1` para de dizer "minutes" com um valor em segundos; o catch-all silencioso de `p2p_media_island.ex` passa a logar |

---

## 8. Decisões travadas — respondidas em 2026-09-01

As doze que faltavam, decididas. Duas foram contra a minha recomendação e as
duas na mesma direção: **não construir infraestrutura para uma hipótese.** Isso
é a decisão por trás de Q4 e Q8 e vale escrever como postura, não como dois
acidentes.

| | Pergunta | Decidido |
|---|---|---|
| **Q1** | o card ao vivo (R.2) | **plano próprio, onda 8** — é entrega, não conserto |
| **Q2** | o answerer que recarrega | **consertar, e a ferramenta é o navegador** — spec de Playwright dirigindo o caso, não teoria |
| **Q3** | os dois specs de pré-join | **consertar os dois** |
| **Q4** | o endereço do space | **manter legível** — contra a recomendação |
| **Q5** | link expira? | **não expira**; a revogação é a saída |
| **Q6** | zona de status e nicklist | **status agora**, nicklist junto com o card |
| **Q7** | os 9 `msgid` de outras features | **traduzir e apertar o gate** |
| **Q8** | rate limit de HTTP | **nunca — é problema de borda** — contra a recomendação |
| **Q9** | spec "a mesma chamada duas vezes" | **escrever** |
| **Q10** | os `Process.sleep` do `open_surfaces_test` | **reescrever** |
| **Q11** | hook registrado ≠ hook montado | **checagem no `lint.hooks`** |
| **Q12** | empurrar e limpar | **empurrar agora**; apagar os docs na onda 8 |

### As duas que foram contra a recomendação, escritas como decisão

**Q4 — o endereço do space fica legível.** `/space/<base64(#canal)>` decodifica
com um comando, e isso é aceito de propósito: um id opaco custa tabela,
migração, links quebrados e o contrato do `SpaceRef` com o hook do canvas e
quatro specs, para um vazamento que só existe em canal privado e que a metade
barata já tirou da tela. **Não é esquecimento; é o preço achado justo.** O
`@moduledoc` do `SpaceRef` já diz que é encoding e não segredo — agora diz por
decisão e não por descrição.

**Q8 — rate limit é da borda, não da aplicação.** Não existe em rota nenhuma e
não vai passar a existir aqui. A entropia do slug carrega o argumento sozinha
(31^10 ≈ 8,2×10¹⁴) e o resto é trabalho de CDN ou proxy reverso. Isto fecha
R.11 como decisão em vez de deixá-la como pergunta aberta que volta em toda
auditoria.

### A ordem que essas respostas produzem

1. **Q2 + Q3** — os três specs vermelhos, no navegador (bloco maior).
2. **Q9 + Q10** — os dois specs que faltam e os laços de sleep.
3. **Q6** — a zona de status dizendo onde.
4. **Q7** — traduzir e pôr `i18n.catalog.check` no `make ci`.
5. **Q11** — a checagem de hook montado no `lint.hooks`.
6. **Q4 + Q8** — as duas frases de decisão nos moduledocs.
7. **Q1** — o plano da onda 8, e então apagar estes documentos (Q12).

## 9. TDD

Teste primeiro, como em todas as ondas. As linhas abaixo são as que **não
existem hoje** — as que existem e continuam valendo não estão listadas.

| Camada | Asserção |
|---|---|
| `:liveview` | um `get/2` cru em `/play/:game/:token` **não** reivindica a vaga (Fase A) |
| `:liveview` | um `get/2` cru em `/p2p/:token` **não** anexa conexão nem dispara takeover — `:sys.get_state` do `SessionServer` inalterado |
| `:liveview` | o render morto desenha a antessala sem `[Pronto]`, `[Iniciar]` e `[Cancelar]` |
| `:liveview` | o mesmo `get/2` para `/call/:token` e `/space/:slug` — nenhuma escrita |
| `:integration` | uma vaga reivindicada guarda um `expires_at` e volta pela varredura (D7.1 da Fase A) |
| `:integration` | sessão P2P viva + link de partida → `active_session_for_user/1` devolve a sessão viva |
| `:liveview` | a recusa do space **não** contém o nome do canal |
| `:liveview` | `/join/:slug` de sala em canal secreto: o nome do canal não aparece no `<head>` |
| `:integration` | `create/1` duas vezes com o mesmo `{kind, target, creator}` devolve **um** link |
| `:unit` | `ShareLinks.Policy`: quem cria por kind, quem revoga |
| `:liveview` | a barra de abas renderiza "focar" quando o registro tem a superfície e "abrir" quando não (onda 6 §1.3, nunca escrita) |
| Vitest | o hook mostra a nota quando ninguém responde ao pedido de foco, inclusive no `back_to_chat` |
| Playwright | `← Chat` sem aba que responda mostra a nota (K5, substituindo a asserção vazia) |
| Playwright | abrir a mesma chamada duas vezes não gera dois participantes (A.8) |

Regras da casa que se aplicam inteiras aqui: nunca asserir em `send_update`
assíncrono; `mix assets.build` e matar o servidor em `:4003` antes de qualquer
Playwright; e **reverter o conserto uma vez para ver o teste ficar vermelho** —
metade destes testes é sobre uma escrita que não deve acontecer, e um teste que
afirma ausência é o mais fácil de escrever verde por acidente. Foi exatamente
assim que a asserção do K5 nasceu inútil.

---

## 10. Obrigações do repositório

- [ ] `PerfBudgets` para `:join` (R.14) — é a única página pública do plano.
- [ ] Help topics: a revogação de link é controle acionável, logo é obrigatória
      (`AGENT-GUIDE §12`). "Como eu desfaço um link que compartilhei" é a
      pergunta.
- [ ] i18n: os 11 `msgid` de R.12, mais o `msgid` do convite que muda de caminho
      (§6.2). `extract` + `merge` dos domínios tocados, nunca o rebuild global.
- [ ] `SURFACE.txt` se algum evento novo de LiveView/channel/dataset nascer.
- [ ] `e2e/TEST_CATALOG.md` regenerado — o K5 muda de `@flow`, porque o que ele
      cobre muda.
- [ ] `guide/webrtc-p2p.md`: se a Fase A mudar o contrato de takeover (ela muda
      *quando* ele dispara), o §8.5 muda no mesmo commit.
- [ ] `guide/windowed-desktop.md`: se a §4.2 concluir que a janela embutida não
      maximiza, é uma linha lá.
- [ ] `docs/README.md`: este plano sai da lista "In flight" quando for apagado.
- [ ] `make ci` verde antes de qualquer fase ser considerada fechada.

---

## 11. Riscos

* **O portão de `connected?/1` é fácil de pôr no lugar errado.** Pôr no
  `mount/3` inteiro faz o render morto não desenhar nada, e aí a superfície
  perde o primeiro paint que a onda 0 pagou caro para ter. O portão é sobre a
  **escrita**, não sobre a leitura.
* **Reusar o link vivo muda o que "compartilhar" significa.** Duas pessoas
  compartilhando a mesma sala passam a ver o mesmo endereço; se alguma coisa no
  futuro quiser saber quem compartilhou para quem, o dado deixa de existir.
  Aceitar de propósito, ou guardar o `creator` no reuso.
* **Mexer na barra de status do chat é mexer na tela mais usada do produto.**
  A §4.2 tem cinco specs de chamada e o smoke de chat como rede; rodar os dois
  antes de fechar.
* **O `msgid` do convite muda em 13 locales.** É o caminho conhecido de deixar
  drift de `.pot` que quebra o `make ci` de outra pessoa — extract e merge no
  mesmo commit.
* **A auditoria não verificou Firefox em nada.** Nenhuma fase aqui muda
  transporte, mas a §4.2 mexe em geometria de janela, que é onde o Firefox
  costuma divergir.

---

## 12. Pronto quando

- [ ] `make ci` verde — 17/17, Dialyzer incluído.
- [ ] Nenhum `mount/3` de superfície escreve no domínio no render morto, provado
      por `get/2` nas quatro superfícies.
- [ ] Uma vaga tomada por engano volta sozinha.
- [ ] O chat reabre a sessão P2P viva de quem tem um link de partida aberto.
- [ ] Os cinco specs vermelhos estão verdes, ou `fixme` com a limitação escrita e
      linkada — nenhum vermelho permanente, nenhum `skip` mudo.
- [ ] A recusa do space e o `<head>` do `/join` não nomeiam canal privado.
- [ ] Compartilhar duas vezes a mesma sala devolve o mesmo endereço, e existe uma
      `Policy` que diz quem revoga.
- [ ] O convite P2P escreve um caminho que funciona.
- [ ] A barra de abas e a zona de status dizem "em outra aba".
- [ ] As quatro decisões da §8 estão respondidas **no próprio arquivo**, com o
      porquê — uma decisão tomada e não escrita é uma decisão que se reabre.
- [ ] A seção "Resultado da auditoria" tem, ao lado de cada `R.n`, o commit que o
      fechou.

---

## 13. O que esta onda **não** faz

**O card ao vivo na conversa (R.2) não está aqui, e não é esquecimento.**

Ele é uma entrega, não um conserto: três kinds × dois estados, contagem de
participantes vinda do summary, `[Copiar link]`, os cards terminais com a
próxima ação plausível, e a assinatura de space com cancelamento por
visibilidade — que a própria onda 1 marcou como o único custo novo de tráfego do
plano inteiro. É `P3`, uma decisão de produto travada, desenhada no `ux.md §2.1`
com estados que ninguém desenhou de novo desde então.

Misturar isso com uma onda de conserto faria as duas piores: a onda de conserto
demoraria semanas e o card sairia como o menor denominador de uma lista de bugs.
Ele merece o mesmo tratamento que as ondas 1–6 tiveram — um arquivo, um
desenho conferido contra o `ux.md` recuperado, e uma tabela de TDD.

Também ficam de fora, com razão escrita:

| Não feito | Razão |
|---|---|
| Endereço opaco de space | **D7.1** — decisão, não conserto; precisa do número de spaces privados em produção |
| Rate limit de HTTP | R.11 diz que a entropia sozinha resolve. Um rate limit de rota pública é infraestrutura e merece plano próprio |
| Guest pass | `D1` do `README` do plano original: muda moderação, ban e superfície de abuso |
| `:p2p_invite` virar `:share_card` | depende do card ao vivo existir |
| A nicklist marcando quem está na chamada | **D7.4** — vai junto com o card, que lê o mesmo summary |
