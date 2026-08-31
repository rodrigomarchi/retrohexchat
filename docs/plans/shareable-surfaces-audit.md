# Auditoria — superfícies compartilháveis

Escrito em 2026-08-31, depois que as seis ondas do plano
`docs/plans/shareable-surfaces/` foram declaradas fechadas e o diretório
apagado (commit `9620e81b`).

**Este documento não é um resumo.** Um resumo repetiria as afirmações de quem
fez o trabalho, que é exatamente o que não serve para auditá-lo. Aqui está: a
lista de obrigações reconstruída **dos arquivos do plano no git**, o comando que
prova ou desmente cada uma, e — a parte que importa — **o que está faltando**.

Quem retomar isto: leia a §1, rode a §2, e depois vá direto para a §4. A §3 é
consulta.

---

## 1. Como usar este documento

O plano tinha 11 arquivos e 24 iterações de diário. Foram apagados de propósito
(as regras duráveis foram para os guias primeiro), mas continuam no git:

```sh
git show 9620e81b^:docs/plans/shareable-surfaces/README.md
git show 9620e81b^:docs/plans/shareable-surfaces/PROGRESS.md
git show 9620e81b^:docs/plans/shareable-surfaces/wave-5-games-surfaces.md
# etc. — 9620e81b^ é o último commit em que o diretório existia
```

Para recuperar todos de uma vez:

```sh
mkdir -p /tmp/plan && for f in README ux HANDOVER PROGRESS \
  wave-0-identity-and-surfaces wave-1-join-resolver wave-2-conference-surface \
  wave-3-space-surface wave-4-p2p-channel-and-surface wave-5-games-surfaces \
  wave-6-cross-tab-and-bundle; do
  git show 9620e81b^:docs/plans/shareable-surfaces/$f.md > /tmp/plan/$f.md
done
```

**A regra de ouro desta auditoria:** cada linha da §3 e da §4 tem um comando.
Se um comando não estiver escrito, a linha não vale nada — foi uma opinião
minha, e é aí que a próxima coisa esquecida vai estar.

---

## 2. A verificação em quinze minutos

```sh
# 1. O gate. Ler a linha "Results:", nunca o exit code de um pipe.
mix format && make i18n.gettext.extract && make ci > /tmp/ci.log 2>&1; echo $?
grep "Results:" /tmp/ci.log | tail -1        # esperado: 17/17

# 2. As rotas que o plano criou existem e são as que ele prometeu.
grep -nE '"/(join|call|space|p2p|play)' apps/retro_hex_chat_web/lib/retro_hex_chat_web/router.ex

# 3. O código que devia ter sumido, por SÍMBOLO (nunca por nome de arquivo).
grep -rn "RetroGamesIsland\|RetroGamesEvents\|ArcadeSessionHook" apps e2e   # esperado: vazio
wc -l apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/group_call_events.ex \
      apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex
# esperado: 298 e 460 (eram 2.603 e 2.258)

# 4. Os catálogos: entradas do plano ainda em inglês nos 13 locales.
#    Ver §4.1 — este é o achado que mais durou escondido.
make i18n.catalog.check 2>&1 | grep -E "help(_games)?\.po.*empty=[1-9]"

# 5. Os testes de navegador que o plano carregou como vermelhos do começo ao fim.
cd e2e && MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 \
  E2E_BASE_URL=http://localhost:4003 BASE_URL=http://localhost:4003 \
  PUBLIC_ORIGIN=http://localhost:4003 \
  npx playwright test tests/chat-group-call.spec.ts tests/chat-p2p.spec.ts \
    tests/chat-call-fault-injection.spec.ts --retries=0 --project=chromium
# medido em 2026-08-31: 32 passam, 5 falham. Ver §4.2.
```

Se 1 e 3 passarem e 4 e 5 falharem como descrito, esta auditoria está correta e
atualizada. Se 4 ou 5 mudaram, alguém mexeu depois — reveja a §4.

---

## 3. O que foi entregue, e o comando que prova

Uma linha por obrigação escrita nas seis ondas. **Verdade** significa que o
comando ao lado confirma; não significa que eu gostei do resultado.

### 3.1 As rotas e as superfícies

| Prometido | Estado | Como conferir |
|---|---|---|
| `/join/:slug` público, no laço de locales | ✅ | `grep -n "join/:slug" .../router.ex` — duas ocorrências, uma delas dentro do `for locale_segment` |
| `/call/:token`, `/space/:slug`, `/p2p/:token` | ✅ | `grep -n "live \"/" .../router.ex` |
| `/play`, `/play/:game`, `/play/:game/:token` | ✅ | idem |
| `/play/arcade/:game` antes de `/play/:game/:token` | ✅ | `arcade_game_controller_test.exs`, teste "the arcade route wins over the match route it looks like" |
| `/lobby/:token` legado resolve para o lugar certo | ❌ | **§4.3** |
| Um módulo, dois pontos de montagem (D2) | ✅ | `grep -c "live_render" .../chat_live.html.heex` — 7 ocorrências (4 superfícies mais slots); e cada `*_live_test.exs` tem par nested |

### 3.2 As obrigações de repositório, onda a onda

| Item | Onda | Estado | Como conferir |
|---|---|---|---|
| `PerfBudgets` `:play` | 0 | ✅ | `grep "html_bytes(:play)" test/support/perf_budgets.ex` |
| `PerfBudgets` `:call` | 2 | ✅ | idem `:call` |
| `PerfBudgets` `:space` | 3 | ✅ | idem `:space` |
| `PerfBudgets` `:p2p` | 4 | ✅ | idem `:p2p` |
| **`PerfBudgets` `:join`** | 1 | ❌ | **§4.4** |
| Help topics de cada onda | 0–5 | ✅ | `grep -c "id: \"feature-" .../help_topics/features.ex`; todo template tem tópico (loop na §3.4) |
| `SURFACE.txt` | 0–6 | ✅ | `cd apps/retro_hex_chat_web/assets && ./scripts/surface_snapshot.sh --check` |
| `e2e/TEST_CATALOG.md` | 2–6 | ✅ | `make e2e.catalog && git diff --exit-code e2e/TEST_CATALOG.md` |
| `bundle_budget.cjs` sem entry nova (D4) | 6 | ✅ | decisão medida em `docs/reference/ci-pipeline.md` |
| Migração do `share_links` com índices | 1 | ✅ | `grep index priv/repo/migrations/*create_share_links*` — único em `slug`, índice em `creator_id` |
| Migração do lobby aberto | 5 | ✅ | `priv/repo/migrations/20260831120000_open_lobby_sessions.exs` |
| Job de expiração no Oban + observabilidade | 5 | ✅ | `jobs/open_lobby_expiry_worker.ex` + `open_lobby_expiry_worker_test.exs` (assere o evento de telemetria, não só o efeito) |
| Sitemap não ganha `/join` | 1 | ⚠️ | verdade **por construção** (`SEO.@landing_paths` é constante), mas a onda pedia teste e não há |
| i18n dos domínios tocados | 0–6 | ⚠️ | **§4.1** |

### 3.3 O núcleo de domínio da onda 5

| Asserção da tabela de TDD | Estado | Onde |
|---|---|---|
| changeset permite `peer_id` nulo em `open`, exige nos pareados | ✅ | `open_session_test.exs`, "the changeset invariant" |
| `open → pending` só com peer | ✅ | idem, "a peerless session cannot be walked into a paired status" |
| duas reivindicações concorrentes: uma ganha | ✅ | idem, "two people follow the same link at the same moment" — **e foi verificado revertendo**: com `read → check → write` as 8 concorrentes ganham as 8 |
| reivindicar o próprio link recusado | ✅ | idem |
| bloqueado não reivindica | ✅ | idem |
| expirado não reivindica | ✅ | idem |
| rate limit de criação | ✅ | idem (reusa `P2P.RateLimiter`) |
| `[Iniciar]` só do host; host sai → sala fecha (P7) | ✅ | `play_match_test.exs`, "the guest has neither Start nor Cancel" e "the host can cancel the match" |

### 3.4 Comandos de conferência que valem repetir

```sh
# todo template de ajuda tem um tópico registrado (sem órfãos)
for f in apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/feature_*.html.heex; do
  id=$(basename $f .html.heex | sed 's/_/-/g')
  grep -q "id: \"$id\"" apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/*.ex || echo "ÓRFÃO: $id"
done

# funções de domínio que o plano criou e ninguém chama
for f in "ShareLinks.revoke" "describe_many" "Surfaces.count" "Surfaces.list"; do
  echo "$f -> $(grep -rn -- "$f" apps --include='*.ex' --include='*.heex' \
    | grep -v 'def \|@spec\|defdelegate\|@doc\|/test/' | wc -l) chamadas fora de teste"
done
```

---

## 4. Os achados — o que **não** foi feito

Oito. Nenhum deles aparece no diário do plano como pendência; sete foram
encontrados nesta auditoria e um estava marcado `[ ]` na onda 0 e nunca voltou.

### 4.1 Cerca de dez `msgid` do plano continuam em inglês nos 13 locales

**Severidade: média.** É texto de produto que um leitor não-inglês vê.

A onda 0 marcou isto como dívida explícita — *"Os 7 `msgid` novos traduzidos —
precisa do venv de Argos Translate, ausente nesta máquina"* — e a onda 1 somou
mais. Nenhuma onda posterior voltou, e o `make ci` não cobra cobertura de `.po`,
então nada apitou. As ondas 5 e 6 traduziram 44+ msgids **à mão**, o que prova
que a justificativa do venv não se sustentava.

```sh
python3 - <<'PY'
import glob, re
def entries(path):
    for b in re.split(r'\n\n+', open(path).read()):
        m=re.search(r'^msgid ((?:"(?:[^"\\]|\\.)*"\s*)+)^msgstr ((?:"(?:[^"\\]|\\.)*"\s*)+)', b, re.M|re.S)
        if m:
            mid=''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1)))
            ms=''.join(re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(2)))
            if mid: yield mid, ms, b
for f in ['apps/retro_hex_chat/priv/gettext/pt_BR/LC_MESSAGES/help.po',
          'apps/retro_hex_chat_web/priv/gettext/pt_BR/LC_MESSAGES/help_games.po']:
    for mid, ms, b in entries(f):
        if ms == '' and ('feature_retro_games' in b or 'features.ex:17' in b or 'features.ex:174' in b):
            print(f.split('/')[-1], '->', mid[:70])
PY
```

**Do plano** (o resto das entradas vazias é deriva de bots/RSS/scraper, de
outras pessoas):

- `help`: `own tab`, `share a game` — palavras-chave do tópico de Retro Games
  (onda 0)
- `help_games`: as **oito** frases das seções "Playing in Its Own Tab" e
  "Sharing a Game" de `feature_retro_games.html.heex` (ondas 0 e 1)

Custo de fechar: ~10 msgids × 13 locales, escritos à mão, do jeito que as ondas
5 e 6 fizeram. Não precisa de venv.

### 4.2 Cinco specs de Playwright entraram vermelhos e saíram vermelhos

**Severidade: média-alta.** São regressões de produto ou de teste que ninguém
está mais olhando, porque o Playwright **não está no `make ci`**.

Medido em 2026-08-31, no `HEAD` desta auditoria: **32 passam, 5 falham.** São
exatamente os mesmos cinco que o handover da onda 2 já listava.

| Spec | Teste | Diagnóstico registrado |
|---|---|---|
| `chat-group-call.spec.ts` | two identified channel users join the same SFU call | janela maximizada cobre a barra de status; o clique não alcança |
| `chat-group-call.spec.ts` | pre-join can enter with microphone and camera disabled | o helper procura uma chave `rhc:group-call:prejoin:` no `localStorage` **que não existe em lugar nenhum do repositório** |
| `chat-group-call.spec.ts` | pre-join permission denial can retry | idem |
| `chat-p2p.spec.ts` | the inviter cancels a pending invite from the status bar | mesmo z-index da primeira |
| `chat-call-fault-injection.spec.ts` | P2P answerer reloads while applying the initial offer | recuperação de mídia depois de reload no meio do primeiro offer; metade corrigida na onda 4B (epoch por página) |

Duas delas são **bug de teste, não de produto** (a chave de `localStorage`
inventada), e foram diagnosticadas na iteração 13 sem serem consertadas. O
padrão que se repetiu seis ondas seguidas: *"verificado com `git stash`: falha
igual no `HEAD`, não é meu"* — verdadeiro em cada onda, e o resultado é que
ninguém nunca foi o dono.

### 4.3 O convite P2P ainda escreve `/lobby/<token>`, que joga você no chat

**Severidade: média.** Toda PM de convite carrega um link que vai para o lugar
errado, e desde a onda 4 existe o lugar certo.

```sh
grep -n "lobby/%{token}" apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/lobby_invite.ex
cat apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/app/lobby_redirect_controller.ex
```

O texto do convite é *"P2P session request. Use the P2P control in this PM.
/lobby/%{token}"*, e `LobbyRedirectController` **ignora o token** e redireciona
para `/chat`. A onda 1 listou em "Pronto quando": *"`/lobby/:token` legado
resolve para `/join/:slug` quando possível"* — e ficou como estava.

O alvo certo hoje nem é `/join/:slug` (um token de sessão não tem slug): é
`/p2p/:token`, que existe desde a onda 4 e aplica o portão de três perguntas.
Uma linha no controller.

### 4.4 `/join/:slug` não tem orçamento de payload

**Severidade: baixa, mas é a única página pública do plano.**

```sh
grep -n "html_bytes(:" apps/retro_hex_chat_web/test/support/perf_budgets.ex
# :connect :help :chat :play :call :space :p2p — sem :join
```

A onda 1 escreveu *"`PerfBudgets` para `:join` (é uma página pública — o
orçamento importa)"*. As quatro superfícies do app ganharam orçamento; a única
tela que um estranho vê, não. `payload_budget_test.exs` também não a exercita.

### 4.5 A prévia social de um link compartilhado é o card genérico do site

**Severidade: média.** É metade da razão de o `/join/:slug` existir.

```sh
# renderize /join/<slug> e leia o <head>
curl -s http://localhost:4000/join/<slug> | grep -E 'og:(title|description|image)'
```

Medido: `og:title` = `Join - RetroHexChat`, `og:description` = a descrição da
landing, `og:image` = a imagem da landing. **Nada sobre o que foi compartilhado.**

O `ux.md` §2.2 desenhou essa tela como *"a primeira coisa que um estranho vê do
produto"*, com Open Graph, e escreveu a regra de privacidade da prévia: *"um
preview de rede social que diz 'Chamada em #diretoria' vaza a existência de um
canal que a pessoa não podia nem listar. Canal público aparece; canal privado
vira 'Uma chamada no RetroHexChat'"*.

Essa lógica **existe** — é `JoinLive.subject/1` — e só alimenta o **corpo do
card na página**. Nunca chegou às meta tags, que são a superfície para a qual a
regra foi escrita. Não é vazamento (a prévia não diz nada); é a promessa não
cumprida.

### 4.6 `ShareLinks.revoke/2` não tem nenhum chamador fora de teste

**Severidade: média.** A onda 5 lista revogação como **mitigação de abuso**.

```sh
grep -rn "ShareLinks.revoke\|revoke(" apps --include='*.ex' --include='*.heex' | grep -v /test/
```

A função existe, é testada e não tem UI. A onda 1 previu um help topic *"como
revogar"*, que corretamente não foi escrito — ajuda responde "como eu faço", e
não há como fazer. Mas a onda 5, ao listar as mitigações obrigatórias do lobby
aberto, contou com ela: *"revogação pelo criador (onda 1 já dá isso)"*.

Atenuante honesto: para o kind `play` de partida, `[Cancelar]` fecha a sala e o
link morre por consequência (`Liveness` pergunta se a cadeira está vazia). Para
`call`, `space` e `play` solo, um link mintado é **para sempre** — só o fim da
sala o mata, e um link de space nunca morre, porque um space nunca acaba.

### 4.7 A barra de abas e a zona de status do chat não dizem "em outra aba"

**Severidade: baixa.** Desenhado no `ux.md` §2.7 e na onda 6 §1.2, não construído.

```sh
grep -rn "open_surface_paths" apps/retro_hex_chat_web/lib/
# 5 consumidores: os quatro `← Chat` e o popover do crachá de chamada
```

O `ux.md` §2.7 desenha: *"A aba `[☎ Chamada]` na barra ganha um estado novo:
**'em outra aba'**, com a ação `Focar` em vez de `Abrir`"*, e a onda 6 §1.2
repete pedindo o mesmo do `chat_shell_status`.

O que foi feito: os quatro links que **realmente abrem uma aba** ganharam as duas
formas. A barra de abas e a zona de status **não** — elas abrem a janela do chat,
não uma aba, então não havia segunda aba a evitar; mas o desenho pedia que
dissessem *onde* a coisa está, e isso não existe.

### 4.8 A linha de Playwright da onda 6 está meio coberta

**Severidade: baixa.**

A onda 6 pedia: *"abrir a mesma chamada duas vezes não gera dois participantes;
a segunda aba avisa"*. `surface-cross-tab.spec.ts` cobre o `← Chat` (K5) e o
copiar numa satélite (K6). **Não** existe spec que abra a mesma chamada em duas
abas e verifique a contagem de participantes.

Contra-argumento honesto: com o registro de superfícies o link agora diz "ir para
a aba", então o caminho de UI para abrir duas vezes ficou difícil de alcançar —
mas "difícil de alcançar pela UI" não é o mesmo que "testado".

---

## 5. O que foi deliberadamente não feito (não reabrir sem ler)

Para o auditor não gastar tempo re-litigando decisões que têm razão escrita:

| Não feito | Onde está a razão |
|---|---|
| Entry `surface.js` separada | `docs/reference/ci-pipeline.md` — medido: economizaria 14,3% e custaria no caminho comum |
| Start menu nas satélites | `docs/guide/windowed-desktop.md` §7.0 — +177 nós por tela, quatro vezes, e um teste segura |
| Guest pass (link que concede autorização) | D1 no README do plano (`git show 9620e81b^:...`): merece plano próprio, com moderação e ban junto |
| Migração de host na sala de partida | P7: é uma sala que dura minutos; a recuperação certa é criar outra |
| Prontidão persistida em `metadata` | Prontidão é do par de olhos na tela; persistir criaria segundo dono de um fato que um reload invalida |
| Suíte de P2P em Firefox | Playwright/Firefox responde `Unknown permission: microphone`; a suíte é Chromium por construção |
| Aba do arcade contada ou focada | Outra origem: sem LiveView para monitorar e fora do `BroadcastChannel` (escrito em `guide/surfaces.md` §19.4) |

---

## 6. Onde as regras duráveis foram parar

O plano mandava mover antes de apagar. Conferir que a mudança foi real, e não
uma linha dizendo que foi:

```sh
wc -l docs/guide/surfaces.md                       # 268 linhas, §19
grep -n "^## 19\." docs/guide/surfaces.md          # sete seções
grep -n "surfaces.md" AGENTS.md docs/README.md docs/AGENT-GUIDE.md
grep -n "Six reserved first segments" docs/AGENT-GUIDE.md      # §16
grep -n "7.0 Satellites" docs/guide/windowed-desktop.md
grep -n "one app entry" docs/reference/ci-pipeline.md
```

| Guia | O que recebeu |
|---|---|
| `guide/surfaces.md` (§19, novo) | D2, a régua do read-model, `Live.Surface`, `SurfaceHost`, o registro, a coordenação entre abas, os links, o portão de três perguntas, P1–P7, as armadilhas |
| `AGENT-GUIDE.md` §16 | segmentos reservados, rota pública dentro do laço de locales, `noindex` |
| `guide/windowed-desktop.md` §7.0 | o que uma satélite carrega, com o número e o teste |
| `guide/webrtc-p2p.md` §8.1 e §8.5 | `open` + escrita condicional; fechar aba como caso comum |
| `reference/ci-pipeline.md` | a decisão de bundle com a tabela |
| `reference/call-handshake-resilience-map.md` | passe de exatidão no transporte P2P |

---

## 7. Onde eu sou mais capaz de ter enganado você

Escrito por quem fez o trabalho, sobre o próprio trabalho. Estes são os modos de
falha que **este** plano ofereceu, e onde procurar primeiro na próxima vez:

1. **"Verificado com `git stash`: não é meu."** Verdadeiro seis ondas seguidas,
   e o resultado é a §4.2: cinco testes que ninguém nunca foi dono. A frase é
   honesta e o efeito é abandono. Regra melhor: *um vermelho que atravessa duas
   ondas passa a ser da onda que o encontrou.*

2. **Item de checklist tratado como item de commit.** As obrigações de onda
   (`PerfBudgets`, i18n, help) foram cumpridas quando estavam no caminho do que
   eu estava construindo, e esquecidas quando não estavam — §4.1 e §4.4 são
   exatamente isso: as ondas cujo trabalho *era* a superfície ganharam
   orçamento; a página pública, que era um efeito colateral da onda 1, não.

3. **Confundir "a lógica existe" com "a lógica é usada".** §4.5 e §4.6 são a
   mesma forma: `subject/1` implementa a regra de privacidade da prévia e nunca
   chega numa meta tag; `revoke/2` implementa a mitigação de abuso e não tem
   botão. Nos dois casos o teste de unidade passa e o produto não tem a
   capacidade. **Grep por chamador fora de teste é o antídoto**, e está na §3.4.

4. **Declarar a onda fechada lendo o diário em vez da tabela.** Aconteceu na
   onda 4 (11 de 13 linhas) e foi corrigido virando ritual na onda 5 — que
   achou dois buracos reais, um deles um invariante de changeset. O ritual
   funciona; ele só nunca foi aplicado às ondas **anteriores** à sua criação, e
   é lá que a §4 concentra os achados: ondas 0, 1 e 2.

5. **A tela bonita esconde a parte que falta.** O screenshot pega o que está
   feio, não o que não existe. Nenhuma das oito coisas da §4 apareceria numa
   captura de tela.

---

## 8. Se for para consertar, esta é a ordem

Por custo × consequência, não por gravidade:

1. **§4.3** (`/lobby/<token>` → `/p2p/:token`) — uma linha no controller e um
   teste. Conserta um link que hoje leva ao lugar errado em toda PM de convite.
2. **§4.1** (10 msgids × 13 locales) — mecânico, do jeito que as ondas 5 e 6
   fizeram; sem venv.
3. **§4.4** (`PerfBudgets` `:join`) — medir e escrever, ~15 linhas de teste.
4. **§4.5** (Open Graph do card) — `JoinLive.subject/1` já tem o conteúdo e a
   regra de privacidade; falta levá-lo ao `<head>`. É a maior devolução de
   produto da lista.
5. **§4.6** (revogar) — decidir primeiro se a capacidade fica: ou ganha UI, ou a
   função sai e a onda 5 perde uma mitigação que ela achava que tinha.
6. **§4.2** (5 specs) — duas são bug de teste (a chave de `localStorage`
   inventada) e devem ser as primeiras; as outras três são z-index e recuperação
   de mídia, cada uma um commit próprio.
7. **§4.7 e §4.8** — desenho não construído e cobertura parcial; os menos
   urgentes, e legítimo decidir que não valem.
