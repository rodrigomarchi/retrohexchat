# Handover — auditar o plano de superfícies compartilháveis

Escrito em 2026-08-31 **por quem fez o trabalho**, para uma sessão que vai
auditá-lo com o contexto zerado. Apagar quando a auditoria fechar e os achados
dela virarem issues ou commits.

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
