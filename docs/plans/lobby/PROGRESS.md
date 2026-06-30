# Lobby (P2P Universal) — Progresso da Decomposição em Ilhas

Quadro central de progresso da decomposição do `LobbyLive`. **Atualize-o em todo loop
de implementação**, junto com o `## Progress Log` do plano individual. É o gêmeo do
`../PROGRESS.md` (que rastreou a migração — concluída — do ChatLive).

> Antes de qualquer coisa, leia [`00-OVERVIEW.md`](00-OVERVIEW.md) (arquitetura + 3
> contratos + cross-check do playbook) e `../STATEFUL-COMPONENT-PLAYBOOK.md` (receita +
> §9 windowing).

## Status Legend

- `pending`: ainda não iniciado.
- `in_progress`: iniciado, parcial ou aguardando validação.
- `blocked`: impedimento concreto, com próximo passo registrado.
- `complete`: tasks relevantes concluídas e validação registrada.

## Loop Rules

- **Leia o `STATEFUL-COMPONENT-PLAYBOOK.md` (esp. §9 windowing + §0a-anti) antes de
  cada extração.** Os 4 planos seguem o mesmo padrão — não redescubra armadilhas.
- **Respeite a ordem de tiers** (acoplamento crescente): 01 chat → 02 game → 03 file →
  04 media. Cada tier depende dos contratos provados no anterior.
- Antes de editar código, marque o plano escolhido como `in_progress` aqui.
- Depois de editar, registre evidência de validação (`make ci` 9/9 + spec Playwright).
- Nunca marque `complete` sem atualizar o checklist do plano individual.
- Sempre inclua o próximo passo.
- Registre **aprendizados novos** no `## Histórico de aprendizados` deste arquivo E,
  se forem reutilizáveis, na §9/Histórico do playbook.
- Use a data real do ambiente no momento da execução.

## Quadro de planos

| Tier | Plano | Ilha | Status | Contratos que estabelece/usa |
|---|---|---|---|---|
| 1 | [01](01-chat-island.md) | Chat | `pending` | **estabelece C1** (system-msg) |
| 2 | [02](02-game-island.md) | Game | `pending` | **estabelece C2+C3**; usa C1 |
| 3 | [03](03-file-island.md) | File | `pending` | usa C1/C2/C3; constraint hook-montado |
| 4 | [04](04-media-island.md) | Media | `pending` | usa todos; `surface_peer_media` |
| — | — | conn/telemetria + privacy + backbone WebRTC + taskbar | **fica no pai** (sem extração) | agregador / read-model |

## Mapa de Dependências & Armadilhas (para agentes de execução)

**Ordem obrigatória:** 01 → 02 → 03 → 04. Não pule.

- **01 Chat** é dona de `messages` (o sink de mensagens de sistema) → faça primeiro
  para o contrato **C1** existir quando 02/03/04 precisarem registrar mensagens.
- **02 Game** é a mais limpa (own-PubSub + own-window) → prova **C2** (read-model →
  taskbar) e **C3** (ilha dirige a própria janela), que 03/04 copiam.
- **03 File**: risco nº1 = **hook-sempre-montado** (ilha sempre montada, visibilidade
  por classe `u-hidden`, nunca `:if`). Sem PubSub (data-channel).
- **04 Media**: a gigante — sessão dedicada; `surface_peer_media` (auto-join +
  windowing) e o cenário de **vídeo bidirecional** (RTP real) são o que mais regride.
  NÃO tocar na negociação single-offerer (backbone do pai).

### ⚠️ A armadilha transversal (classe do bug do plano 41) — vale para 02/03/04

O `LobbyLive` tem `handle_info(_msg, socket)` catch-all em `lobby_live.ex:228` e só casa
`%{event:...}`. O bubble do contrato **C2** é uma TUPLA
(`send(self(), {:feature_summary, ...})`) → **cai no catch-all e é engolido em
silêncio.** Sempre adicione a cláusula `handle_info({:feature_summary, ...})` explícita
ACIMA da linha 228 e teste que o badge/strip muda.

### Armadilhas que NÃO se aplicam (já cruzadas — ver OVERVIEW)

Modal-in-modal (0 ocorrências), `render_submit`/`JS.push(value:)` (chat já é string +
campo nomeado), `select_item` (devices são `<select>` cru; layout/preset são string).

## Current Focus

- Nenhum plano iniciado. **Próximo:** 01 Chat (estabelece C1).
- Last updated: 2026-06-30

## Histórico de aprendizados

- 2026-06-30: Série planejada e cruzada com o código real (grep das armadilhas do
  playbook). Lobby é mais limpo que o ChatLive (sem modal-in-modal, form de chat já
  seguro, sem `select_item`). Única armadilha transversal = swallow do catch-all
  (linha 228) sobre o bubble C2 por tupla. Windowing confirmado compatível
  (`window_command` funciona de LiveComponent). Nenhuma implementação iniciada.
