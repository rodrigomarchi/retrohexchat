defmodule RetroHexChatWeb.HelpContent.Helpers do
  @moduledoc false
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  @doc "Section heading with icon, used inside help content templates."
  attr :icon, :atom, required: true
  slot :inner_block, required: true

  @spec help_h4(map()) :: Phoenix.LiveView.Rendered.t()
  def help_h4(assigns) do
    ~H"""
    <h4 class="flex items-center gap-1.5 text-sm font-bold mt-4 mb-1.5 text-text">
      <.help_icon name={@icon} class="w-3.5 h-3.5 flex-shrink-0" />
      {render_slot(@inner_block)}
    </h4>
    """
  end

  @doc "Cross-reference link to another help topic."
  attr :topic, :string, required: true
  slot :inner_block, required: true

  @spec help_link(map()) :: Phoenix.LiveView.Rendered.t()
  def help_link(assigns) do
    ~H"""
    <.link navigate={"/chat/help/#{@topic}"} class="text-link hover:underline">
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc "Render an icon by name. Dispatches to the Icons facade at runtime."
  attr :name, :atom, required: true
  attr :class, :string, default: "w-3.5 h-3.5"

  @spec help_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def help_icon(assigns) do
    apply(Icons, assigns.name, [%{class: assigns.class}])
  end
end
