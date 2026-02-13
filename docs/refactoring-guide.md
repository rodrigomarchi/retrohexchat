# Guia de Refatoracao — Arquivos Grandes

## Arquivos com 300+ linhas (codigo fonte)

| # | Arquivo | Linhas | Tipo | Severidade |
|---|---------|--------|------|------------|
| 1 | `retro_hex_chat_web/live/chat_live.ex` | **7.269** | LiveView | CRITICO |
| 2 | `retro_hex_chat/chat/help_topics.ex` | 1.876 | Data module | Alto |
| 3 | `retro_hex_chat_web/assets/css/layout.css` | 813 | CSS | Alto |
| 4 | `retro_hex_chat_web/components/address_book_dialog.ex` | 767 | Component | Alto |
| 5 | `retro_hex_chat/channels/server.ex` | 718 | GenServer | Alto |
| 6 | `retro_hex_chat_web/components/channel_central_dialog.ex` | 578 | Component | Medio |
| 7 | `retro_hex_chat_web/components/perform_dialog.ex` | 494 | Component | Medio |
| 8 | `retro_hex_chat_web/components/log_viewer_dialog.ex` | 387 | Component | Medio |
| 9 | `retro_hex_chat/chat/formatter.ex` | 377 | Parser | Medio |
| 10 | `retro_hex_chat/presence/notify_list.ex` | 358 | Context | Medio |
| 11 | `retro_hex_chat/accounts/session.ex` | 354 | Struct/Context | Medio |

### Parametros da comunidade Elixir/Phoenix

| Faixa | Avaliacao |
|-------|-----------|
| < 200 linhas | Ideal |
| 200-400 linhas | Aceitavel |
| 400-600 linhas | Sinal de alerta |
| > 600 linhas | Precisa refatorar |
| > 1.000 linhas | Definitivamente grande demais |

---

## Tecnicas de decomposicao

### 1. `attach_hook/4` — Extracao de event handlers (LiveView)

A tecnica **oficialmente recomendada** pelo Phoenix para extrair `handle_event` e `handle_info` de LiveViews grandes. Disponivel desde LiveView 0.17+.

**Como funciona:** Handlers sao definidos em modulos separados e registrados no `mount/3`. Cada hook retorna `{:halt, socket}` se tratou o evento, ou `{:cont, socket}` para passar adiante.

```elixir
# chat_live.ex — mount registra os hooks
def mount(_params, _session, socket) do
  socket =
    socket
    |> attach_hook(:alias_events, :handle_event, &ChatLive.AliasEvents.handle_event/3)
    |> attach_hook(:timer_events, :handle_event, &ChatLive.TimerEvents.handle_event/3)
    |> attach_hook(:dialog_events, :handle_event, &ChatLive.DialogEvents.handle_event/3)

  {:ok, socket}
end

# chat_live/alias_events.ex — modulo separado
defmodule RetroHexChatWeb.ChatLive.AliasEvents do
  import Phoenix.LiveView

  def handle_event("alias_add", params, socket) do
    {:halt, assign(socket, ...)}
  end

  def handle_event("alias_remove", %{"name" => name}, socket) do
    {:halt, assign(socket, ...)}
  end

  # OBRIGATORIO: catch-all retorna {:cont, socket}
  def handle_event(_event, _params, socket), do: {:cont, socket}
end
```

**Lifecycle stages suportados:** `:handle_params`, `:handle_event`, `:handle_info`, `:handle_async`, `:after_render`

**Fonte:** [Phoenix.LiveView docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)

### 2. Roteamento por prefixo — Delegacao direta

Alternativa mais simples quando nao se quer a semantica halt/cont dos hooks. O LiveView faz pattern match no nome do evento e delega.

```elixir
# chat_live.ex — thin routing layer
def handle_event("alias_" <> _rest = event, params, socket) do
  ChatLive.AliasEvents.handle(event, params, socket)
end

def handle_event("timer_" <> _rest = event, params, socket) do
  ChatLive.TimerEvents.handle(event, params, socket)
end

# chat_live/alias_events.ex
defmodule RetroHexChatWeb.ChatLive.AliasEvents do
  import Phoenix.LiveView

  def handle("alias_add", params, socket) do
    {:noreply, assign(socket, ...)}
  end
end
```

### 3. `on_mount` — Setup compartilhado entre LiveViews

Para logica de inicializacao reutilizada em multiplos LiveViews. Pode tambem registrar hooks.

```elixir
defmodule RetroHexChatWeb.InitAssigns do
  def on_mount(:default, _params, _session, socket) do
    socket = Phoenix.LiveView.assign(socket, :common_data, load_data())
    {:cont, socket}
  end
end

# No router
live_session :default, on_mount: RetroHexChatWeb.InitAssigns do
  live "/chat", ChatLive
end
```

**Fonte:** [Phoenix.LiveView on_mount docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)

### 4. LiveComponents — Subsistemas com estado proprio

Usar **somente** quando um pedaco da UI precisa de estado E event handling proprios. **NAO usar apenas para organizacao de codigo** — a documentacao oficial alerta contra isso.

```elixir
# Template do pai
<.live_component module={AliasDialog} id="alias-dialog" aliases={@aliases} />

# Componente com estado proprio
defmodule RetroHexChatWeb.AliasDialog do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="dialog">...</div>
    """
  end

  def handle_event("save", params, socket) do
    {:noreply, assign(socket, ...)}
  end

  # Comunica com o pai via send
  def handle_event("close", _params, socket) do
    send(self(), :close_alias_dialog)
    {:noreply, socket}
  end
end
```

**Fonte:** [WyeWorks: Breaking up a Phoenix LiveView](https://www.wyeworks.com/blog/2020/03/03/breaking-up-a-phoenix-live-view/)

### 5. "Kill Your Fat Context" — Decomposicao de contextos

Padrao de Peter Ullrich para quebrar contextos monoliticos em 4 camadas:

```
MyApp.Chat/
  ├── alias_list.ex       # CRUD puro (Repo layer)
  ├── finders/
  │   └── active_aliases.ex   # Queries complexas
  ├── services/
  │   └── expand_alias.ex     # Logica de negocio
  └── chat.ex                 # Facade com defdelegate
```

```elixir
# Facade — API publica limpa
defmodule MyApp.Chat do
  defdelegate add_alias(session, name, expansion), to: MyApp.Chat.AliasList
  defdelegate expand(session, text), to: MyApp.Chat.AliasExpander
end
```

**Fonte:** [Peter Ullrich: Kill your Phoenix Context](https://peterullrich.com/phoenix-contexts)

### 6. Functional Core / Imperative Shell

Separar logica pura (testavel sem side effects) dos handlers do LiveView:

```elixir
# Core puro — sem side effects
defmodule RetroHexChat.Chat.AliasExpander do
  @spec expand(String.t(), [AliasEntry.t()]) :: String.t()
  def expand(text, aliases) do
    # transformacao pura
  end
end

# Shell imperativo — LiveView handler
def handle_event("send_message", %{"text" => text}, socket) do
  expanded = AliasExpander.expand(text, socket.assigns.aliases)
  # side effects: broadcast, assign, etc.
  {:noreply, socket}
end
```

**Fonte:** [ElixirMerge: Refactoring Large Legacy Modules](https://elixirmerge.com/p/refactoring-a-large-legacy-elixir-module-for-readability-and-testability)

### 7. CSS — Separacao por responsabilidade

Para `layout.css` (813 linhas), dividir em arquivos tematicos:

```
assets/css/
  ├── layout.css          # Grid, containers, posicionamento
  ├── components.css      # Botoes, inputs, tabs
  ├── dialogs.css         # Estilos dos dialogs (address book, channel central, etc.)
  ├── chat.css            # Area de chat, mensagens, nicklist
  └── dark-theme.css      # Overrides para tema escuro
```

---

## Estrategia de organizacao por arquivo

### `chat_live.ex` (7.269 linhas) — PRIORIDADE 1

Estrutura proposta:

```
live/
  ├── chat_live.ex              # mount, render, assign_defaults (~500 linhas)
  └── chat_live/
      ├── alias_events.ex       # handle_event "alias_*"
      ├── timer_events.ex       # handle_event "timer_*"
      ├── dialog_events.ex      # handle_event para abrir/fechar dialogs
      ├── channel_events.ex     # handle_event join/part/switch/topic
      ├── message_events.ex     # handle_event send_message, formatting
      ├── perform_events.ex     # handle_event perform_*
      ├── context_menu_events.ex # handle_event context menu actions
      ├── pubsub_handlers.ex    # handle_info para broadcasts PubSub
      ├── timer_handlers.ex     # handle_info para timers internos
      └── helpers.ex            # funcoes auxiliares compartilhadas
```

### `help_topics.ex` (1.876 linhas) — PRIORIDADE 2

Arquivo de dados (listas de topicos). Opcoes:
- Manter como esta (dados estaticos sao aceitaveis em arquivo grande)
- Ou dividir por categoria: `help_topics/commands.ex`, `help_topics/features.ex`, etc.

### `server.ex` (718 linhas) — PRIORIDADE 3

```
channels/
  ├── server.ex                 # GenServer callbacks, state init (~300 linhas)
  └── server/
      ├── message_handling.ex   # send_message, broadcast logic
      ├── mode_handling.ex      # mode changes (+b, +e, +I, +k, etc.)
      └── membership.ex         # join, part, kick, ban
```

### Dialogs (494-767 linhas) — PRIORIDADE 4

Cada dialog grande pode extrair sub-componentes como function components:

```
components/
  ├── address_book_dialog.ex          # Shell + tab routing (~200 linhas)
  └── address_book_dialog/
      ├── contacts_tab.ex             # Function component
      ├── notify_tab.ex               # Function component
      ├── nick_colors_tab.ex          # Function component
      └── control_tab.ex              # Function component
```

---

## Principios de navegabilidade

1. **Um modulo, uma responsabilidade** — cada arquivo deve ter um proposito claro pelo nome
2. **Path = namespace** — `ChatLive.AliasEvents` vive em `chat_live/alias_events.ex`
3. **Maximo ~300 linhas por arquivo** — acima disso, buscar oportunidade de extracao
4. **Facade pattern** — modulo principal delega para submodulos, servindo como indice navegavel
5. **Nomenclatura semantica** — nomes descrevem *o que*, nao *como* (`MessageHandling`, nao `Utils`)
6. **Agrupamento por feature** — prefira agrupar por funcionalidade (alias, timer, perform) sobre agrupar por tipo (handlers, helpers)

---

## Referencias

- [Phoenix.LiveView — attach_hook](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [Peter Ullrich: Kill your Phoenix Context](https://peterullrich.com/phoenix-contexts)
- [WyeWorks: Breaking up a Phoenix LiveView](https://www.wyeworks.com/blog/2020/03/03/breaking-up-a-phoenix-live-view/)
- [Curiosum: Context Maintainability Guidelines](https://www.curiosum.com/blog/elixir-phoenix-context-maintainability-guildelines)
- [Hanso: LiveView Best Practices](https://www.hanso.group/weblog/phoenix-liveview-best-practices)
- [ElixirForum: How to structure a large LiveView app](https://elixirforum.com/t/how-to-structure-a-large-live-view-app/65192)
- [ElixirForum: Defoverridable function fallbacks](https://elixirforum.com/t/defoverridable-function-fallbacks-for-liveview-callbacks/66471)
- [Elixir Refactorings Catalog](https://github.com/lucasvegi/Elixir-Refactorings)
- [ElixirMerge: Refactoring Large Legacy Modules](https://elixirmerge.com/p/refactoring-a-large-legacy-elixir-module-for-readability-and-testability)
