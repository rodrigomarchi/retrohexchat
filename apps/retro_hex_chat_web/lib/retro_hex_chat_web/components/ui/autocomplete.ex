defmodule RetroHexChatWeb.Components.UI.Autocomplete do
  @moduledoc """
  Autocomplete dropdown component for the showcase design system.

  Composed from scroll_area + minimal markup.
  Multi-mode dropdown supporting commands, nicks, channels, and subcommands
  with category headers and keyboard navigation highlight.

  ## Usage

      <.autocomplete
        items={[
          %{category: "Commands", label: "/join", description: "Join a channel"},
          %{category: "Commands", label: "/part", description: "Leave a channel"}
        ]}
        selected_index={0}
      />
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

  attr :on_select, :any, default: nil, doc: "Item click callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec autocomplete(map()) :: Phoenix.LiveView.Rendered.t()
  def autocomplete(assigns) do
    assigns = assign(assigns, :grouped_items, group_items(assigns.items))

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
        <div :for={{category, items} <- @grouped_items}>
          <%!-- Category header --%>
          <div class="px-retro-4 py-retro-2 text-[10px] font-bold text-muted-foreground bg-surface border-b border-border">
            {category}
          </div>

          <%!-- Items --%>
          <div
            :for={{item, idx} <- items}
            class={[
              "flex items-center gap-retro-4 px-retro-4 py-retro-2 text-xs cursor-pointer",
              if(idx == @selected_index,
                do: "bg-selection-bg text-selection-fg",
                else: "hover:bg-hover-bg"
              )
            ]}
            phx-click={@on_select}
            phx-value-index={idx}
            phx-value-label={item.label}
            data-testid={"autocomplete-item-#{idx}"}
          >
            <.autocomplete_item_content mode={@mode} item={item} selected={idx == @selected_index} />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Mode-specific rendering ──────────────────────────

  attr :mode, :atom, required: true
  attr :item, :map, required: true
  attr :selected, :boolean, default: false

  defp autocomplete_item_content(%{mode: :nick} = assigns) do
    ~H"""
    <span class={[
      "w-2 h-2 rounded-full shrink-0",
      if(Map.get(@item, :online, true), do: "bg-success", else: "bg-disabled")
    ]} />
    <span class="font-bold truncate">{@item.label}</span>
    """
  end

  defp autocomplete_item_content(%{mode: :channel} = assigns) do
    ~H"""
    <span :if={Map.get(@item, :joined, false)} class="text-success shrink-0">&#10003;</span>
    <span class="font-bold shrink-0">{@item.label}</span>
    <span :if={Map.get(@item, :description)} class="truncate text-muted-foreground">
      {@item.description}
    </span>
    """
  end

  defp autocomplete_item_content(assigns) do
    ~H"""
    <span class="font-bold shrink-0">{@item.label}</span>
    <span :if={Map.get(@item, :description)} class="truncate text-muted-foreground">
      {@item.description}
    </span>
    """
  end

  defp group_items(items) do
    items
    |> Enum.with_index()
    |> Enum.group_by(fn {item, _idx} -> Map.get(item, :category, "Results") end)
    |> Enum.sort_by(fn {category, _} -> category end)
  end
end
