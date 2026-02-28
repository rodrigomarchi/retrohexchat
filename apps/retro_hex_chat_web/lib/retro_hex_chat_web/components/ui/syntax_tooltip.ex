defmodule RetroHexChatWeb.Components.UI.SyntaxTooltip do
  @moduledoc """
  Command syntax tooltip component for the showcase design system.

  Floating tooltip that shows command syntax guidance as users type.
  Highlights the currently active parameter and optionally shows
  description, sub-options, context messages, and examples.

  ## Usage

      <.syntax_tooltip
        tooltip={%{
          command: "join",
          params: [%{name: "channel", required: true}, %{name: "key", required: false}],
          current_index: 0,
          description: "Join a channel",
          sub_options: [],
          context_message: nil,
          examples: ["/join #lobby", "/join #lobby secretkey"]
        }}
        detail_level={:beginner}
      />
  """
  use RetroHexChatWeb.Component

  @doc "Renders the command syntax tooltip."

  attr :tooltip, :any,
    default: nil,
    doc:
      "Map with keys: command, params (list of maps with :name, :required), current_index, description, sub_options, context_message, examples. Can be nil to render nothing."

  attr :detail_level, :atom,
    default: :beginner,
    values: [:beginner, :expert, :off],
    doc: "Controls level of detail shown"

  attr :class, :string, default: nil
  attr :rest, :global

  @spec syntax_tooltip(map()) :: Phoenix.LiveView.Rendered.t()
  def syntax_tooltip(assigns) do
    ~H"""
    <div
      :if={@tooltip != nil && @detail_level != :off}
      class={
        classes([
          "shadow-retro-window bg-surface border border-border p-retro-4 text-xs max-w-sm",
          @class
        ])
      }
      data-testid="syntax-tooltip"
      {@rest}
    >
      <%!-- Header: command + param list --%>
      <div class="flex flex-wrap items-center gap-retro-2 font-mono font-bold mb-retro-2">
        <span class="text-title-bar-text bg-title-bar px-1">/{@tooltip.command}</span>
        <.tooltip_params params={@tooltip.params} current_index={@tooltip.current_index} />
      </div>

      <%!-- Beginner-only details --%>
      <div :if={@detail_level == :beginner} class="space-y-retro-2">
        <%!-- Description --%>
        <p :if={@tooltip.description} class="text-xs text-foreground">
          {@tooltip.description}
        </p>

        <%!-- Sub-options --%>
        <div
          :if={@tooltip.sub_options && @tooltip.sub_options != []}
          class="shadow-retro-field bg-white p-retro-4 space-y-retro-2"
        >
          <div :for={opt <- @tooltip.sub_options} class="flex gap-retro-4 text-xs">
            <span class="font-mono font-bold shrink-0">{opt.flag}</span>
            <span class="text-muted-foreground">{opt.description}</span>
          </div>
        </div>

        <%!-- Context message --%>
        <p :if={@tooltip.context_message} class="text-xs italic text-muted-foreground">
          {@tooltip.context_message}
        </p>

        <%!-- Examples --%>
        <div
          :if={@tooltip.examples && @tooltip.examples != []}
          class="flex flex-wrap gap-retro-2 mt-retro-2"
        >
          <code
            :for={ex <- @tooltip.examples}
            class="shadow-retro-field bg-canvas-bg text-canvas-fg px-1 font-mono text-xs"
          >
            {ex}
          </code>
        </div>
      </div>
    </div>
    """
  end

  # ── Private helpers ───────────────────────────────────────

  attr :params, :list, required: true
  attr :current_index, :integer, default: nil

  defp tooltip_params(assigns) do
    ~H"""
    <span
      :for={{param, index} <- Enum.with_index(@params)}
      class={
        classes([
          "font-mono px-1",
          if(index == @current_index,
            do: "bg-warning-alt text-black font-bold",
            else: "text-muted-foreground"
          )
        ])
      }
    >
      <%= if param.required do %>
        &lt;{param.name}&gt;
      <% else %>
        [{param.name}]
      <% end %>
    </span>
    """
  end
end
