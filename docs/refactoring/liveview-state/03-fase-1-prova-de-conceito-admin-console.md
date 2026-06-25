# Fase 1 — Prova de conceito: extrair o Admin Console

**Objetivo:** mover todo o estado e os eventos do Admin Console para um
`LiveComponent` isolado, provando o padrão antes de replicá-lo. É o maior
ganho isolado (**~32 assigns**) e um piloto de baixo risco (é um diálogo de
admin, com superfície de teste contida).

**Resultado esperado:** `assign_defaults/1` perde ~32 assigns; o módulo
`ChatLive.AdminConsoleEvents` encolhe drasticamente; nasce o **primeiro
`LiveComponent` do projeto**, servindo de molde para a Fase 2.

## Estado e código envolvidos hoje

Assigns no socket raiz (`live/app/chat_live.ex`, dentro de
`assign_defaults/1` a partir de `:622`):

```
show_admin_console, admin_console_results, admin_console_tab,
admin_console_motd, admin_console_motd_result, admin_console_broadcast_result,
admin_console_turn_stats, ... (~32 chaves admin_console_*)
```

Eventos hoje em `live/chat_live/admin_console_events.ex` (1.185 linhas, 18
`assign`s) — anexado como hook em `live/app/chat_live.ex:541`:

```elixir
{:admin_console_events, &ChatLive.AdminConsoleEvents.handle_event/3},
```

Apresentação (function component stateless) em
`components/ui/dialogs/admin_console_dialog.ex`, chamado no template
`live/app/chat_live.html.heex`.

## Passo a passo

### 1. Criar o componente

Arquivo novo: `live/chat_live/components/admin_console_component.ex`.

```elixir
defmodule RetroHexChatWeb.ChatLive.Components.AdminConsoleComponent do
  @moduledoc """
  Diálogo do Admin Console como LiveComponent stateful.

  Possui o próprio estado de UI (aba ativa, resultados de console, MOTD,
  resultado de broadcast, etc.). O ChatLive pai apenas decide montá-lo
  (via `show_admin_console`) e passa o que é de domínio (`session`).
  """
  use RetroHexChatWeb, :live_component

  alias RetroHexChatWeb.Components.UI.Dialogs

  @impl true
  @spec update(map(), Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:tab, fn -> "console" end)
     |> assign_new(:results, fn -> [] end)
     |> assign_new(:motd, fn -> nil end)
     |> assign_new(:motd_result, fn -> nil end)
     |> assign_new(:broadcast_result, fn -> nil end)
     |> assign_new(:turn_stats, fn -> nil end)}
     # ... demais defaults que hoje moram em assign_defaults/1 ...
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  # Eventos que SÓ mexem na UI do diálogo ficam aqui (phx-target={@myself}).
  def handle_event("admin_console_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab: tab)}
  end

  # Eventos que tocam DOMÍNIO (executar comando admin, broadcast, etc.):
  # chamam o contexto Admin diretamente e atualizam só os assigns de
  # resultado do próprio componente.
  def handle_event("admin_console_run", %{"command" => cmd}, socket) do
    result = RetroHexChat.Admin.run_console_command(socket.assigns.session, cmd)
    {:noreply, assign(socket, results: [result | socket.assigns.results])}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    # Reaproveita o function component de apresentação JÁ existente,
    # passando os assigns do PRÓPRIO componente. Zero retrabalho de UI.
    ~H"""
    <div>
      <Dialogs.admin_console_dialog
        show={true}
        myself={@myself}
        active_tab={@tab}
        results={@results}
        motd={@motd}
        motd_result={@motd_result}
        broadcast_result={@broadcast_result}
        turn_stats={@turn_stats}
        on_tab="admin_console_tab"
        on_close="close_admin_console"
      />
    </div>
    """
  end
end
```

> **Por quê `assign_new`?** Inicializa o estado de UI uma única vez quando o
> componente monta, sem redefinir a cada `update/2` (evita resetar rascunhos —
> a mesma armadilha "estado transitório x permanente" citada pela comunidade).

### 2. Ajustar o function component de apresentação

`components/ui/dialogs/admin_console_dialog.ex` ganha um attr `myself` e troca
os `phx-click="..."` por `phx-click="..." phx-target={@myself}`, de forma que os
eventos do diálogo sejam roteados para o componente, não para o `ChatLive`.

> O markup permanece idêntico — só muda o alvo do evento. Sem mudança visual.

### 3. Substituir a chamada no template do `ChatLive`

Em `live/app/chat_live.html.heex`, trocar a chamada do function component:

```heex
<%!-- ANTES: function component recebendo ~20 atributos do socket raiz --%>
<.admin_console_dialog
  show={@show_admin_console}
  active_tab={@admin_console_tab}
  results={@admin_console_results}
  ... />

<%!-- DEPOIS: LiveComponent montado sob demanda, recebe só o domínio --%>
<.live_component
  :if={@show_admin_console}
  module={RetroHexChatWeb.ChatLive.Components.AdminConsoleComponent}
  id="admin-console"
  session={@session}
/>
```

> `:if={@show_admin_console}` garante que o componente **só existe** quando o
> diálogo está aberto — o estado some ao fechar, exatamente o que queremos.

### 4. Enxugar o `ChatLive`

- Remover de `assign_defaults/1` (`live/app/chat_live.ex:622`) **todos** os
  assigns `admin_console_*` (mantendo apenas `show_admin_console`, que é
  visibilidade e pertence ao pai).
- Manter no hook `ChatLive.AdminConsoleEvents` **apenas** os eventos de
  abrir/fechar (`open_admin_console` → `assign(show_admin_console: true)` e
  `close_admin_console` → `assign(show_admin_console: false)`). Migrar todo o
  resto para o componente.
- Se o módulo de eventos ficar trivial, considerar movê-lo para o hook
  genérico de diálogos (avaliado na Fase 3).

### 5. Mover/ajustar lógica de domínio

Qualquer lógica de negócio em `admin_console_events.ex` que ainda não esteja em
um contexto deve ser empurrada para `RetroHexChat.Admin` (cumprindo
*"LiveViews MUST be thin"* da `CLAUDE.md`). O componente apenas **chama** o
contexto.

## Testes

- Adaptar os testes existentes do Admin Console. Eventos do diálogo agora são
  testados via `Phoenix.LiveViewTest` com `element/2` apontando para o
  componente (`[id="admin-console"]`).
- Garantir cobertura: abrir → trocar de aba → rodar comando → fechar → reabrir
  (estado deve nascer limpo na reabertura).
- Rodar `make ci` e confirmar **0** regressões (incluindo dialyzer, pois o
  novo módulo precisa de `@spec`).

## Critérios de pronto (Fase 1)

- [ ] Existe `AdminConsoleComponent` usando `:live_component`.
- [ ] `assign_defaults/1` não contém mais assigns `admin_console_*` (exceto
      `show_admin_console`).
- [ ] Eventos de UI do Admin Console usam `phx-target={@myself}`.
- [ ] Nenhuma mudança visual perceptível (markup reaproveitado).
- [ ] `make ci` verde.
- [ ] Documentação de ajuda revisada se algum texto referenciava o fluxo
      (ver regra de Help System na `CLAUDE.md`).
