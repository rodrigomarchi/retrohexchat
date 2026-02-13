defmodule RetroHexChatWeb.Components.SyntaxTooltip do
  @moduledoc """
  Function component for the command syntax tooltip.

  Shows parameter guidance as users type commands, with live
  highlighting of the current expected parameter.
  """

  use Phoenix.Component

  @doc """
  Renders the syntax tooltip above the input area.

  ## Attributes

    * `tooltip` - Map with tooltip data (command, syntax, parameters, etc.) or nil
    * `detail_level` - :beginner, :expert, or :off
  """
  attr :tooltip, :map, default: nil
  attr :detail_level, :atom, default: :beginner

  @spec syntax_tooltip(map()) :: Phoenix.LiveView.Rendered.t()
  def syntax_tooltip(assigns) do
    ~H"""
    <div
      :if={@tooltip != nil && @detail_level != :off}
      class="syntax-tooltip"
      data-testid="syntax-tooltip"
    >
      <div class="syntax-tooltip-header">
        <span class="syntax-tooltip-command">/{@tooltip.command}</span>
        <span class="syntax-tooltip-syntax">
          {render_syntax_params(assigns)}
        </span>
      </div>
      <div :if={@detail_level == :beginner} class="syntax-tooltip-description">
        {@tooltip.description}
      </div>
      <div
        :if={@detail_level == :beginner && @tooltip.sub_options != nil && @tooltip.sub_options != []}
        class="syntax-suboptions"
      >
        <div :for={opt <- @tooltip.sub_options} class="syntax-suboption">
          <span class="syntax-suboption-flag">{opt.flag}</span>
          <span :if={opt.requires_param} class="syntax-suboption-param">nick</span>
          — {opt.description}
        </div>
      </div>
      <div
        :if={@detail_level == :beginner && @tooltip.context_message != nil}
        class="syntax-context"
      >
        {@tooltip.context_message}
      </div>
      <div
        :if={@detail_level == :beginner && @tooltip.examples != []}
        class="syntax-examples"
      >
        <span :for={ex <- @tooltip.examples} class="syntax-example">{ex}</span>
      </div>
    </div>
    """
  end

  defp render_syntax_params(assigns) do
    tooltip = assigns.tooltip
    params = tooltip.parameters || []
    current_index = tooltip.current_param_index

    assigns = assign(assigns, params: params, current_index: current_index)

    ~H"""
    <span
      :for={param <- @params}
      class={"syntax-param #{if param.position == @current_index, do: "syntax-param-active", else: ""}"}
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
