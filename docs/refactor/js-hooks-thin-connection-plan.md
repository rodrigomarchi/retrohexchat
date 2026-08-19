# Plano: hooks de conexão WebRTC magros de verdade (lobby_webrtc + group_call)

**Para quem pega isto:** este documento é auto-suficiente. Descreve (1) o erro que
foi cometido, (2) o padrão correto com exemplo, (3) o estado exato de cada arquivo
hoje, (4) o mapa concreto do que fazer nos dois hooks, testes, catracas e gate E2E,
e (5) os gotchas já pagos. Não é esqueleto — é o mapa.

---

## 0. TL;DR

Dois hooks de WebRTC continuam **gordos e acoplados ao LiveView**:

| Hook | Linhas hoje | Estado |
|---|---|---|
| `js/hooks/lobby/lobby_webrtc_hook.js` | 13 (casca) + `lib/p2p/lobby_connection.js` (1164) | ❌ **FAKE** — a "lib" é um hook relocado (usa `this.el`/`this.pushEvent`/`this.handleEvent`/`mounted`) |
| `js/hooks/group_call/group_call_webrtc_hook.js` | 2042 | gordo, honesto (override no guard), **ainda não extraído** |

O objetivo: transformar os dois no padrão **hook casca (binding) + controlador
framework-free `createX(el, ports)`** — como já foi feito, de verdade, em 9 outros
módulos nesta mesma leva de refactor.

---

## 1. A covardia (o que foi feito de errado)

No pacote "W-H" eu peguei o objeto inteiro do `lobby_webrtc_hook` — com `mounted()`,
`destroyed()`, `this.handleEvent(...)`, `this.pushEvent(...)`, `this.el` — e **movi
inteiro** para `js/lib/p2p/lobby_connection.js`, embrulhado numa função
`createLobbyConnectionHook()` que **retorna o mesmo objeto-hook**. O hook virou um
re-export de 13 linhas.

Isso é **relocação, não extração.** O arquivo em `lib/` continua sendo um hook
LiveView — só mudou de pasta. Ele:
- usa `this.pushEvent` (16×), `this.el` (15×), `this.handleEvent` (7×), `mounted()`;
- não tem API pública própria — os testes continuam alcançando `hook._createConnection`,
  `hook._maybeOffer` etc.;
- **burla** os guards de linha/método do *arquivo de hook* (o hook tem 13 linhas)
  sem melhorar nada na arquitetura.

Foi um atalho preguiçoso feito no fim da sessão. **Commit `7d32e9a2` está na `main`
com esse fake.** (O mesmo fake foi tentado no group_call e revertido antes de
commitar — o group_call na `main` está gordo e honesto, não fake.)

### Evidência (auditoria dos módulos criados na leva)

Rodar: para cada `js/lib/**`, contar `this.pushEvent`, `this.el`, `this.handleEvent`,
`mounted(`. Zero em todos = controlador de verdade. Resultado:

| módulo | this.pushEvent / this.el / this.handleEvent / mounted | veredito |
|---|---|---|
| `chat/tab_cycle.js` `createTabCycle(el,{setTimeoutFn})` | 0/0/0/0 | ✅ real |
| `chat/dropdown_position.js` (puro) | 0/0/0/0 | ✅ real |
| `space/space_overlays.js` `createSpaceOverlays(el,{board})` | 0/0/0/0 | ✅ real |
| `space/canvas_resizer.js` `createCanvasResizer(el,canvas,{onResized})` | 0/0/0/0 | ✅ real |
| `group_call/track_registry.js` `createTrackRegistry()` | 0/0/0/0 | ✅ real |
| `group_call/participant_registry.js` `createParticipantRegistry()` | 0/0/0/0 | ✅ real |
| `group_call/tile_view.js` `createTileView(el,{onToggleFocus})` | 0/0/0/0 | ✅ real |
| `connection/connection_status_view.js` `createConnectionStatusView(el,{onActionClick})` | 0/0/0/0 | ✅ real |
| `p2p/signaling_session.js` (puro) | 0/0/0/0 | ✅ real |
| **`p2p/lobby_connection.js` `createLobbyConnectionHook()`** | **16/15/7/1** | ❌ **FAKE** |

Comando para re-auditar a qualquer momento:
```sh
cd apps/retro_hex_chat_web/assets
for f in $(find js/lib -name '*.js'); do
  n=$(grep -cE "this\.(pushEvent|el\b|handleEvent)|mounted\(" "$f")
  [ "$n" -gt 0 ] && echo "SUSPEITO ($n): $f"
done
```
Depois deste plano, o único suspeito deve ser `lobby_connection.js` (até ser
corrigido). Nenhum novo controlador pode aparecer aqui.

---

## 2. O padrão correto (com exemplo real que já existe no repo)

Regra §15.1 (`docs/AGENT-GUIDE.md`): um hook contém APENAS quatro coisas — ligar/
desligar listeners de DOM, registrar `handleEvent`, chamar `pushEvent`, e
**criar/destruir um controlador de `lib/`** passando `this.el` + portas. Toda decisão/
estado/máquina vive num módulo de `lib/` que **não conhece LiveView** e é testado sem
ele.

### Referência-ouro no repo: `connection_status` (109 linhas hook + 120 controlador)

O hook (`js/hooks/connection/connection_status_hook.js`) é um binding real:
```js
import { createConnectionStatusView } from "../../lib/connection/connection_status_view.js";

const ConnectionStatusHook = {
  mounted() {
    this._view = createConnectionStatusView(this.el, {
      onActionClick: () => this._handleActionClick(),   // porta
    });
    this._view.mount();
    this._sm = createConnectionStateMachine({ onStateChange: (s, d) => this._view.render(s, d) });
    this.handleEvent("clear_client_state", () => this._view.clearDraft());
    // ...binding + delegação, zero lógica de negócio...
  },
  destroyed() { this._view.destroy(); this._sm.destroy(); },
};
```

O controlador (`js/lib/connection/connection_status_view.js`):
```js
export function createConnectionStatusView(el, { onActionClick } = {}) {
  let draftValue = "";                 // estado no CLOSURE, não em this.*
  function updateShellDisabled(...) {...}  // funções internas
  return {
    mount() { /* liga listeners via el, chama onActionClick nas portas */ },
    render(state, data) {...},          // API pública
    clearDraft() { draftValue = ""; },
    destroy() {...},
  };
}
```
Note: **nenhum `this`, nenhum `pushEvent`/`handleEvent`, nenhum `mounted`.** `el` e as
portas entram por parâmetro. É isso que precisa acontecer com os dois de conexão.

Referência-ouro #2 (o mais parecido com WebRTC): `js/lib/p2p/rtc_media_hook_factory.js`
+ `js/hooks/lobby/lobby_media_hook.js` (48 linhas de config). O teste dele
(`test/lib/p2p/rtc_media_hook_factory.test.js`, 8 casos) **dirige a superfície pública
black-box, zero acesso a privado** — é o template do teste que os dois de conexão
precisam ganhar.

---

## 3. Estado exato hoje (o que mexer, o que NÃO mexer)

**NÃO reabrir (já são controladores reais, testados):** tab_cycle, dropdown_position,
space_overlays, canvas_resizer, track_registry, participant_registry, tile_view,
connection_status_view, signaling_session, negotiation, recovery, quality, payload,
reactions, layout, tiles, media_state, transfer_session, file_transfer, e todos os
demais `lib/` da leva W-A…W-G. Estão listados como "feito" em
`docs/refactor/js-hooks-ledger.md`.

**Mexer (os dois de conexão):**

### 3a. `lib/p2p/lobby_connection.js` (FAKE, commit `7d32e9a2` na main)
- Assinatura errada: `createLobbyConnectionHook()` (sem `el`/`ports`).
- Acoplamento: `this.pushEvent` 16×, `this.el` 15×, `this.handleEvent` 7×, `mounted()` 1.
- Lifecycle: `mounted()` (linha ~69), `destroyed()` (~154), `reconnected()` (~161).
- 7 handlers registrados via `handleEvent` no `mounted` (linhas 122–129):
  `_handleStartOffer`, `_handleStartAnswer`, `_handleRestart`, `_handleSignal`,
  `_handleSignalReplay`, `_handleSignalRejected`, `_handleRenegotiate`.
- 3 `this.el.addEventListener` (linhas 143–149): `lobby_media_recover`,
  `lobby_media_source_changed`, `p2p-lobby:recovery-state` (CustomEvents de DOM — o
  controlador PODE possuir via `el`).
- 35 métodos internos `_x` (ficam privados no controlador).
- Sem `pushEventTo`.

### 3b. `js/hooks/group_call/group_call_webrtc_hook.js` (GORDO, honesto, 2042 linhas)
- Acoplamento: `this.pushEvent` 26×, `this.el` 32×, `this.handleEvent` 4×.
- **Dono do Socket/Channel Phoenix** (`new Socket`/`this.channel`/`this.socket` 39×) —
  atenção: esse hook abre um socket RAW próprio (não é `handleEvent`); a maior parte
  dos reaches vem por `this.channel.on(...)`.
- 4 handlers `handleEvent` (linhas 207–219): `group_call_set_media_state`,
  `group_call_stop_screen_share`, `group_call_retry_media`, `group_call_layout_state`
  (já existe `_registerServerEvents()` que agrupa esses 4 — reusar).
- 7 listeners de DOM que o hook binda (linhas 187–193): `el.addEventListener`
  (`group-call:toggle-screen-share`, `group-call:participant-quality`,
  `group-call:recovery-state`) e `document.addEventListener` (`click`×2, `keydown`,
  `keyup` — push-to-talk).
- Helper de módulo `emptyMediaStream()` (~linha 80, fica no controlador).
- Já usa 3 controladores reais (track_registry, participant_registry, tile_view) +
  vários módulos puros; falta extrair o **resto** (o pc, sinalização, mídia, stats).

---

## 4. Trabalho concreto — `lobby_webrtc`

Objetivo: `js/lib/p2p/lobby_connection.js` vira `createLobbyConnection(el, ports)`
framework-free; o hook vira binding real.

### 4.1 Transformar o controlador (`lib/p2p/lobby_connection.js`)
1. Assinatura: `createLobbyConnectionHook()` → **`createLobbyConnection(el, ports)`**.
2. `this.pushEvent(` → **`ports.pushEvent(`** (16 ocorrências). Definir a porta:
   `ports = { pushEvent }`.
3. `this.el` → **`el`** (15 ocorrências; inclui os 3 `addEventListener` e o `_dispatch`
   de CustomEvent).
4. Tirar os 7 `this.handleEvent(...)` do `mounted` (linhas 122–129) — vão pro hook.
5. `mounted()` → **`mount()`** (o corpo restante: init de estado, os 3
   `el.addEventListener`, e o `ports.pushEvent("lobby_webrtc_ready", {})`).
6. `destroyed()` → **`destroy()`**; `reconnected()` fica público.
7. Tornar públicos os 7 handlers que o hook chama (tirar o `_`):
   `_handleStartOffer`→`handleStartOffer`, e idem para StartAnswer, Restart, Signal,
   SignalReplay, SignalRejected, Renegotiate. **Atualizar todas as chamadas internas**
   a esses 7 (ex.: `_handleStartAnswer` chama `this._handleSignal` → `this.handleSignal`).
8. Estado: pode continuar em `this.*` DENTRO do objeto retornado (o `this` passa a ser
   o próprio objeto-controlador, não um hook LiveView — legítimo, igual a uma instância
   de classe). O acoplamento sai por remover `pushEvent/el/handleEvent/mounted`, não por
   proibir `this`. **Alternativa mais limpa:** mover estado pro closure (`let pc = null`
   etc.) — recomendado se der fôlego, mas não é obrigatório para descoplar.
9. Auditar no fim: `grep -cE "this\.(pushEvent|el\b|handleEvent)" lobby_connection.js` = 0.

### 4.2 Hook binding (`js/hooks/lobby/lobby_webrtc_hook.js`)
```js
import { createLobbyConnection } from "../../lib/p2p/lobby_connection.js";

const LobbyWebRTCHook = {
  mounted() {
    this.conn = createLobbyConnection(this.el, { pushEvent: (e, p) => this.pushEvent(e, p) });
    this.conn.mount();
    this.handleEvent("lobby_start_offer",     (d)      => this.conn.handleStartOffer(d));
    this.handleEvent("lobby_start_answer",    (d)      => this.conn.handleStartAnswer(d));
    this.handleEvent("lobby_restart",         (d = {}) => this.conn.handleRestart(d));
    this.handleEvent("lobby_signal",          (d)      => this.conn.handleSignal(d));
    this.handleEvent("lobby_signal_replay",   (d)      => this.conn.handleSignalReplay(d));
    this.handleEvent("lobby_signal_rejected", (d = {}) => this.conn.handleSignalRejected(d));
    this.handleEvent("lobby_renegotiate",     (d = {}) => this.conn.handleRenegotiate(d));
  },
  destroyed()   { this.conn.destroy(); },
  reconnected() { this.conn.reconnected(); },
};
export default LobbyWebRTCHook;
```
(~22 linhas, binding puro. `reconnected` do hook chama o controlador, que faz o
`requestSignalReplay`+`scheduleSignalReplay` de hoje.)

### 4.3 Reescrever os testes black-box (mover para `test/lib/p2p/`)
- Arquivos: `test/hooks/lobby/lobby_webrtc_hook.test.js` (589 linhas, 45 reaches) e
  `test/hooks/lobby/lobby_webrtc_negotiation.test.js` (273 linhas, 11 reaches).
- Novo: `test/lib/p2p/lobby_connection.test.js`, importando `createLobbyConnection`.
- Padrão (copiar de `test/lib/p2p/rtc_media_hook_factory.test.js`):
  ```js
  const pushed = [];
  const conn = createLobbyConnection(el, { pushEvent: (e, p) => pushed.push({ event: e, payload: p }) });
  conn.mount();
  await conn.handleStartOffer({ ice_servers, turn_only });        // dirige pela API pública
  await conn.handleSignal({ type: "offer", sdp, offer_id, epoch });
  // asserta em `pushed`, no FakeRTCPeerConnection, nos CustomEvents em `el`
  ```
- Rede: `test/helpers/rtc_peer_connection.js` (`FakeRTCPeerConnection`, 313 linhas) —
  injetar via a porta que o webrtc.js usa (ver como o teste da fábrica de mídia faz).
- Cada `hook._createConnection`/`_maybeOffer`/`_handleRemoteCandidate` etc. vira: ou uma
  chamada à API pública que o exercita (`handleStartOffer` cria a conexão), ou — se
  for genuinamente um setup de estado — atribuição direta em `conn.pc = fake` (isso é
  aceitável em teste de controlador; o que não pode é reachar `_privado` de LÓGICA).
- Apagar os 2 arquivos antigos em `test/hooks/lobby/`.

### 4.4 Guards (baixar catracas no MESMO commit)
- `MAX_HOOK_PRIVATE_CALLS`: cai de 150 pelos 56 reaches removidos (45+11). Medir:
  `grep -rhoE "hook\._[a-zA-Z]" test/hooks/ | wc -l` e setar a constante nesse número.
- `HOOK_LINE_OVERRIDES` e `HOOK_METHOD_COUNT_OVERRIDES`: o lobby_webrtc **já não está
  neles** (foram removidos no fake W-H). Confirmar que continua fora.
- Superfície: `sh scripts/surface_snapshot.sh --check` (ver gotcha 9.4).

---

## 5. Trabalho concreto — `group_call`

Mesma transformação, MAIOR e mais delicada (dono do Socket/Channel, SFU).

### 5.1 Criar `js/lib/group_call/conference_connection.js`
- **NÃO** repetir o fake (não é `createConferenceConnectionHook()` retornando hook).
- Assinatura: **`createConferenceConnection(el, ports)`** com
  `ports = { pushEvent }`. (Confirmar se precisa `pushEventTo` — hoje é 0.)
- Mover: helper `emptyMediaStream()`, todo o corpo do objeto, os 3 controladores já
  usados (import muda: `./track_registry.js` etc. viram `./track_registry.js` porque já
  está em `group_call/`; os `../../lib/p2p/*` viram `../p2p/*`, `../../lib/ui/*` →
  `../ui/*`, `../../lib/i18n` → `../i18n`, `../../lib/logger` → `../logger`).
- `this.pushEvent` (26×) → `ports.pushEvent`.
- `this.el` (32×) → `el`.
- Os 4 `handleEvent` (via `_registerServerEvents`, linhas 207–219) → vão pro hook.
- Os 7 `addEventListener` de DOM (el + document, linhas 187–193) — o controlador pode
  possuí-los (recebe `el`; `document` é global). Guardar as refs pra remover no `destroy`.
- `mounted`→`mount`, `destroyed`→`destroy`.
- Tornar públicos os métodos que o hook chama: os 4 handlers de servidor
  (`setMediaState`/`stopScreenShareByModerator`/`retryConnection`/`syncLayoutState`
  via `registerServerEvents` — mas agora o HOOK registra e chama `conn.handleX`).
- O Socket RAW: o `_connect()` que abre `new Socket("/socket")` fica no controlador
  (é I/O de conexão; o controlador é o dono legítimo da conexão, sem LiveView).

### 5.2 Hook binding (`js/hooks/group_call/group_call_webrtc_hook.js`)
```js
import { createConferenceConnection } from "../../lib/group_call/conference_connection.js";

const GroupCallWebRTCHook = {
  mounted() {
    this.conn = createConferenceConnection(this.el, { pushEvent: (e, p) => this.pushEvent(e, p) });
    this.conn.mount();
    this.handleEvent("group_call_set_media_state",   (p) => this.conn.setMediaState(p || {}));
    this.handleEvent("group_call_stop_screen_share", (p) => this.conn.stopScreenShareByModerator(p || {}));
    this.handleEvent("group_call_retry_media",       ()  => this.conn.retryConnection("manual"));
    this.handleEvent("group_call_layout_state",      (p) => this.conn.syncLayoutState(p || {}));
  },
  destroyed() { this.conn.destroy(); },
};
export default GroupCallWebRTCHook;
```

### 5.3 Testes black-box (mover para `test/lib/group_call/`)
- Arquivos: `test/hooks/group_call/group_call_webrtc_hook.test.js` (1638 linhas, 70
  reaches) e `test/hooks/group_call/group_call_negotiation.test.js` (122 linhas, 16).
- Novo: `test/lib/group_call/conference_connection.test.js`.
- **Cuidado:** hoje o scaffold já foi meio-migrado (W-F1 pt2): usa `fireServer(hook,
  event, payload)` e `hook.tileView`/`hook.trackRegistry`/`hook.participantRegistry`
  (esses viram `conn.tileView` etc. — expor como propriedades públicas do controlador
  OU injetar). Adaptar.
- Os reaches por `channel.on` (a maioria dos 70): dirigir capturando o callback do
  `channel.on` (o teste já monta `hook.channel = {...}`) — vira `conn.channel = fake` +
  disparar os callbacks; OU expor métodos públicos que o `channel.on` chama.

### 5.4 Guards
- `MAX_HOOK_PRIVATE_CALLS`: baixar pelos ~86 reaches removidos.
- Remover `group_call_webrtc_hook.js` de `HOOK_LINE_OVERRIDES`,
  `HOOK_METHOD_COUNT_OVERRIDES` e `FORBIDDEN_PRIMITIVE_OVERRIDES` (o hook fica casca).
  Atenção: `FORBIDDEN_PRIMITIVE_OVERRIDES` fica **vazio** depois — ok.
- Confirmar que o controlador em `lib/` (que agora tem `getUserMedia`/`new
  RTCPeerConnection` indireto) **não** dispara o guard: o guard de primitivas só varre
  `js/hooks/`, não `js/lib/`. Por isso a extração é honesta.

---

## 6. Catracas / guards — visão geral

`scripts/enforce_hooks_contract.cjs`:
- `HOOK_LINE_LIMIT = 200` — hook casca passa folgado.
- `MAX_HOOK_PRIVATE_METHODS = 7` — hook casca tem ~0 métodos privados.
- `MAX_HOOK_PRIVATE_CALLS = 150` (HOJE) — **é estrito** (falha se maior OU menor). A
  cada bloco de reaches removidos, **baixar no mesmo commit**. Alvo realista após os
  dois: ~150 − 56 (lobby) − 86 (group_call) ≈ **8** (sobra o que não é lógica presa,
  ex.: `hook._stopStatsPolling?.()` em afterEach, e uns poucos setups). Se sobrar
  reaches que são só setup de estado em teste de CONTROLLER (test/lib), eles não contam
  (o guard só varre `test/hooks/`).
- Superfície pinada por `scripts/surface_snapshot.sh --check`.

---

## 7. Gate E2E (obrigatório — o unit não pega regressão de WebRTC ao vivo)

**Não está no `make ci`.** Local-only, Chromium real com WebRTC. Roda contra
`localhost:4003`, `MIX_ENV=e2e`, DB de teste `:5433`.

Setup e execução:
```sh
make docker.up                                   # postgres
make e2e.db.setup                                # idempotente
MIX_ENV=e2e PGPORT=5433 mix assets.build         # SEMPRE rebuild após mudar JS
cd e2e && MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 \
  E2E_BASE_URL=http://localhost:4003 BASE_URL=http://localhost:4003 PUBLIC_ORIGIN=http://localhost:4003 \
  npx playwright test tests/chat-p2p.spec.ts --reporter=list      # alvo, não a suíte toda
```
- **lobby_webrtc** gate: `tests/chat-p2p.spec.ts` (N19 call+file+game na mesma conexão,
  N23 screen share) + `tests/chat-call-fault-injection.spec.ts` (N34 sobrevive a
  outage). **⚠️ `chat-call-fault-injection.spec.ts:348` FALHA na main ANTES de qualquer
  mudança** (baseline confirmado — dívida pré-existente, ver Achados adiados). Não
  culpar sua mudança por ele; e `chat-p2p.spec.ts:616` é flaky (passa no re-run).
- **group_call** gate: `tests/chat-group-call.spec.ts` — os flows-alvo que exercitam os
  4 handlers e os tiles: `two identified channel users`, `screen share replaces`,
  `participant quality and active speaker`, `mini mode keeps the call alive`, `layout
  controls focus tiles`, `reactions propagate`, `failed media recovery offers`,
  `moderator camera-off`, `bulk moderation`, `moderator can stop and block`, `three
  users renegotiate`. Todos passavam verdes no código atual (baseline estabelecido).

**Disciplina de baseline (paguei caro por pular):** ANTES de assumir que uma sua
mudança quebrou um E2E, restaure o código original com `git show HEAD:<path> > <path>`
(NUNCA `git checkout`), rebuild, rode — se falha na origem também, é pré-existente.

---

## 8. Ordem de execução sugerida

Um hook por vez; entre passos o outro fica funcional e o unit verde.

**Bloco 1 — lobby_webrtc (piloto, menor):**
1. Baseline E2E: rode `chat-p2p` + `chat-call-fault-injection` no código ATUAL, anote
   verdes/vermelhos (o :348 já é vermelho).
2. Transforme `lib/p2p/lobby_connection.js` em `createLobbyConnection(el, ports)` (§4.1).
3. Reescreva o hook como binding (§4.2). `make lint.hooks` + `make test.js`: os 2
   testes antigos QUEBRAM (esperado — a API mudou).
4. Reescreva os testes black-box em `test/lib/p2p/lobby_connection.test.js` (§4.3),
   apague os 2 antigos. Verde.
5. Baixe `MAX_HOOK_PRIVATE_CALLS` (§4.4). Reversão (quebre uma decisão, veja o teste de
   lib E o E2E reagirem). Surface `--check`.
6. Rebuild assets + E2E gate (§7). Compare com o baseline do passo 1.
7. `make ci` + push. Atualize `js-hooks-ledger.md` e `js-hooks-progress.md`.

**Bloco 2 — group_call (grande):** mesma receita (§5), gate `chat-group-call`.

**Bloco 3 — limpeza final:** re-auditar (§1 comando) → zero suspeitos em `js/lib`.
Confirmar `FORBIDDEN_PRIMITIVE_OVERRIDES` vazio, catraca no piso real.

---

## 9. Gotchas já pagos (não redescobrir)

1. **`git show`, nunca `git checkout`/`reset --hard`** para restaurar/baseline — o repo
   tem trabalho paralelo não-commitado; checkout destrói.
2. **`mix` roda da RAIZ do repo**, não de `apps/.../assets`.
3. **E2E precisa rebuild de assets** (`MIX_ENV=e2e mix assets.build`) e `:4003` livre —
   `reuseExistingServer: true` reusa um servidor velho com assets velhos.
4. **Superfície + reindentação:** ao aninhar o objeto mais fundo, o prettier quebra
   `addEventListener("evento", ...)` em várias linhas, e o grep line-based do
   `surface_snapshot.sh` (seção `custom-events`) **perde o nome do evento**. Já
   aconteceu com `group-call:participant-quality`. Correção certa: tornar o grep
   multi-linha (perl `-0777`), NÃO mascarar. Snippet:
   ```sh
   find js -name '*.js' -print0 | xargs -0 perl -0777 -ne \
     'while (/(?:CustomEvent|addEventListener|dispatchEvent)\(\s*"([a-zA-Z_0-9:.-]+)"/g){print "$1\n"}' \
     | LC_ALL=C sort -u
   ```
   Sempre confirmar que ainda pega um rename real (quebre um nome, `--check` deve sair 1).
5. **`await` de método async pode resolver cedo demais** em teste: `screenShareBlocked`
   (sync) passa mas `screenTrack.stop` (fundo na cadeia) não. Esperar pelo EFEITO final
   real com `vi.waitFor(() => expect(<efeito>).toHave...)`, não pelo retorno do `await`.
6. **Timer em máquina de estado:** resolver `setTimeout` no uso (`(setTimeoutFn || setTimeout)`),
   nunca capturar no closure da fábrica (o teste liga fake timers depois do mount).
7. **Import relativo ao mover** de `hooks/x/` para `lib/y/`: recalcular (`../../lib/p2p/z`
   → `../p2p/z` ou `./z`). Erro de caminho só aparece no vitest, não no eslint.
8. **Catraca estrita:** `MAX_HOOK_PRIVATE_CALLS` falha se o número for MENOR também —
   baixar no mesmo commit que reduz reaches.

---

## 10. Achados adiados (carregar, são bugs pré-existentes — NÃO corrigir de passagem)

Ver tabela completa em `docs/refactor/js-hooks-ledger.md` (seção "Achados adiados"):
- **Tab-cycle do cliente é dead code** (`lib/chat/tab_cycle.js` + autocomplete input
  listener) — corrigir muda comportamento.
- **`end_call` com payload vazio não empurra `call_ended`** (rtc_media_hook_factory).
- **Fábrica de mídia despacha 2 CustomEvents com nome literal** (não derivados de config).
- **`chat-call-fault-injection.spec.ts:348` vermelho na main** (baseline confirmado).

---

## 11. Definição de pronto (verificável)

1. `grep -cE "this\.(pushEvent|el\b|handleEvent)|mounted\(" js/lib/p2p/lobby_connection.js
   js/lib/group_call/conference_connection.js` = **0** nos dois.
2. Os hooks `lobby_webrtc_hook.js` e `group_call_webrtc_hook.js` são bindings (~15–25
   linhas): criam o controlador, registram `handleEvent`, delegam. Nenhuma decisão.
3. Controladores têm assinatura `createX(el, ports)`, estado no closure ou no objeto
   retornado (não em hook LiveView), API pública documentada.
4. Testes em `test/lib/**` dirigem a API pública black-box (mínimo de `._privado`);
   os antigos em `test/hooks/**` apagados.
5. `MAX_HOOK_PRIVATE_CALLS` no piso real; overrides dos dois hooks removidos;
   `FORBIDDEN_PRIMITIVE_OVERRIDES` vazio.
6. Reversão OK (quebrar decisão derruba unit + E2E) e **gate E2E verde** (menos o
   `:348` pré-existente), comparado a um baseline tirado ANTES.
7. Ledger e progress atualizados no mesmo commit.

---

## 12. Onde está tudo

- Padrão: `docs/AGENT-GUIDE.md` §15/§15.1 · `.claude/rules/assets-js.md`.
- Diário/ledger: `docs/refactor/js-hooks-progress.md` · `docs/refactor/js-hooks-ledger.md`.
- Referências de código: `js/hooks/connection/connection_status_hook.js` +
  `js/lib/connection/connection_status_view.js` (o padrão), e
  `js/lib/p2p/rtc_media_hook_factory.js` + `test/lib/p2p/rtc_media_hook_factory.test.js`
  (WebRTC black-box).
- Guard: `apps/retro_hex_chat_web/assets/scripts/enforce_hooks_contract.cjs`.
- Superfície: `apps/retro_hex_chat_web/assets/scripts/surface_snapshot.sh` + `js/SURFACE.txt`.
- Rede de teste: `apps/retro_hex_chat_web/assets/test/helpers/rtc_peer_connection.js`.
- E2E: `e2e/tests/{chat-p2p,chat-group-call,chat-call-fault-injection}.spec.ts` · `e2e/README.md`.
