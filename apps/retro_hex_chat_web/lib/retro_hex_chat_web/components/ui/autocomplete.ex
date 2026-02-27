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
  attr :class, :string, default: nil
  attr :rest, :global

  @spec autocomplete(map()) :: Phoenix.LiveView.Rendered.t()
  def autocomplete(assigns) do
    assigns = assign(assigns, :grouped_items, group_items(assigns.items))

    ~H"""
    <div
      class={
        classes([
          "shadow-retro-window bg-surface border border-border w-[280px] max-h-[200px] overflow-y-auto retro-scrollbar",
          @class
        ])
      }
      {@rest}
    >
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
        >
          <span class="font-bold shrink-0">{item.label}</span>
          <span :if={Map.get(item, :description)} class="truncate text-muted-foreground">
            {item.description}
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp group_items(items) do
    items
    |> Enum.with_index()
    |> Enum.group_by(fn {item, _idx} -> Map.get(item, :category, "Results") end)
    |> Enum.sort_by(fn {category, _} -> category end)
  end
end
