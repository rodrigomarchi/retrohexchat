# Fase 0 — Diagnóstico

Medição objetiva dos LiveViews que concentram estado, com referências ao
código. Tudo aqui foi medido sobre o estado atual do repositório.

## Visão geral dos ofensores

| # | LiveView | Linhas (módulo) | Total c/ handlers | `assign`s no socket | `handle_event` | `handle_info` | Gravidade |
|---|----------|----------------:|------------------:|--------------------:|---------------:|--------------:|-----------|
| 1 | `live/app/chat_live.ex` + cluster `live/chat_live/` (65 módulos) | 1.273 | **18.145** | **≈ 260** + struct `Session` (28 campos) | **479** | **123** | 🔴 Crítico |
| 2 | `live/app/p2p_session_live.ex` | 1.377 | 1.377 (monolítico) | ≈ 60–90 | ~55 | ~15 | 🔴 Crítico |
| 3 | `live/app/game_session_live.ex` | 822 | 822 (monolítico) | ~30 | ~12 | 🟠 Alto |
| 4 | `live/app/solo_session_live.ex` | 361 | 361 | ≈ 25 | ~12 | 🟡 Médio |
| 5 | `live/app/connect_live.ex` | 420 | 420 | ≈ 13 | ~6 | 🟢 OK |
| 6 | `live/app/arcade_game_live.ex` | 114 | 114 | ≈ 9 | ~4 | 🟢 OK |

> As ~90 páginas em `live/showcase_live/` são catálogo de componentes (estado
> trivial) e estão fora de escopo.

## Ofensor nº 1 em detalhe: o cluster `ChatLive`

O arquivo `live/app/chat_live.ex` parece fino (1.273 linhas), mas isso é
ilusório. Ele anexa **31 módulos de eventos + 2 de info** via `attach_hook`,
todos operando **sobre o mesmo socket**.

Referência — a lista de hooks anexados em
`live/app/chat_live.ex:569` (`attach_all_hooks/1`):

```elixir
# live/app/chat_live.ex:569
defp attach_all_hooks(socket) do
  event_hooks = [
    {:emoji_events, &ChatLive.EmojiEvents.handle_event/3},
    {:admin_console_events, &ChatLive.AdminConsoleEvents.handle_event/3},
    {:channel_central_events, &ChatLive.ChannelCentralEvents.handle_event/3},
    # ... 31 módulos no total
  ]
  # ...
end
```

Somando o cluster (`chat_live.ex` + `chat_live/`):

- **18.145 linhas** manipulando um único socket.
- **479 cláusulas `handle_event`** e **123 `handle_info`**.
- **65 módulos** que leem/escrevem o mesmo namespace de assigns, sem fronteira.

### A raiz do problema: `assign_defaults/1`

A função `live/app/chat_live.ex:622` declara **~260 chaves de assign de
primeiro nível** numa única chamada. Trechos representativos:

```elixir
# live/app/chat_live.ex:622
defp assign_defaults(socket, session) do
  socket
  |> assign(
    channel_users: [],
    # ... estado de UI de diálogos misturado com estado de domínio ...
    show_admin_console: false,
    admin_console_results: [],
    admin_console_tab: "console",
    admin_console_motd: nil,
    # ... +250 chaves ...
    channel_list_count: 0
  )
end
```

### Composição do estado (por que é grave)

| Grupo de estado | Nº de assigns | Natureza |
|---|---:|---|
| Flags de diálogo/visibilidade (`show_*`, `*_visible`, `*_dialog`) | ~51 | UI pura no socket raiz |
| `admin_console_*` | ~32 | console de admin inteiro embutido |
| `channel_central_*` | ~17 | um diálogo complexo inteiro |
| `search_*` | ~12 | estado de busca (transitório) |
| `account_*` | ~10 | diálogo de conta |
| `autocomplete_*` | ~6 | autocomplete do input |
| `url_catcher_*`, `timers_dialog_*`, `alias_dialog_*`, `custom_menus_*`, `autorespond_*` | ~30 | cada diálogo replica seu próprio mini-CRUD |
| `session` (struct) | 1 assign / **28 campos** | god-object de domínio |

**~50% dos assigns são estado de UI** (flags `show_*`, posições `x/y` de menus
de contexto, abas selecionadas, rascunhos de formulário). Isso infla o diff de
cada render e impede raciocinar sobre o que muda.

### Diálogos são function components que recebem o estado por atributo

Hoje os diálogos são **function components stateless** que recebem dezenas de
atributos vindos dos assigns do pai. Exemplo real em
`live/app/chat_live.html.heex:776`:

```heex
<.channel_central_dialog
  show={@show_channel_central}
  active_tab={@channel_central_tab}
  channel_name={@channel_central_channel}
  operator={@channel_central_operator}
  owner={@channel_central_owner}
  notice={@channel_central_notice}
  transfer_error={@channel_central_transfer_error}
  access_tab={@channel_central_access_tab}
  cs_error={@channel_central_cs_error}
  # ... ~25 atributos, cada um espelhando um assign do socket raiz ...
  on_close="close_channel_central"
/>
```

É **exatamente por isso** que o `ChatLive` tem ~260 assigns: o estado de cada
diálogo vive no pai e é "costurado" como atributo. Os componentes existem em
`components/ui/dialogs/` (ex.: `channel_central_dialog.ex`,
`admin_console_dialog.ex`), mas são burros — toda a memória está no pai.

### Descoberta-chave: o projeto NÃO usa `LiveComponent`

Busca por `use ..., :live_component` em todo `apps/retro_hex_chat_web/lib`
retorna **zero resultados**. Todos os componentes são function components
stateless. Essa é a causa estrutural do god socket e o eixo central da
refatoração (ver [02-arquitetura-alvo.md](./02-arquitetura-alvo.md)).

## O que já está correto (não mexer)

- **`ChatLive` já usa `streams` para mensagens.** O template
  `live/app/chat_live.html.heex:219` usa `phx-update="stream"` com
  `@streams.chat_messages` e `@streams.status_messages`. A função
  `refresh_active_message_stream/2` vive em
  `live/chat_live/helpers/session.ex:55`. **Não há migração de mensagens a
  fazer no `ChatLive`** — isso é uma força do código atual.
- **Estado morto a remover:** o assign `messages: %{}` em
  `assign_defaults/1` parece vestigial (sem leitura via `@messages` no
  template). Confirmar e remover na Fase 3.

## Ofensores nº 2 e nº 3

- **`live/app/p2p_session_live.ex`** — 1.377 linhas num **único arquivo
  monolítico** (não decomposto como o `ChatLive`). Acumula mensagens com
  **append em lista**, anti-padrão que reenvia a coleção a cada render:

  ```elixir
  # live/app/p2p_session_live.ex:782
  {:noreply, assign(socket, messages: socket.assigns.messages ++ [msg])}
  ```

  Aqui `streams` **se aplica** (ao contrário do `ChatLive`). Ver
  [06-fase-4-p2p-e-game-session.md](./06-fase-4-p2p-e-game-session.md).

- **`live/app/game_session_live.ex`** — 822 linhas monolíticas com ~40 assigns
  gerenciando estado de jogo P2P, turnos e sincronização.

## Metas mensuráveis

| Métrica | Hoje | Alvo |
|---|---:|---:|
| Assigns de primeiro nível em `assign_defaults/1` | ~260 | ~80–100 |
| Flags `show_*` no socket raiz | ~51 | ~20 (apenas montar/desmontar componentes) |
| `LiveComponent`s no projeto | 0 | ≥ 8 (um por diálogo complexo) |
| `p2p_session_live` usando `streams` p/ mensagens | não | sim |
| `make ci` | verde | verde (em cada fase) |
