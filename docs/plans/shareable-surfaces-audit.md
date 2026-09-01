# Handover — auditar o plano de superfícies compartilháveis

Escrito em 2026-08-31 **por quem fez o trabalho**, para uma sessão que vai
auditá-lo com o contexto zerado. Apagar quando a auditoria fechar e os achados
dela virarem issues ou commits.

---

## Resultado da auditoria — 2026-08-31, sessão independente

Escrito por quem **não** fez o trabalho, com o contexto zerado, contra os 11
arquivos do plano recuperados do `9620e81b^` (§1.3). Nada foi consertado: a
auditoria diagnostica e para, e a ordem de conserto proposta está no fim.

O que está abaixo desta seção é o handover e **não foi editado** — a diferença
entre o que o autor achou e o que esta passada achou é ela mesma um dado.

### R.n → o commit que fechou

Fechado em 2026-09-01. Cada linha aponta para o commit onde o achado deixou de
existir; os dois marcados como decisão fecharam sem código, com o porquê escrito
no `@moduledoc` do módulo que a auditoria acusou.

| | Achado | Fechado por |
|---|---|---|
| R.1 | um `GET` queima a vaga | `a266b7be` (a vaga), `2704d8db` (a varredura) |
| R.2 | o card não é ao vivo | **onda 8** — é entrega, não conserto (Q1) |
| R.3 | o space publica o canal privado | `b2868f2e` (a recusa), `2704d8db` (as metas) |
| R.4 | nenhuma meta tag é do link | `b2868f2e` |
| R.5 | cada Share cria um link novo | `aa58a947` |
| R.6 | o link mascara a sessão viva | `a266b7be` |
| R.7 | a janela cobre a barra de status | `b2868f2e` — e o diagnóstico estava errado; ver a correção na própria seção |
| R.8 | a justificativa do `default_maximized` | `b2868f2e` |
| R.9 | só o popover soube das abas | `2704d8db` (tira de abas), `11fc201e` (zona de status) |
| R.10 | o `← Chat` degrada em silêncio | `b2868f2e` |
| R.11 | o argumento do slug e o rate limit | `2704d8db` (o texto), decisão Q8 no `@moduledoc` do `Slug` |
| R.12 | os `msgid` vazios | `2704d8db` (os 10 do plano), `05785b47` (os 30 que sobravam, e o gate) |
| R.13 | os cinco specs vermelhos | `2704d8db` (dois), `cbab23f9` (os três, com três causas erradas corrigidas) |
| R.14 | `PerfBudgets` e o spec que faltava | `2704d8db` (orçamento), `7836824b` (o spec K7) |
| R.15 | os dois defeitos pequenos | `2704d8db` |

E o achado que a auditoria não fez: **`SurfacePresenceHook` estava registrado e
montado em lugar nenhum**, junto com outros cinco. Virou checagem em `973004a0`.

---

### R.0 O veredito curto

O Apêndice A estava certo em oito de oito, e é um piso baixo. Fora dele há
**quinze** achados, e os dois maiores não são bugs de código: são entregas
declaradas fechadas que não existem — o **card ao vivo na conversa** (P3, uma
decisão de produto travada) e o **estado "em outra aba"** na barra de abas, na
zona de status e no menu (ux.md §2.7, onda 6 §1.2). As duas ondas onde o ritual
de conferir a tabela linha por linha nunca rodou — 1 e 6 — são exatamente onde
elas estão. O diagnóstico do autor sobre si mesmo (§4.4) se confirma.

O achado com maior consequência operacional é **R.1**: um `GET` simples em
`/play/:game/:token` queima a vaga da partida, e a vaga queimada nunca volta.
Está provado com um teste, abaixo.

Em compensação, a metade que o autor apostou que estaria quebrada — as duas
movimentações grandes de 5bb4091e e 725de14b — está **limpa** nas quatro classes
de defeito que ele listou (§2, passo 2). Isso também está medido.

---

### R.1 Um `GET` em `/play/:game/:token` queima a vaga, e ela nunca volta — ALTA

`P2PLive.mount/3` chama `resolve_session/3` → `take_seat/2` → `claim_seat/2`, que
é uma **escrita no banco**, sem nenhuma guarda de `connected?/1`
(`apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/p2p_live.ex:54`, `:262`,
`:290`). O `mount/3` de um LiveView roda duas vezes, e a primeira é o render
morto de uma requisição HTTP comum. Então quem apenas **busca a página** já
tomou o assento — um prefetch do navegador, uma extensão, um scanner de link
atrás de um proxy autenticado, ou a pessoa apertando Esc antes do socket abrir.

Pior: `Queries.claim_open_session/3` zera `expires_at`
(`apps/retro_hex_chat/lib/retro_hex_chat/lobby/queries.ex:61`), e a varredura de
expiração só enxerga linhas `status = "open"` (`:87-93`,
`open_and_expired/2`). Uma vaga queimada assim **não é recuperada por nada** a
não ser o passe de 24 h de registros velhos: o link da partida fica morto com
ninguém dentro.

> **Correção, 2026-08-31, escrita ao implementar a onda 7.** O parágrafo acima
> está errado na segunda metade, e o texto errado fica aqui de propósito. A
> linha **é** recuperada: `claim_open_session/2` chama `ensure_session_server/1`,
> e o `SessionServer` agenda `:pending_expiry` em cinco minutos no `init`
> (`lobby/session_server.ex:184`), fechando a sessão que ainda estiver `pending`
> (`:374`). Eu li a query da varredura e não o servidor, e a varredura era a
> única coisa que eu tinha olhado — então foi a única que pôde me responder.
>
> O que sobra é pior escrito assim, e é o achado de verdade: um prefetch **mata
> o link da partida**, porque `open` é o único estado em que ele é seguível e a
> máquina só anda para frente (`open → pending → expired`). Não deixa lixo no
> banco; deixa o link morto. A primeira metade — a escrita no render morto —
> está confirmada, e ao implementar apareceu uma segunda escrita pior: ver a
> Iteração 1 de [`shareable-surfaces-wave-7-progress.md`](shareable-surfaces-wave-7-progress.md).

Reprodução (roda, imprime, e passa):

```sh
cat > apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/zz_probe_test.exs <<'EOF'
defmodule RetroHexChatWeb.App.ZzProbeTest do
  use RetroHexChatWeb.LiveViewCase, async: false
  @moduletag :liveview
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.{NickServ, RegisteredNick}

  defp reg(p) do
    n = "#{p}#{uid()}" |> String.slice(0, 16)
    {:ok, nick} = %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: n, password: "password123"})
      |> RetroHexChat.Repo.insert()
    NickServ.restore_identified(nick.nickname)
    on_exit(fn -> NickServ.remove_identified(nick.nickname) end)
    nick
  end

  test "the dead render already burns the seat", %{conn: conn} do
    host = reg("ZHost"); guest = reg("ZGuest")
    {:ok, %{session: s}} = Lobby.create_open_session(host.id, metadata: %{"game_id" => "hex_pong"})
    assert {:ok, %{status: "open", peer_id: nil}} = Lobby.get_session(s.token)

    # a bare HTTP GET — no websocket is ever opened
    resp = conn |> chat_conn(guest.nickname) |> get(~p"/play/hex_pong/#{s.token}")
    assert resp.status == 200

    {:ok, after_get} = Lobby.get_session(s.token)
    IO.puts("\n>>> status=#{after_get.status} peer_id=#{inspect(after_get.peer_id)} expires_at=#{inspect(after_get.expires_at)}")
    assert after_get.peer_id == guest.id
    assert after_get.status == "pending"
    assert is_nil(after_get.expires_at)
  end
end
EOF
mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/zz_probe_test.exs
rm apps/retro_hex_chat_web/test/retro_hex_chat_web/live/app/zz_probe_test.exs
```

Saída medida: `>>> status=pending peer_id=956379 expires_at=nil`.

**O que foi prometido:** onda 5 §6 — *"O teste de reivindicação concorrente
passa, e falha se a escrita condicional virar `read → check → write`"*. A escrita
condicional está certa (`queries.ex:77-83`, com `WHERE peer_id IS NULL AND status
= 'open' AND not expired`) e o teste de concorrência existe. Ninguém perguntou
**de onde** a chamada sai. E o `README §6` manda a superfície *carregar* o dado
inicial no `mount/3`; o código transformou isso em *escrever* nele.

**Por que os testes não pegam:** `live/2` sempre conecta, então o `mount`
conectado corrige o do render morto (`take_seat` casa em `peer_id: user_id`) e o
efeito fica invisível. Só um `get/2` cru mostra.

**Custo do conserto:** pequeno. Reivindicar só com `connected?(socket)` — no
render morto o `take_seat` devolve a sessão sem escrever, e a antessala aparece
igual — mais o teste de `get/2` acima como regressão.

---

### R.2 O card na conversa não é ao vivo, não tem estado terminal e não tem contagem — ALTA

`RetroHexChatWeb.Components.UI.ShareMessageCard` tem 69 linhas e desenha: um
ícone, um nome, `"shared by X"` e **um** botão `[Join]`
(`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/share/share_message_card.ex:17-42`).
Ele nunca lê `@card.live?`. Não há indicador de estado, não há roster, não há
contagem, não há `[Copiar link]`, e não há variante encerrada — um link para uma
chamada que acabou continua oferecendo `[Join]`, que é o beco que o desenho
proíbe por escrito.

E ele não é ao vivo em nenhum sentido: é calculado uma vez, no pipeline que
decora as mensagens da tela (`message_viewport.ex:411 put_share_cards/1`), sem
nenhuma assinatura. A assinatura de space que a onda 1 exigia **não existe**:

```sh
grep -rn "Topics.space\b\|Topics\.space(" apps/*/lib | grep -v priv/gettext   # só o SpaceLive
grep -n "live?" apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/share/share_message_card.ex  # vazio
sed -n '410,425p' apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/message_viewport.ex
```

Um efeito colateral disso é pior que um card cinza: `describe_many/1` **filtra
fora** os links revogados e expirados (`share_links/service.ex:96`), então um
link revogado não fica cinza — o card simplesmente **some** do histórico.

**O que foi prometido, e onde está escrito:**

* `README §3 P3` — decisão de produto travada: *"O card na conversa é ao vivo.
  Participantes e estado atualizam sozinhos; ao acabar, o card fica cinza e
  oferece a próxima ação plausível, nunca um beco."*
* `ux.md §2.1` — três kinds com `● AO VIVO` / `● 7 dentro` / `○ AGUARDANDO`,
  a linha de participantes, os dois botões, e os dois estados terminais
  (`○ ENCERRADA` "durou 42 min · 5 participantes" → `[ Abrir #retro ]`;
  `○ TERMINOU` "ana venceu bob" → `[ Jogar Hex Pong ]`).
* `wave-1 §2.4` — a tabela "o que mantém o card vivo, por kind", incluindo a
  assinatura nova de space.
* `wave-1 §3.3` — a tabela de TDD, três linhas dela: *"estado encerrado: cinza,
  sem `[Entrar]`, **com** a próxima ação"*; *"contagem de participantes reflete o
  summary passado, e muda quando ele muda"*; *"o chat assina o tópico
  `space:#canal` ao renderizar um card de space daquele canal, e **cancela**
  quando o último card sai de vista"*.

Nenhuma das três tem teste, porque nenhuma das três tem código.

**Custo do conserto:** grande — é uma entrega, não um bug. Estado terminal +
`[Copiar link]` + contagem a partir do summary que o `ChatLive` já mantém é a
metade barata; a assinatura de space com cancelamento por visibilidade é a cara,
e é a que a própria onda 1 marcou como o único custo novo.

---

### R.3 O endereço do space publica o nome do canal privado que o card esconde — MÉDIA

`SpaceRef.slug/1` é `Base.url_encode64` do id do space
(`apps/retro_hex_chat_web/lib/retro_hex_chat_web/space_ref.ex:26`). O id é o nome
do canal, ou `dm:<a>:<b>`.

```sh
python3 -c "import base64; print(base64.urlsafe_b64encode(b'#diretoria').decode().rstrip('='))"
# I2RpcmV0b3JpYQ   ->  /space/I2RpcmV0b3JpYQ
python3 -c "import base64; print(base64.urlsafe_b64encode(b'dm:alice:bob').decode().rstrip('='))"
# ZG06YWxpY2U6Ym9i -> /space/ZG06YWxpY2U6Ym9i
```

O `JoinLive` cuida do nome com precisão no corpo do card — `space_name/1` só
nomeia o canal quando `listed_channel?/1` (`join_live.ex:224-240`) — e então
`surface_path/1` põe o mesmo nome, codificado, no `href` do botão `[Entrar]`
(`join_live.ex:284`). Quem vê "A space on RetroHexChat" lê `#diretoria` no
próprio botão. Vale para qualquer visitante **com sessão**, membro ou não.

E a recusa termina de contar: `SpaceLive.allowed?/2` responde
*"You have to be in %{channel} to enter its space."* com o nome do canal dentro
(`live/app/space_live.ex`, ramo `mode: "channel"`). O `CallLive` não faz isso —
as recusas dele nunca nomeiam o canal (`call_live.ex:303-330`), o que mostra que
a regra era conhecida e não foi aplicada aqui.

**O que foi prometido:** `ux.md §2.2` — *"Canal público aparece; canal privado
vira 'Uma chamada no RetroHexChat'"*; `wave-1 §2.5` — *"o preview não revela nome
de canal privado… Isto é um teste, não um comentário"*. O `@moduledoc` do
`SpaceRef` chega a dar o motivo certo (*"a channel name a stranger reads off an
address bar names a channel they may not be allowed to know exists"*) e conclui,
na frase seguinte, que decodificar é trivial e proposital — ou seja, o módulo
sabe do vazamento e o documenta como aceitável, contra o `ux.md`.

**Custo do conserto:** médio para o endereço (um id opaco por space, com
mapeamento persistido — é uma tabela nova); **pequeno** para a metade barata:
tirar o nome do canal da mensagem de recusa, como o `CallLive` já faz.

---

### R.4 A.5 confirmado, e maior: nenhuma meta tag é específica do link — MÉDIA

Confirmado e a causa é mais simples do que o Apêndice A supõe. O `JoinLive`
atribui só `page_title` e `robots` (`live/join_live.ex:37-44`); o layout monta
`og:title` de `page_title`, `og:description` do texto **padrão da landing** e
`og:image` da imagem padrão (`components/layouts/landing_live.html.heex:11-14`,
`:60-70`). Não é que a regra de privacidade não chegou às meta tags: **nada**
do link chega. O `subject/1`, que é exatamente o texto certo e já respeita a
regra, alimenta só o corpo.

```sh
grep -n "page_description\|page_title\|robots" apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/join_live.ex
grep -n "og:title\|og:description\|og:image\"" apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/layouts/landing_live.html.heex
```

**Custo:** pequeno — `assign(page_description: …)` a partir do `subject/1` que já
existe, e um teste que abra `/join/:slug` de um canal secreto e asserte que o
nome do canal não aparece no `<head>`.

---

### R.5 Cada clique em Share cria um link novo; nada limita, deduplica ou expira — MÉDIA

Quatro chamadores de `ShareLinks.create/1` (`call_live.ex:200`,
`space_live.ex:257`, `p2p_live.ex:282`, `play_live.ex:183`), nenhum com
deduplicação e nenhum com rate limit. `Service.create/1` não põe `expires_at`
(`share_links/service.ex:30-34`), então todo link mintado vale para sempre.
A `ShareBar` esconde o botão depois de mintar, mas o `share_url` é um assign:
recarregar a aba e clicar de novo cria outro slug para a mesma sala.

Isso é o que torna **A.6 pior do que ele se descreve**: mesmo que a revogação
ganhasse UI, ela revoga *um* slug — os irmãos da mesma sala continuam valendo, e
ninguém sabe quantos são.

```sh
grep -rn "ShareLinks.create" apps/*/lib
grep -rn "ShareLinks.revoke" apps/*/lib | grep -v '/test/'   # vazio: A.6 confirmado
ls apps/retro_hex_chat/lib/retro_hex_chat/share_links/       # não existe policy.ex
```

**O que foi prometido:** `README §3 P6` — *"Se todo `Retro Games` aberto gerasse
um `share_link` no banco, a tabela vira lixo em uma semana"* (a preocupação
estava certa e a mitigação escolhida — nascer de um botão — não cobre o clique
repetido); `wave-1 §3.1` — um `share_links/policy_test.exs` com *"quem pode criar
por kind; quem pode revogar (criador + op do canal)"*; `wave-1 §3.2` — *"rate
limit de criação dispara e libera"*. **Não existe `ShareLinks.Policy`**, e
`revoke/2` aceita qualquer `revoked_by` sem verificar nada
(`share_links/service.ex:104-116`).

**Custo:** pequeno-médio — reusar o link vivo do mesmo `{kind, target, creator}`
em vez de criar outro, e a `Policy` que a onda 1 pediu.

---

### R.6 Um link de partida mascara a sessão P2P viva de quem o criou — MÉDIA

`Lobby.active_session_for_user/1` devolve a sessão não-terminal mais recente
(`lobby.ex:183`), e um lobby aberto é não-terminal. O `P2PReadModel.refresh_all/1`
trata `{"open", _role}` devolvendo o socket intacto — corretamente, porque um
link que ninguém tomou não é uma sessão em que você está
(`chat_live/p2p_read_model.ex:48-56`). O problema é o **primeiro** passo: se você
está numa sessão P2P viva e minta um link de partida, o link é o mais recente, o
read-model para nele, e a janela P2P **não reabre** no próximo mount ou
reconexão.

Reprodução (roda, imprime, e passa):

```sh
cat > apps/retro_hex_chat/test/retro_hex_chat/lobby/zz_probe_test.exs <<'EOF'
defmodule RetroHexChat.Lobby.ZzProbeTest do
  use RetroHexChat.DataCase, async: false
  @moduletag :integration
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Service
  alias RetroHexChat.P2P.{RateLimiter, RateLimitTable}
  alias RetroHexChat.Services.RegisteredNick

  defp nick(n) do
    {:ok, r} = %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: n, password: "password123"})
      |> Repo.insert()
    RateLimiter.reset(RateLimitTable.table_name(), r.id)
    r
  end

  test "a match link masks the running session" do
    a = nick("auditprobea"); b = nick("auditprobeb")
    {:ok, %{session: real}} = Service.create_session(a.id, b.id)
    assert Lobby.active_session_for_user(a.id).token == real.token
    {:ok, %{session: open}} = Service.create_open_session(a.id, metadata: %{"game_id" => "hex_pong"})
    got = Lobby.active_session_for_user(a.id)
    IO.puts("\n>>> real=#{real.status} open=#{open.status} returned=#{got.status}")
    assert got.token == open.token
  end
end
EOF
mix test apps/retro_hex_chat/test/retro_hex_chat/lobby/zz_probe_test.exs
rm apps/retro_hex_chat/test/retro_hex_chat/lobby/zz_probe_test.exs
```

Saída medida: `>>> real=pending open=open returned=open`.

**O que foi prometido:** o `@moduledoc` do próprio `P2PReadModel` — *"Anything
further along reopens the surface, because the session server owns that fact and
a reload must not look like an ending"*; `ux.md §2.5` — *"Quem chega depois do
início não volta para a sala: uma sessão que já está correndo entrega a
superfície direto"*.

**Custo:** mínimo — excluir `status: "open"` de `active_sessions_for_user/1`
(ou pular os abertos em `refresh_all/1`), mais o teste acima.

---

### R.7 A janela de chamada maximizada cobre a zona de status do próprio chat — MÉDIA

Dois dos cinco specs vermelhos de A.2 **não são bug de teste**: são o produto. O
Playwright não consegue clicar em `status-bar-group-call` nem em
`status-bar-p2p-stop` porque a janela maximizada da chamada intercepta o
ponteiro por cima deles:

```
- element is visible, enabled and stable
- <div id="group-call" … data-window-default-maximized="true" …> subtree intercepts pointer events
```
(`/tmp/aud/e2e_a2.log`, falhas 2 e 5; reproduza com o comando de A.2)

Ou seja: com uma chamada aberta no chat, os controles da barra de status do chat
ficam visíveis e **não clicáveis**. O usuário clica e nada acontece.

**O que não consegui verificar:** se isto é regressão do plano. `default_maximized`
nessas duas janelas **precede** o plano — `git show 3076e54e^:…/chat_live.html.heex
| grep -n default_maximized` mostra as duas linhas já lá. Se o que mudou foi a
geometria por causa do `live_render` intermediário, eu não determinei: isso
exigiria dar checkout numa revisão pré-plano e rodar os specs, e eu não fiz.

**Custo:** desconhecido até diagnosticar; a barra de status precisa ficar acima
do workspace de janelas, ou a janela não pode maximizar sobre ela.

> **Correção, 2026-08-31, escrita ao implementar a onda 7.** O enquadramento
> acima está errado e o texto errado fica aqui. Não é geometria: os atributos das
> duas janelas são idênticos antes e depois do plano, e a barra de status em
> questão é a do **próprio chat**, no rodapé da janela do chat (`:status` slot,
> `chat_live.html.heex:87`) — uma janela maximizada por cima dela é como um
> gerenciador de janelas funciona, não um defeito.
>
> O que mudou foi o **fluxo**: `/p2p <nick>` abria um diálogo e o pré-join era um
> diálogo; os dois viraram a antessala dentro de uma janela fixada e maximizada,
> que abre mais cedo. Os specs clicavam num controle do chat num momento em que
> ele deixou de estar alcançável, e a capacidade não sumiu — mudou de casa
> (`p2p-room-cancel`, o `[Cancelar]` do P7). **Os dois specs foram apontados para
> onde o controle está e estão verdes.** Custo real: uma linha em cada um.
>
> Eu chamei de "produto, não teste" com base no log do Playwright e não fui olhar
> onde o elemento morava. Ver a Iteração 3 de
> [`shareable-surfaces-wave-7-progress.md`](shareable-surfaces-wave-7-progress.md).

---

### R.8 A.3 confirmado, e a justificativa dele é falsa — MÉDIA

Todo convite P2P **novo** escreve `/lobby/%{token}` no texto da PM
(`chat_live/helpers/lobby_invite.ex:89`), e `/lobby/:token` redireciona para
`/chat` jogando o token fora (`controllers/app/lobby_redirect_controller.ex:11`).
O `@moduledoc` justifica assim: *"The `/lobby/<token>` path stays embedded in the
text for legacy token resolution"* (`lobby_invite.ex:7`). **Não existe nenhuma
resolução legada de token:**

```sh
grep -rn "lobby/" apps/*/lib apps/retro_hex_chat_web/assets/js | grep -v priv/gettext
# router (o redirect), o moduledoc, o próprio msgid, e três hooks de nome parecido. Ninguém lê o token.
```

**O que foi prometido:** `wave-1 §2.4` — *"hoje ele carrega `/lobby/<token>` no
texto … e passa a carregar `/join/:slug`"*; `wave-1 §6` — *"`/lobby/:token` legado
resolve para `/join/:slug` quando possível"*; `ux.md §2.1` — *"O convite P2P de
hoje passa a ser uma variante desse card, não um segundo componente"* (e
`:p2p_invite` continua sendo um tipo próprio em
`components/ui/chat/message_row.ex:123`).

**Custo:** pequeno no código (`/p2p/%{token}`, que existe desde a onda 4, e o
controller redirecionando para lá), com a ressalva de que é um `msgid` traduzido
em 13 locales.

---

### R.9 A.7 confirmado, e maior: só o popover soube das abas abertas — MÉDIA

`@open_surface_paths` tem **um** consumidor dentro do chat, e ele está dois
cliques fundo, no popover do badge de chamada:

```sh
grep -rn "open_surface_paths" apps/retro_hex_chat_web/lib | grep -v priv/gettext
grep -rn "surface_tab_link" apps/retro_hex_chat_web/lib | grep -v priv/gettext
grep -n "chat_shell_status" apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex
grep -n "conference\|call" apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/nicklist.ex   # vazio
```

O botão da aba `[☎ Chamada]` continua com `phx-click="group_call_open"` e sem
nenhum estado novo (`components/ui/group_call/channel_badge.ex:35-56`); o
`chat_shell_status` recebe só `p2p_session` e `group_call`
(`chat_live.html.heex:88`); a nicklist não tem nenhuma marca de chamada; a
taskbar e o menu Games não conhecem `open_surface_paths`.

**O que foi prometido:** `ux.md §2.7`, as duas primeiras bullets — *"A aba
`[☎ Chamada]` na barra ganha um estado novo: **"em outra aba"**, com a ação
`Focar` em vez de `Abrir`"* e *"A nicklist marca quem está na chamada — dado que
o summary já carrega"*; `wave-6 §1.2` — *"A taskbar e o menu Games/Call passam a
mostrar o estado real"* e *"o `chat_shell_status` … agora ele diz **onde**"*;
`wave-6 §1.3`, linha `:liveview` — *"a taskbar renderiza 'focar' quando o registro
tem a superfície"* (não existe esse teste, porque não existe esse
comportamento); e `wave-6 §4`, segunda bullet do "Pronto quando".

**Custo:** médio. O mecanismo inteiro já existe e funciona (`OpenSurfaces`,
`surface_tab_link`, o hook, o `tab_registry`) — falta ligá-lo nos três lugares
que o desenho nomeia.

---

### R.10 O `← Chat` degrada em silêncio, e o spec que diz cobrir isso não pode falhar — MÉDIA

`surface_tab_link/1` renderiza a nota `<p data-surface-tab-note>` que o hook
mostra quando nenhuma aba responde ao pedido de foco
(`components/ui/share/surface_tab_link.ex:62-72`). `back_to_chat/1` monta **o
mesmo hook** e não renderiza nota nenhuma (`:99-107`). O hook procura a nota em
`this.el.parentElement` e, não achando, não faz nada
(`assets/js/hooks/surfaces/surface_tab_link_hook.js:50-53`): o primeiro clique em
`← Chat` com a aba do chat inalcançável não faz **nada** e não diz nada. (O
segundo clique segue o `href` — e aí abre um segundo chat, que é exatamente o
takeover que o `@moduledoc` do componente diz existir para evitar.)

E o spec que declara cobrir isso asserta a ausência da nota **no caminho em que a
aba respondeu**:

```
e2e/tests/surface-cross-tab.spec.ts:3   @flow K5 … and says so when no tab answers
e2e/tests/surface-cross-tab.spec.ts:53  await expect(playTab.getByTestId("play-back-to-chat-note")).toHaveCount(0);
```

Essa asserção passaria idêntica se a nota fosse apagada do repositório inteiro —
o que, para o `back_to_chat`, é o estado atual. É a forma exata que o §2 passo 3
descreve: *"`refute` na frente de um helper que espera uma coisa aparecer"*.

**O que foi prometido:** `wave-6 §4` — *"o caso de foco bloqueado degrada com
mensagem em vez de silêncio"*; `wave-6 §1.1`, passo 3 do contrato.

**Custo:** mínimo — renderizar a nota também no `back_to_chat`, e trocar a
asserção do K5 por uma que force o caminho sem resposta.

> **Corrigido em 2026-08-31, e era três defeitos e não um.** Além da nota que
> faltava: **`SurfacePresenceHook` não estava montado em template nenhum**, então
> nada jamais respondeu a um pedido de foco — a metade de "focar a aba existente"
> da onda 6 §1.1 nunca rodou; e **`log.info` não existe** (`lib/logger.js` é um
> `Object.freeze({debug, error, warn})`), então a linha de log antes de
> `_note("true")` lançava um `TypeError` dentro de um `.then` e comia o resto do
> callback em silêncio. Mais um quarto achado ao consertar: a nota é estado de
> servidor que o JS muta, e precisava de `phx-update="ignore"` para sobreviver ao
> próximo patch. Os quatro estão consertados e o K5 agora prova o caminho sem
> resposta. Ver a Iteração 3 do diário.

---

### R.11 O argumento de segurança do slug se apoia num rate limit que não existe — BAIXA

O `@moduledoc` de `ShareLinks.Slug` calcula a entropia e conclui: *"31^10 … which
at a thousand guesses a second **against a rate-limited public route** is not a
strategy"* (`share_links/slug.ex:11-16`). A onda 1 §5 diz o mesmo: *"a resolução
tem rate limit por IP como qualquer rota pública"*. **Não existe rate limit de
HTTP em lugar nenhum deste app** — nem no endpoint, nem em pipeline, nem em plug:

```sh
grep -rn "RateLimit\|Hammer\|throttle\|ExRated" apps/*/lib | grep -v priv/gettext | grep -vi "join throttle\|flood"
grep -n "plug " apps/retro_hex_chat_web/lib/retro_hex_chat_web/endpoint.ex
```

O único limitador do repositório é o `P2P.RateLimiter` em ETS, por `user_id`, e
ele não cobre rota pública nenhuma.

**Avaliação honesta:** a entropia sozinha já resolve. O espaço é 31¹⁰ ≈ 8,2×10¹⁴;
com 10⁴ links vivos, achar *qualquer* um custa ~10¹¹ tentativas em média —
enumerar não é viável nem sem limite nenhum. O
defeito é a **justificativa escrita**, que credita um controle inexistente — e
uma frase assim é como um requisito de segurança some numa refatoração futura.

**Custo:** uma frase, ou o rate limit de verdade.

---

### R.12 A.1 confirmado, e o número é maior — BAIXA

`make i18n.catalog.check` reprova no `HEAD` (exit 2). Por locale: **11** msgids
vazios em `help.po` e **8** em `help_games.po`, nos 13 locales — não "~10 msgids"
no total. Do plano são 11 deles:

* `help.po`: `own tab`, `share a game` (`chat/help_topics/features.ex:1749-1750`);
* `help_games.po`: as nove entradas de
  `controllers/help_content/feature_retro_games.html.heex` (linhas 19, 38, 41,
  47, 53, 60, 63, 69, 75) — as seções "Playing in Its Own Tab" e "Sharing a Game".

O resto é deriva de bots/greeter/link-cards/thumbnails, de outras pessoas — a
atribuição do autor está correta.

**Verificado e descartado:** `share.po`, o domínio novo do plano, tem 4 entradas
`fuzzy` em todos os locales, o que faz `ready < translated`. Isso **não** é uma
falha visível ao usuário: o Gettext do Elixir usa traduções fuzzy em runtime.
Medido — `Gettext.dgettext(RetroHexChatWeb.Gettext, "share", "This link is no
longer active. The chat is still there.")` com `locale = pt_BR` devolve
`"Este link não está mais ativo. O chat continua lá."`.

---

### R.13 A.2 confirmado exatamente, com um diagnóstico diferente — MÉDIA-ALTA

Rodado com o comando de A.2: **32 passam, 5 falham**, os cinco nomeados. As
causas se dividem em três, e só uma delas é bug de teste:

| Spec | Causa |
|---|---|
| `chat-group-call.spec.ts:1275` e `:1341` (pré-join) | ~~**bug de teste**~~ — **corrigido 2026-08-31, e eu repeti o erro do autor.** A sondagem morta do `localStorage` era real e saiu; os dois continuam vermelhos por baixo dela, e por motivos de **produto**: a preferência de dispositivo não é lembrada entre cancelar e reabrir, e a caixa de aviso de permissão aparece sem texto. Ambos precedem o plano. Diagnóstico até onde foi na Iteração 3 do diário. — **Verdes em 2026-09-01, e as duas frases acima estavam erradas sobre a causa.** O aviso não "aparece sem texto": o hook escreve classe e texto e o patch seguinte do LiveView repinta o template por cima, seis milissegundos depois — falta `phx-update="ignore"`. E a preferência não "vai para o registro de dispositivo confiável": esse registro exige um dispositivo lembrado, `remember_device` é `false` por padrão e `trusted_device_nicks` está **vazia**, então nem o caminho do `[Entrar]` jamais persistiu. Sondas e correções na Iteração 7 do diário |
| `chat-group-call.spec.ts:967` e `chat-p2p.spec.ts:888` | ~~**produto**: a janela maximizada cobre a barra de status — R.7~~ **Corrigido 2026-08-31:** specs desatualizados, apontando para um controle que mudou de casa. Verdes. Ver a correção em R.7 |
| `chat-call-fault-injection.spec.ts:355` | ~~**produto**: a mídia não se restabelece quando o answerer recarrega. É a "Limitação registrada" da onda 4B, registrada como limitação enquanto o spec a asserta como comportamento~~ — **verde em 2026-09-01.** Não era uma limitação: eram **três defeitos empilhados** (o resume olhando para o status errado, o pedido de restart olhando para o mesmo status errado, e a metade do servidor do protocolo de prontidão do `AGENT-GUIDE` §15 que nunca foi escrita para o `LobbyWebRTCHook`), mais um quarto criado ao consertar os três. Iteração 7 do diário |

**Não verifiquei** se os cinco já estavam vermelhos antes do plano: isso exige
dar checkout numa revisão pré-plano e rodar, e eu não fiz.

**Fechado em 2026-09-01:** os cinco estão verdes. As cinco suítes de chamada
juntas dão 44/44. O padrão que atravessa as três linhas desta tabela é o mesmo
que a §4 do handover descreve: **cada causa que eu escrevi aqui a partir de
leitura estava errada, e cada uma que veio de uma sonda no navegador estava
certa.**

---

### R.14 A.4 e A.8 confirmados — BAIXA

`/join/:slug` continua sem orçamento (`grep -n "html_bytes(:" …/perf_budgets.ex`
lista `:connect :help :chat :play :call :space :p2p` — sem `:join`), e
`surface-cross-tab.spec.ts` cobre K5 e K6 e nada de "abrir a mesma chamada duas
vezes não gera dois participantes" (onda 6 §1.3, linha Playwright).

---

### R.15 Dois defeitos pequenos que precedem o plano — BAIXA

Achados no caminho, e "todo erro encontrado é meu":

* `Lobby.Service.check_rate_limit/1` interpola segundos numa string que diz
  minutos: *"Try again in %{minutes} minutes"* recebe `remaining_seconds`
  (`lobby/service.ex`, `p2p/rate_limiter.ex:42-43`). Erra por 60×. Introduzido em
  `b9033b05`.
* `p2p_media_island.ex:324` — `defp media_event(socket, _name, _params), do: socket`
  é um catch-all silencioso que come qualquer evento de mídia não previsto,
  contra a regra "No silent catch" do `AGENTS.md`. Introduzido em `e1dd7b62`.

---

## R.16 O que eu verifiquei e **não** virou achado

Isto é metade do valor de uma auditoria e por isso está escrito.

* **Os dois commits grandes estão limpos nas quatro classes que o §2 passo 2
  lista.** Nenhum nome de evento ficou órfão em nenhuma das duas movimentações:

  ```sh
  # todo handle_event do HEAD, com clausulas multi-linha
  perl -0777 -ne 'while (/def handle_event\(\s*"([a-z0-9_:.-]+)"/gs){print "$1\n"}' \
    $(find apps -name '*.ex' -path '*/lib/*') | sort -u > /tmp/head.ev
  git show 725de14b^:apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex \
    | perl -0777 -ne 'while (/def handle_event\(\s*"([a-z0-9_:.-]+)"/gs){print "$1\n"}' | sort -u > /tmp/old.ev
  comm -23 /tmp/old.ev /tmp/head.ev   # só p2p_setup_accept e p2p_setup_cancel, removidos com o markup
  ```

  O mesmo para `group_call_events.ex` contra `5bb4091e^`: conjunto vazio. E
  nenhum evento de template sem handler em lugar nenhum do app — as 24 exceções
  do grep ingênuo são todas despachadas por prefixo ou por dispatcher.
* **Ids duplicados entre os dois hosts:** tratado de propósito. O
  `GroupCallConfirmDialog` é renderizado pelos dois com ids distintos
  (`CallLive` usa `GroupCallConfirmDialog.id/0`, o chat usa
  `ChatLive.GroupCallEvents.confirm_dialog_id/0`), e o `@moduledoc` explica por quê.
* **`App.ReturnTo`** é sólido: rejeita `//`, `\`, `..`, URL absoluta, e só
  descasca segmentos de locale que o router registra de fato. Está aplicado nos
  dois lugares que importam (`connect_live.ex:46,59` e
  `session_controller.ex:125`). O `LocaleController.safe_return_to/1` é mais
  fraco (não rejeita `\`), mas o `Phoenix.Controller.redirect/2` recusa `\`
  sozinho (`deps/phoenix/lib/phoenix/controller.ex`, `@invalid_local_url_chars`) —
  vira 500, não open redirect.
* **A reivindicação concorrente é uma escrita condicional de verdade**, com a
  condição repetida no `WHERE` e a expiração junto (`lobby/queries.ex:77-83`), e
  `Policy.can_claim?/2` respeita bloqueio/ignore como a onda 5 exigia.
* **O `OpenLobbyExpiryWorker` existe, está agendado** (`config/config.exs:58,69`
  — `@reboot` e `*/5 * * * *`) **e é instrumentado** com `Observability.span` e
  metadados de resultado, como o `AGENT-GUIDE §17` pede.
* **O portão do `[Iniciar]` é reconferido no servidor** e não só desabilitado no
  HTML (`p2p_live/events.ex:428-445` chama `room_can_start?/1`), e só o criador
  tem a cláusula.
* **`/join/:slug` está registrado sob todos os segmentos de locale** e tem teste
  disso (`router.ex:66-77`, `join_live_test.exs:156-174`) — a lição da iteração 7
  foi aprendida.
* **`/join/:slug` nunca conecta o LiveSocket** (a landing só o arranca ao tocar
  na janela Connect), então `Queries.record_resolution/1` conta uma vez por
  visita e não duas. Eu suspeitei do contrário e estava errado.
* **O componente `p2p_starting_room` é testado com `room`/`setup` montados à mão,
  mas o pareamento com o produtor está coberto** pelos testes de LiveView, que
  renderizam a sala a partir dos assigns reais (`play_match_test.exs:77-134`,
  `p2p_live_test.exs:158-224`). O suspeito do §2 passo 3 não se confirmou aqui.
* **`SURFACE.txt`, `TEST_CATALOG.md` e os tópicos de ajuda estão em dia**;
  nenhum template `feature_*.html.heex` órfão; os símbolos da onda 0
  (`RetroGamesIsland`, `RetroGamesEvents`, `ArcadeSessionHook`) sumiram de fato.
* **`RetroHexChat.Surfaces` é um GenServer único, global**, e todo mount de
  superfície faz 2–3 `GenServer.call` nele. É o mesmo formato do gargalo já
  medido do NickServ, mas o volume é ordens de grandeza menor e eu não tenho
  medição — registro como coisa a vigiar, não como achado.

## R.17 O que eu **não** consegui verificar

* Se os cinco specs vermelhos já estavam vermelhos antes do plano (exigiria
  checkout de revisão pré-plano + execução; não fiz).
* Se R.7 é regressão do plano ou geometria pré-existente (mesmo motivo).
* Firefox, em qualquer coisa: a suíte aqui roda `--project=chromium`.
* Qualidade das 44+ traduções escritas à mão — li placeholders, não o texto.
* Acessibilidade além de um spot-check dos componentes novos (rótulos presentes,
  a nota do `surface_tab_link` é `display:none` e não fica lida por leitor de
  tela). Não rodei nenhuma ferramenta.
* Performance real: li orçamentos estáticos, não medi nada em navegador.

## R.18 Ordem de conserto proposta

Por consequência, não por esforço.

1. **R.1** — a vaga queimada no render morto. É o único achado que destrói dado
   do usuário e é o mais barato de consertar.
2. **R.6** — o link de partida mascarando a sessão viva. Duas linhas e um teste.
3. **R.10** — a nota do `← Chat` e o spec vazio do K5.
4. **R.7 / R.13** — diagnosticar a barra de status coberta, e depois decidir os
   cinco vermelhos: consertar os dois de teste, e abrir o do answerer como
   limitação conhecida ou como bug.
5. **R.3 (metade barata)** + **R.4** — tirar o nome do canal da recusa do
   `SpaceLive`, e pôr o `subject/1` nas meta tags.
6. **R.8** — o convite parar de escrever `/lobby/<token>`.
7. **R.5** — reusar o link vivo em vez de criar outro, e a `Policy` que a onda 1
   pediu (que é o que faz a revogação de A.6 valer a pena construir).
8. **R.9** — ligar `open_surface_paths` na barra de abas, na zona de status e na
   nicklist.
9. **R.2** — o card ao vivo. É a entrega maior e deve ser o próprio plano, não
   um item de conserto.
10. **R.11, R.12, R.13(a), R.14, R.15** — o resto, em lote.

**Nada disto foi consertado.** Peça o que quiser que eu ataque e em que ordem.

---

## 0. Leia isto antes de qualquer outra coisa

**Este arquivo não é a auditoria.** É o handover para ela. Quem o escreveu é a
parte interessada, e isso tem duas consequências que você precisa carregar até o
fim:

1. **Eu enquadrei o que você vai olhar.** Tudo que está aqui é o que eu
   *consegui pensar em* verificar. O que eu não pensei em procurar não está
   nesta lista, e é exatamente onde o próximo defeito está. Se você tratar o
   Apêndice A como checklist, você vai confirmar oito coisas e parar.
2. **A auditoria que eu fiz é rasa e eu digo exatamente quanto** (§3). Uma
   camada mecânica: arquivo existe, comando roda, teste passa. **Não** li o diff
   de nenhum dos 28 commits, não avaliei se os testes asseguram a coisa certa,
   não revisei corretude de domínio nem superfície de abuso.

O plano tinha um ritual — *conferir a tabela de TDD linha por linha antes de
dizer que fechou* — que nasceu na onda 5 porque a onda 4 foi declarada fechada
com 11 de 13 linhas. Esse ritual **nunca foi aplicado às ondas 0 a 4**. É a
maior razão para esta auditoria existir.

---

## 1. O que foi construído, em fatos verificáveis

Seis "ondas", 28 commits, entre 2026-08-28 e 2026-08-31. O objetivo declarado:
tirar conferência, space, P2P e jogos de dentro da aba única do `/chat` e dar a
cada um **URL própria e compartilhável, sem duplicar implementação**.

### 1.1 O que existe agora

| Superfície | Endereço | Módulo | Também renderizado no chat? |
|---|---|---|---|
| conferência | `/call/:token` | `App.CallLive` | sim, `live_render` |
| space | `/space/:slug` | `App.SpaceLive` | sim |
| sessão P2P | `/p2p/:token` | `App.P2PLive` | sim |
| partida | `/play/:game/:token` | `App.P2PLive`, aberto no jogo | sim |
| jogos solo | `/play`, `/play/:game` | `App.PlayLive` | sim |
| arcade | `/play/arcade/:game` | `App.ArcadeGameController` (redirect) | — |
| card público | `/join/:slug` | `JoinLive` (pipeline landing) | — |

Domínios novos ou alterados: `RetroHexChat.ShareLinks` (novo),
`RetroHexChat.Surfaces` (novo), `RetroHexChat.Lobby` (status `open`, `peer_id`
nulo, reivindicação por escrita condicional, job de expiração).

```sh
grep -nE 'live "/(play|call|space|p2p)|get "/(play/arcade|join|lobby)' \
  apps/retro_hex_chat_web/lib/retro_hex_chat_web/router.ex
ls apps/retro_hex_chat/lib/retro_hex_chat/share_links* apps/retro_hex_chat/lib/retro_hex_chat/surfaces.ex
```

### 1.2 Os 28 commits, e quanto cada um dá de leitura

O `--stat` cru engana: os catálogos `.po` inflam tudo. A coluna da direita é o
diff **sem** `priv/gettext`, `TEST_CATALOG.md` e `SURFACE.txt` — o que você de
fato precisa ler.

| Commit | Onda | Alega | Linhas a ler |
|---|---|---|---|
| `3076e54e` | 0 | uma segunda aba deixa de matar a primeira; `Live.Surface`; `/play/:game` | 3.647 |
| `f0898719` | 1 | `ShareLinks`, `/join/:slug`, `App.ReturnTo` | 1.808 |
| `ba197d38` | 1 | o card na conversa | 527 |
| `b33e0963` | 1 | traduções do card | (só catálogo) |
| `7dc8245a` | 2 | `App.GroupCallShape` extraído | 732 |
| `0b665bb2` | 2 | read-model de canal separado | 536 |
| `5bb4091e` | 2 | `CallLive` em dois hosts, `/call/:token` | **4.286** |
| `8bf8b202` | 2 | filiação por contagem de superfícies | 664 |
| `6b66872f` | 3 | `SpaceLive`, `/space/:slug` | 2.237 |
| `58c8fde5` | 4A | sinalização P2P vira Phoenix Channel | 1.278 |
| `725de14b` | 4B | `P2PLive`, `/p2p/:token`, sala de partida, takeover | **4.805** |
| `04f8575f` | 4B | o portão de identificação | 651 |
| `ecf42368` | 5 | lobby aberto no domínio | 1.051 |
| `de125b99` | 5 | partida com endereço, card "vaga preenchida", arcade por âncora | 1.620 |
| `b250d292` | 6 | o chat sabe quais abas você tem | 1.399 |
| `2a3c9382` | 6 | copiar em qualquer tela; bundle e Start menu decididos | 241 |
| `891fed7d` `9620e81b` `9c5b9209` `44ec3391` | 6 | docs, apagar o plano, esta auditoria | ~1.100 |
| 8 commits `docs(plan)` | — | handovers intermediários | (só docs) |

Os dois maiores — `5bb4091e` e `725de14b` — são onde eu apostaria o dinheiro:
são movimentações grandes de código entre processos, exatamente a operação em
que um comportamento se perde sem que nada quebre em compilação nem em teste.

### 1.3 O plano em si está no git, e você vai precisar dele

Os 11 arquivos foram apagados de propósito no `9620e81b` (as regras duráveis
foram para os guias antes). São a **fonte da verdade sobre o que foi prometido**:

```sh
mkdir -p /tmp/plan && for f in README ux HANDOVER PROGRESS \
  wave-0-identity-and-surfaces wave-1-join-resolver wave-2-conference-surface \
  wave-3-space-surface wave-4-p2p-channel-and-surface wave-5-games-surfaces \
  wave-6-cross-tab-and-bundle; do
  git show 9620e81b^:docs/plans/shareable-surfaces/$f.md > /tmp/plan/$f.md
done
```

- `README.md` — as decisões travadas: **P1–P7** (produto) e **D1–D6**
  (arquitetura). Cada onda tinha de obedecê-las.
- `ux.md` — **o desenho de todas as telas.** É contra este arquivo que se mede
  se a tela construída é a tela decidida.
- `wave-*.md` — cada uma termina com "Obrigações do repositório" e "Pronto
  quando". São as listas que a auditoria existe para conferir.
- `PROGRESS.md` — 24 iterações, com os erros. Útil para saber onde o autor já
  sabia que estava pisando em ovos.

---

## 2. Como auditar sem herdar o meu enquadramento

Ordem sugerida, do que eu **não** fiz para o que eu fiz. Se você inverter, vai
gastar o tempo confirmando o que já está confirmado.

### Passo 1 — leia o `ux.md` antes do código

É o desenho, e ele é anterior a mim. Para cada tela desenhada, abra a tela real
(`make server`, ou um spec Playwright descartável com screenshot) e pergunte:
*isto é o que está desenhado?* O Apêndice A.7 é um exemplo de coisa desenhada e
não construída que só apareceu porque alguém comparou os dois.

### Passo 2 — leia os diffs dos dois commits grandes

`5bb4091e` (conferência) e `725de14b` (P2P). Procure a classe de defeito que
este plano produziu quatro vezes e que **nenhum teste pega**:

- markup movido para outro processo que continua empurrando o nome de evento
  antigo (o clique não faz nada, nada quebra);
- `id` literal duplicado quando os dois hosts renderizam o mesmo componente;
- assign lido no host que deixou de existir depois da mudança;
- `handle_info` catch-all comendo mensagem de que alguém depende.

```sh
git show 5bb4091e -- ':!*/priv/gettext/*' | less
git show 725de14b -- ':!*/priv/gettext/*' | less
```

### Passo 3 — audite os testes, não o código

O plano tem ~150 testes novos. A pergunta não é se passam; é **o que eles
asseguram**. Suspeitos por construção:

- testes que constroem o caminho do mesmo jeito que o código constrói (foi
  exatamente assim que `/pt-BR/join/…` deu `NoRouteError` com 16 testes verdes);
- asserções em `render/1` depois de saltos assíncronos, que o gate reprova em
  paralelo e passa local;
- `refute` na frente de um helper que espera uma coisa aparecer — passa no
  instante em que a coisa ainda está lá;
- testes de componente que passam um `room`/`summary` montado à mão que já não
  corresponde ao que o produtor real devolve.

### Passo 4 — a superfície de abuso, que ninguém revisou de fora

O plano criou **endereços públicos e um assento que qualquer um com o link
ocupa**. Perguntas que nenhum teste deste plano faz:

- `/join/:slug` é enumerável? O slug é opaco — quanto de entropia? Há rate limit
  em `/join`?
- Um link de `call`/`space` mintado hoje vale para sempre? (Ver A.6 — não há
  revogação com UI.)
- `/p2p/:token` e `/call/:token` aceitam token de outra pessoa e recusam
  corretamente **antes** de qualquer efeito colateral?
- O lobby aberto tem `expires_at` curto e rate limit de criação — mas o **card
  público** de um link de partida revela algo sobre quem criou?

### Passo 5 — o que o `make ci` não cobra

O gate passa 17/17 e isso prova menos do que parece:

| Não está no gate | Consequência |
|---|---|
| Playwright | 5 specs vermelhos atravessaram o plano inteiro (A.2) |
| cobertura de `.po` traduzido | ~10 msgids do plano em inglês nos 13 locales (A.1) |
| `i18n.catalog.check` | reprova no `HEAD` e ninguém vê |
| `surface_snapshot.sh --check` | reprovou por deriva alheia em três ondas |
| qualquer coisa visual | nenhum dos 10 defeitos de tela do diário apareceria |

### Passo 6 — só então, o Apêndice A

Confirme ou derrube os meus oito. **Tratá-los como o escopo é o erro.**

---

## 3. O que eu já auditei, e em que profundidade

Honestidade sobre o alcance, para você não repetir nem confiar demais:

| Camada | Cobri? | Como |
|---|---|---|
| Existência: rota, módulo, migração, worker, tópico de ajuda | ✅ | grep e `ls` |
| Contagens: linhas dos adaptadores, símbolos mortos | ✅ | `wc -l`, grep por símbolo |
| `make ci` | ✅ | 17/17 com Dialyzer, três execuções |
| Suítes ExUnit | ✅ | domínio e web verdes |
| Playwright das superfícies | ✅ | 7 specs do plano verdes; os 5 antigos vermelhos |
| Chamador fora de teste para APIs novas | ✅ | achou A.6 |
| Catálogos `.po` do plano | ✅ | achou A.1 |
| **Diff dos 28 commits** | ❌ | não abri nenhum |
| **Qualidade de asserção dos testes** | ❌ | contei, não li |
| **Corretude de domínio** (política, estados, concorrência além do teste que escrevi) | ❌ | — |
| **Superfície de abuso / segurança** | ❌ | — |
| **Acessibilidade** das telas novas | ❌ | — |
| **Qualidade das traduções** que eu escrevi à mão | ❌ | escrevi e conferi placeholders; ninguém leu |
| **Performance real** (só orçamentos estáticos) | ❌ | — |
| **Comparação tela a tela contra `ux.md`** | parcial | só onde eu tirei screenshot |

---

## 4. Onde o autor é estruturalmente não confiável

Escrito por mim sobre mim, e é a parte que eu usaria para decidir onde cavar.

1. **"Verificado com `git stash`: não é meu."** Verdadeiro em seis ondas
   seguidas, e o resultado é A.2: cinco testes que ninguém nunca foi dono. A
   frase é honesta e o efeito é abandono.
2. **Item de checklist tratado como item de commit.** As obrigações foram
   cumpridas quando estavam no caminho do que eu construía e esquecidas quando
   não estavam — A.1 e A.4 são exatamente isso.
3. **Confundir "a lógica existe" com "a lógica é usada".** A.5 e A.6 têm a mesma
   forma: o teste de unidade passa e o produto não tem a capacidade. Grep por
   chamador fora de teste é o antídoto, e está no Apêndice B.
4. **Declarar fechado lendo o diário em vez da tabela.** Corrigido a partir da
   onda 5; as ondas 0–4 nunca passaram por isso, e é lá que os achados se
   concentram.
5. **Eu escolho o que medir.** As duas decisões "medidas" da onda 6 (bundle,
   Start menu) foram medidas por mim, com a métrica que eu escolhi. A conclusão
   pode estar certa e o recorte errado — confira o recorte, não a aritmética.
6. **O screenshot pega o que está feio, não o que não existe.** Nenhum dos oito
   achados apareceria numa captura de tela.

---

## Apêndice A — o que eu já encontrei (piso, não teto)

Oito. Sete achados nesta auditoria rasa; um estava marcado `[ ]` na onda 0 e
nunca voltou. **Nenhum deles aparece no diário do plano como pendência.**

Se a sua auditoria terminar com estes oito e mais nada, ela falhou — porque a
minha, que é rasa e enviesada, já os tinha.

### A.1 ~10 `msgid` do plano ainda em inglês nos 13 locales — média

Dívida assumida na onda 0 (*"precisa do venv de Argos Translate"*) e nunca paga.
As ondas 5 e 6 traduziram 44+ msgids à mão, o que desmente a justificativa.

Do plano: `help` → `own tab`, `share a game`; `help_games` → as oito frases das
seções "Playing in Its Own Tab" e "Sharing a Game" de
`feature_retro_games.html.heex`. (As outras entradas vazias são deriva de
bots/RSS/scraper, de outras pessoas.)

```sh
make i18n.catalog.check 2>&1 | grep -E "help(_games)?\.po.*empty=[1-9]"
```

### A.2 Cinco specs de Playwright entraram vermelhos na onda 2 e saíram vermelhos na onda 6 — média-alta

Medido em 2026-08-31: **32 passam, 5 falham** — os mesmos cinco que o handover
da onda 2 já listava. Duas são **bug de teste**: o helper procura uma chave
`rhc:group-call:prejoin:` no `localStorage` que não existe em lugar nenhum do
repositório. Diagnosticado na iteração 13, não consertado.

```sh
cd e2e && MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 \
  E2E_BASE_URL=http://localhost:4003 BASE_URL=http://localhost:4003 \
  PUBLIC_ORIGIN=http://localhost:4003 \
  npx playwright test tests/chat-group-call.spec.ts tests/chat-p2p.spec.ts \
    tests/chat-call-fault-injection.spec.ts --retries=0 --project=chromium
```

### A.3 Todo convite P2P escreve `/lobby/<token>`, que ignora o token — média

`LobbyRedirectController` manda para `/chat`. `/p2p/:token` existe desde a onda
4. A onda 1 listou em "Pronto quando" e ficou como estava.

```sh
grep -n "lobby/%{token}" apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/lobby_invite.ex
cat apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/app/lobby_redirect_controller.ex
```

### A.4 `/join/:slug` não tem orçamento de payload — baixa

A única página pública do plano é a única superfície sem `PerfBudgets`.

```sh
grep -n "html_bytes(:" apps/retro_hex_chat_web/test/support/perf_budgets.ex
```

### A.5 A prévia social de um link é o card genérico do site — média

Medido: `og:title` = `Join - RetroHexChat`, `og:description` e `og:image` = os da
landing. Nada sobre o que foi compartilhado. A regra de privacidade do `ux.md`
§2.2 (canal público aparece, canal privado vira "Uma chamada no RetroHexChat")
existe em `JoinLive.subject/1` e **só alimenta o corpo do card na página** —
nunca chegou às meta tags, que são a superfície para a qual a regra foi escrita.

### A.6 `ShareLinks.revoke/2` não tem chamador fora de teste — média

A onda 5 conta com revogação como mitigação de abuso do lobby aberto
(*"revogação pelo criador (onda 1 já dá isso)"*). Não há UI. Atenuante: para
partida, `[Cancelar]` mata o link por consequência; para `call`, `space` e
`play` solo, um link mintado vale enquanto a sala viver — e um space nunca acaba.

### A.7 A barra de abas e a zona de status não dizem "em outra aba" — baixa

Desenhado no `ux.md` §2.7 e pedido na onda 6 §1.2; não construído.
`open_surface_paths` tem 5 consumidores, todos links que abrem aba.

### A.8 Falta o spec "abrir a mesma chamada duas vezes não gera dois participantes" — baixa

Pedido na onda 6. `surface-cross-tab.spec.ts` cobre `← Chat` e copiar.

---

## Apêndice B — comandos

```sh
# gate (ler "Results:", nunca o exit code de um pipe)
mix format && make i18n.gettext.extract && make ci > /tmp/ci.log 2>&1; echo $?
grep "Results:" /tmp/ci.log | tail -1                    # 17/17

# código que devia ter sumido, por SÍMBOLO
grep -rn "RetroGamesIsland\|RetroGamesEvents\|ArcadeSessionHook" apps e2e   # vazio
wc -l apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/{group_call_events,p2p_session_events}.ex
# 298 e 460 (eram 2.603 e 2.258)

# API criada pelo plano que ninguém chama fora de teste
for f in "ShareLinks.revoke" "describe_many" "Surfaces.count" "Surfaces.list"; do
  echo "$f -> $(grep -rn --include='*.ex' --include='*.heex' -- "$f" apps \
    | grep -v 'def \|@spec\|defdelegate\|@doc\|/test/' | wc -l)"
done

# todo template de ajuda tem tópico registrado
for f in apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/feature_*.html.heex; do
  id=$(basename $f .html.heex | sed 's/_/-/g')
  grep -q "id: \"$id\"" apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/*.ex || echo "ÓRFÃO: $id"
done

# snapshot de superfície JS e catálogo de e2e
cd apps/retro_hex_chat_web/assets && ./scripts/surface_snapshot.sh --check
make e2e.catalog && git diff --exit-code e2e/TEST_CATALOG.md

# onde as regras duráveis foram parar (conferir que a mudança foi real)
wc -l docs/guide/surfaces.md                                  # 268, §19
grep -n "^## 19\." docs/guide/surfaces.md                     # sete seções
grep -n "surfaces.md" AGENTS.md docs/README.md docs/AGENT-GUIDE.md
grep -n "Six reserved first segments" docs/AGENT-GUIDE.md     # §16
grep -n "7.0 Satellites" docs/guide/windowed-desktop.md
grep -n "one app entry" docs/reference/ci-pipeline.md
```

---

## Apêndice C — o que foi deliberadamente não feito

Para não gastar tempo re-litigando o que tem razão escrita:

| Não feito | Razão, e onde ela está |
|---|---|
| Entry `surface.js` separada | `reference/ci-pipeline.md` — economizaria 14,3% e custaria no caminho comum |
| Start menu nas satélites | `guide/windowed-desktop.md` §7.0 — +177 nós × 4 telas, com teste |
| Guest pass | D1 no README do plano: merece plano próprio, com moderação e ban |
| Migração de host na sala de partida | P7: sala que dura minutos; a recuperação certa é criar outra |
| Prontidão persistida em `metadata` | um reload invalida; persistir criaria segundo dono do fato |
| Suíte P2P em Firefox | Playwright/Firefox: `Unknown permission: microphone` |
| Aba do arcade contada ou focada | outra origem: sem LiveView e fora do `BroadcastChannel` (`guide/surfaces.md` §19.4) |
