defmodule RetroHexChatWeb.Components.UI.Autocomplete do
  @moduledoc """
  Autocomplete dropdown component for the v2 design system.

  Accepts native data from `Commands.Autocomplete` directly — no translation layer.

  Multi-mode dropdown supporting commands, nicks, channels, and subcommands
  with category headers and keyboard navigation highlight.

  ## Data formats per mode

  - `:command` — list of strings (category headers) and maps with `name`, `description`
  - `:nick` — list of maps with `nickname`, `status` (`:online`/`:away`), `color_class`
  - `:channel` — list of maps with `name`, `user_count`, `joined?`
  - `:subcommand` — list of maps with `name`, `description`
  """
  use RetroHexChatWeb.Component

  @doc "Renders the autocomplete dropdown."
  attr :items, :list, default: []
  attr :selected_index, :integer, default: 0
  attr :visible, :boolean, default: true, doc: "Show/hide the dropdown"

  attr :mode, :atom,
    default: :command,
    values: [:command, :nick, :channel, :subcommand],
    doc: "Rendering mode"

  attr :command, :string, default: nil, doc: "Parent command for subcommand click events"
  attr :on_select, :any, default: nil, doc: "Item click callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec autocomplete(map()) :: Phoenix.LiveView.Rendered.t()
  def autocomplete(assigns) do
    ~H"""
    <div
      :if={@visible}
      class={
        classes([
          "shadow-retro-window bg-surface border border-border w-[280px] max-h-[200px] overflow-y-auto retro-scrollbar",
          @class
        ])
      }
      data-testid="autocomplete-dropdown"
      {@rest}
    >
      <%= if @items == [] do %>
        <div
          class="px-retro-4 py-retro-8 text-xs text-muted-foreground text-center"
          data-testid="autocomplete-empty"
        >
          No results
        </div>
      <% else %>
        {render_items(assigns)}
      <% end %>
    </div>
    """
  end

  # ── Command mode — mixed strings (headers) and maps ──────────

  defp render_items(%{mode: :command} = assigns) do
    assigns = assign(assigns, :indexed_items, index_selectable_items(assigns.items))

    ~H"""
    <%= for {item, selectable_idx} <- @indexed_items do %>
      <%= if is_binary(item) do %>
        <div class="px-retro-4 py-retro-2 text-[10px] font-bold text-muted-foreground bg-surface border-b border-border">
          {item}
        </div>
      <% else %>
        <div
          class={[
            "flex items-center gap-retro-4 px-retro-4 py-retro-2 text-xs cursor-pointer",
            if(selectable_idx == @selected_index,
              do: "bg-selection-bg text-selection-fg",
              else: "hover:bg-hover-bg"
            )
          ]}
          phx-click={@on_select}
          phx-value-type="command"
          phx-value-value={item.name}
          data-testid={"autocomplete-item-#{selectable_idx}"}
        >
          <span class="font-bold shrink-0">/{item.name}</span>
          <span :if={Map.get(item, :description)} class="truncate text-muted-foreground">
            {item.description}
          </span>
        </div>
      <% end %>
    <% end %>
    """
  end

  # ── Nick mode — flat list with status dots ───────────────────

  defp render_items(%{mode: :nick} = assigns) do
    ~H"""
    <div
      :for={{result, idx} <- Enum.with_index(@items)}
      class={[
        "flex items-center gap-retro-4 px-retro-4 py-retro-2 text-xs cursor-pointer",
        if(idx == @selected_index,
          do: "bg-selection-bg text-selection-fg",
          else: "hover:bg-hover-bg"
        )
      ]}
      phx-click={@on_select}
      phx-value-type="nick"
      phx-value-value={result.nickname}
      data-testid={"autocomplete-item-#{idx}"}
    >
      <span class={[
        "w-2 h-2 rounded-full shrink-0",
        if(result.status == :online, do: "bg-success", else: "bg-disabled")
      ]} />
      <span class={["font-bold truncate", Map.get(result, :color_class)]}>{result.nickname}</span>
    </div>
    """
  end

  # ── Channel mode — flat list with joined checkmark ───────────

  defp render_items(%{mode: :channel} = assigns) do
    ~H"""
    <div
      :for={{result, idx} <- Enum.with_index(@items)}
      class={[
        "flex items-center gap-retro-4 px-retro-4 py-retro-2 text-xs cursor-pointer",
        if(idx == @selected_index,
          do: "bg-selection-bg text-selection-fg",
          else: "hover:bg-hover-bg"
        )
      ]}
      phx-click={@on_select}
      phx-value-type="channel"
      phx-value-value={result.name}
      data-testid={"autocomplete-item-#{idx}"}
    >
      <span :if={result.joined?} class="text-success shrink-0">&#10003;</span>
      <span class="font-bold shrink-0">{result.name}</span>
      <span class="truncate text-muted-foreground">({result.user_count} users)</span>
    </div>
    """
  end

  # ── Subcommand mode — flat list with description ─────────────

  defp render_items(%{mode: :subcommand} = assigns) do
    ~H"""
    <div
      :for={{result, idx} <- Enum.with_index(@items)}
      class={[
        "flex items-center gap-retro-4 px-retro-4 py-retro-2 text-xs cursor-pointer",
        if(idx == @selected_index,
          do: "bg-selection-bg text-selection-fg",
          else: "hover:bg-hover-bg"
        )
      ]}
      phx-click={@on_select}
      phx-value-type="subcommand"
      phx-value-value={result.name}
      phx-value-command={@command}
      data-testid={"autocomplete-item-#{idx}"}
    >
      <span class="font-bold shrink-0">{result.name}</span>
      <span :if={Map.get(result, :description)} class="truncate text-muted-foreground">
        {result.description}
      </span>
    </div>
    """
  end

  # ── Helpers ──────────────────────────────────────────────────

  # Build a list of {item, selectable_index} tuples.
  # Strings (category headers) get nil index; maps get incrementing index.
  defp index_selectable_items(items) do
    {indexed, _count} =
      Enum.map_reduce(items, 0, fn
        item, acc when is_binary(item) -> {{item, nil}, acc}
        item, acc -> {{item, acc}, acc + 1}
      end)

    indexed
  end
end
