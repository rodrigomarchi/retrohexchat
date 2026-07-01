# Lobby — File Transfer Island

> Pré-requisito de leitura: [`00-OVERVIEW.md`](00-OVERVIEW.md) e
> `../STATEFUL-COMPONENT-PLAYBOOK.md`. Depende de
> [`02-game-island.md`](02-game-island.md) (padrões C2/C3 já provados).

## Objetivo

Extrair a transferência de arquivos para
`RetroHexChatWeb.App.LobbyLive.Components.FileIsland`, dona de `file_transfer` e
`file_transfer_ready`, e da família `ft_*`. Feature coesa e **sem PubSub** (o
controle anda no data channel `filetransfer`, não no tópico do lobby).

## Classificação para execução (agentes)

- **Tier:** 🟡 Mecânico-com-cuidado — família `ft_*` grande (~18 eventos), mas toda
  da mesma feature; cross-read só via resumo (C2) e 1 msg de sistema (C1).
- **Dependências:** entra C1/C2/C3 (já provados em 01/02).
- **Componente de referência:** GameIsland (02) para C2/C3; o `FileTransferHook` do
  chat para os push_events `ft_*`.
- **Abordagem:** ilha dona de `file_transfer` + toda a família `ft_*` + config push;
  dirige a janela `file`; espelha resumo (percent) para a taskbar.
- **Gotchas:** **o hook de file deve ficar montado a conexão inteira** (constraint do
  `universal-lobby`): a seção é `:if={connected}` com visibilidade via classe
  `u-hidden`, NÃO `:if` da janela. A ilha (sempre montada) preserva isso
  naturalmente. `ft_config` depende de `file_transfer_ready` — push após ready.
- **Validação:** `make ci` 9/9 + `chat-lobby.spec.ts` (file durante call/game,
  decline, blocked-extension).

## Código atual

- Render: `universal_lobby.ex:250-269` (janela `file`, `on_close="ft_cancel"` →
  `<.file_panel file_transfer= nickname= max_file_size_mb= blocked_file_extensions= />`).
- Panel (stateless): `components/ui/lobby/file_panel.ex`.
- Assigns: `file_transfer` (`lobby_live.ex:674`), `file_transfer_ready` (`:675`).
  Derivados em `universal_lobby.ex`: `file_active` (`:93-95`), `max_file_size_mb`
  (`:96`), `blocked_file_extensions` (`:97`).
- Família `ft_*` (todos hook-driven, `lobby_live.ex`):
  `file_transfer_ready` (`:448`, ensure + push `ft_config`), `ft_offer_sent` (`:456`),
  `ft_offer_received` (`:461`, **`window_command open file`**), `ft_respond`
  (`:468`/`:472`), `ft_accepted` (`:476`), `ft_progress` (`:481`), `ft_completed`
  (`:494`, **msg de sistema C1** + re-push config), `ft_failed` (`:508`),
  `ft_cancelled` (`:515`, **`window_command close file`**), `ft_reset` (`:523`),
  `ft_validation_error` (`:527`), `ft_accept_offer` (`:534`), `ft_cancel` (`:540`,
  push cancel + **`window_command close file`**), `ft_retry` (`:547`), `ft_paused`
  (`:551`), `ft_resumed` (`:558`), `ft_queued`/`ft_rejected` (`:565`, no-op swallow).
- push_events ao hook: `ft_config` (`:737`), `ft_accept` (`:469`,`:535`), `ft_reject`
  (`:473`), `ft_cancel` (`:543`), `ft_retry` (`:548`).
- Taskbar badge: `file_active` → `#{percent}%` (`universal_lobby.ex:383`) → **C2**.

## Técnica

LiveComponent statefull montado na janela `file`, **sempre montado** (preserva o hook
de file vivo a conexão inteira). Dono de `file_transfer`/`file_transfer_ready` e de
toda a família `ft_*` (component-local, pois são hook-driven e não precisam do pai).

- **C3:** `ft_offer_received` abre, `ft_cancelled`/`ft_cancel` fecham a janela `file`
  — todos `window_command` saindo da ilha. `on_close="ft_cancel"`
  (`universal_lobby.ex:254`) vira adapter/`phx-target` na ilha.
- **C2:** ao mudar `file_transfer.status`/`percent`, emitir `{:feature_summary,
  :file, %{active?, percent}}`; pai guarda `file_summary` para o badge.
- **C1:** `ft_completed` → `send_update(ChatIsland, system_message:)`.
- `ft_config` (limites de tamanho/extensão) é computado a partir de
  `Application.get_env` — move com a ilha (helpers `file_transfer_max_size_mb/0` e
  `_blocked_extensions/0` de `universal_lobby.ex:426-436` migram p/ a ilha).

## Tasks

- [x] Criar `Components.FileIsland` (raiz `<div id={@id} class="h-full">` estável,
      `@id` no mount, **sempre montado**).
- [x] Mover `file_panel` + os helpers de limite (`max_file_size_mb`/`blocked_extensions`)
      para a ilha.
- [x] Migrar a família `ft_*` — **NÃO component-local**: o hook faz `pushEvent` para a
      LV raiz, então o host forwarda via 2 adapters (`file_transfer_ready` + genérica
      `"ft_" <> _`) → `send_update(FileIsland, action: {:ft_event, name, params})`; a ilha
      despacha por nome.
- [x] C3: `window_command {open|close, "file"}` + os push_events ao hook saem da ilha
      (de `update/2`); `ft_cancel` (on_close da janela + botão do widget) via adapter.
- [x] C2: ilha emite `{:feature_summary, :file, %{status, sender_nick, percent, speed,
      file_name}}`; pai guarda `file_summary`; taskbar (badge `%`) E strip da janela
      `conn` leem dele.
- [x] C1: `ft_completed` (na ilha) → `send_update(ChatIsland, system_message:)` (+ Logger
      com token passthrough).
- [x] Constraint de montagem garantido: ilha sempre montada (`live_component`, não
      `:if`); janela só esconde via classe. Teste cobre que `ft_cancel` não desmonta o
      hook.
- [x] Removidos do pai `file_transfer`/`file_transfer_ready` + helpers
      (`ensure_file_transfer`/`maybe_push_ft_config`/`ft_meta`); template usa
      `file_summary`.
- [x] Teste de unidade: render por status alcançável em 1 update (connect-prompt/ready-
      browse/offer_received/validation_error), id/data-testid. Estados multi-step
      (transferring/paused/failed) ficam no E2E.

## Armadilhas cruzadas (verificadas contra o código)

- ⚠️ **C2 swallow (linha 228):** o resumo de `%` para o badge é
  `send(self(), {:feature_summary, :file, %{active?, percent}})` (tupla) → exige
  `handle_info({:feature_summary, :file, ...})` explícito ACIMA do catch-all, senão o
  badge `%` nunca atualiza. Mesma classe do bug do plano 41.
- ⚠️ **Constraint de hook-sempre-montado é o risco nº1 desta ilha** (memória
  `universal-lobby`, ponto 3): o `FileTransferHook`/data-channel não pode desmontar
  quando a janela fecha — a ilha é SEMPRE montada, visibilidade por classe `u-hidden`,
  nunca `:if`. Um teste deve garantir que fechar a janela `file` não interrompe uma
  transferência em curso.
- ✅ `<input type=file>` é hook-driven (`file_panel.ex:41`), não é form submit → sem
  trap de `JS.push(value:)`. Zero modal-in-modal.
- ⚠️ `send_update` assíncrono sob LiveViewTest → flush via `render(view)`.

## Validação

- [x] Enviar arquivo durante call/game: oferta → janela `file` abre (C3), progresso,
      conclusão → msg de sistema (C1), badge % na taskbar (C2). (E2E file-during-call +
      file-during-game; lobby_live_test C2 badge `50%`.)
- [x] Recusar oferta: estado volta a "ready". (E2E + unit ready/browse.)
- [x] Extensão bloqueada: `ft_validation_error` renderiza o erro. (E2E blocked + unit.)
- [x] Cancelar (X / `ft_cancel`): janela fecha (C3), peer notificado. (lobby_live_test
      `assert_push_event window_command close file` com flush.)
- [x] Fechar a janela `file` NÃO desmonta o hook (constraint). (lobby_live_test
      "the file transfer hook stays mounted".)
- [x] `make ci` **9/9** (2026-06-30); `chat-lobby.spec.ts` **20/20** (1 flake na
      bidirectional-video — mídia, alheia ao file; passou no retry isolado).

## Prompt de execução

Leia OVERVIEW + playbook. Atenção ao constraint de hook-sempre-montado (ilha sempre
montada, visibilidade por classe). Copie C2/C3 da GameIsland. Sem PubSub aqui.

## Progress Log

- 2026-06-30: Planejado. Não iniciado.
- 2026-06-30: `in_progress`. Escopo: criar
  `RetroHexChatWeb.App.LobbyLive.Components.FileIsland` (dona de
  `file_transfer`/`file_transfer_ready`; SEMPRE montada → hook vivo a conexão inteira).
  **Descoberta-chave:** o `FileTransferHook` faz `pushEvent` para a LV RAIZ (não para o
  LiveComponent), então a família `ft_*` NÃO pode ser component-local — fica no host
  como **adapters finos**: 2 cláusulas (`file_transfer_ready` + genérica `"ft_" <> _`)
  que fazem `send_update(FileIsland, action: {:ft_event, name, params})`. A ilha
  despacha por nome em `update/2` e dispara de volta os push_events ao hook (`ft_config`/
  `ft_accept`/`ft_reject`/`ft_cancel`/`ft_retry`) + `window_command` (C3) — tudo funciona
  de `update/2`. **C2:** `file_summary` (status/sender_nick/percent/speed/file_name)
  espelhado ao host para o badge `%` E a strip da janela `conn` (cross-read rico);
  `handle_info({:feature_summary, :file, summary})` ACIMA do catch-all. **C1:**
  `ft_completed` (na ilha) → `send_update(ChatIsland, system_message:)` + Logger (token
  passthrough). Helpers de config (`max_size_mb`/`blocked_extensions`) migram p/ a ilha.
  Arquivos: `file_island.ex` (novo), `file_island_test.exs` (novo), `lobby_live.ex`,
  `universal_lobby.ex`, `lobby_live.html.heex`, `lobby_live_test.exs` (flush + teste de
  hook-persistente). Validação planejada: `make ci` 9/9 + `chat-lobby.spec.ts`
  (file durante call/game, decline, blocked-extension).
- 2026-06-30: `complete`. Implementado conforme o escopo. **Descoberta central
  confirmada:** `FileTransferHook.pushEvent` vai para a LV RAIZ, não para o LiveComponent
  — então a família `ft_*` NÃO pôde ser component-local; ficou no host como 2 adapters
  (`file_transfer_ready` + `"ft_" <> _`) que collapsam ~18 handlers em 2 linhas cada,
  forwardando `{:ft_event, name, params}` para a ilha. A ilha despacha por nome em
  `update/2` e dispara de volta os push_events ao hook (`ft_config`/`ft_accept`/
  `ft_reject`/`ft_cancel`/`ft_retry`) + `window_command` — tudo de `update/2`. **C2 com
  cross-read rico:** a strip da janela `conn` lê status/sender_nick/percent/speed/
  file_name de `file_transfer`, então `file_summary` espelha exatamente esses 5 campos
  (não só o `%` do badge) via `Map.take`; `handle_info({:feature_summary, :file,
  summary})` ACIMA do catch-all. **Constraint:** ilha sempre montada → hook vivo; teste
  prova que `ft_cancel` (fechar janela) mantém `phx-hook="FileTransferHook"` no DOM.
  **Validação real:** `make ci` **9/9**; `chat-lobby.spec.ts` **20/20** (1 flake na
  bidirectional-video — mídia/RTP, alheia a este plano; passou isolada no retry).
  Unit FileIsland 5/5; lobby_live_test 21/21 (inclui hook-persistente + C2 file badge).
  Arquivos: `file_island.ex` (novo, ~250 ln), `file_island_test.exs` (novo),
  `lobby_live.ex` (encolheu muito), `universal_lobby.ex`, `lobby_live.html.heex`,
  `lobby_live_test.exs`. Aprendizado novo: hook compartilhado que faz `pushEvent` (raiz)
  → eventos de entrada são adapters no host; só os de SAÍDA (push_event/window_command)
  saem da ilha.
