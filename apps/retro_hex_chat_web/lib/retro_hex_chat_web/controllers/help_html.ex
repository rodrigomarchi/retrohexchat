defmodule RetroHexChatWeb.HelpHTML do
  @moduledoc """
  HTML module for the help page templates.

  Provides helper components used inside help content HEEx templates:
  `help_icon/1`, `help_h4/1`, `help_link/1`, and `render_topic_content/1`.
  """
  use RetroHexChatWeb, :html

  embed_templates "help_html/*"

  @doc "Render an icon by name. Dispatches to the Icons facade at runtime."
  attr :name, :atom, required: true
  attr :class, :string, default: "help-icon help-icon-14"

  @spec help_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def help_icon(assigns) do
    apply(RetroHexChatWeb.Icons, assigns.name, [assigns])
  end

  @doc "Section heading with icon, used inside help content templates."
  attr :icon, :atom, required: true
  slot :inner_block, required: true

  @spec help_h4(map()) :: Phoenix.LiveView.Rendered.t()
  def help_h4(assigns) do
    ~H"""
    <h4 class="help-section-heading">
      <.help_icon name={@icon} class="help-icon help-icon-14" />
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
    <a href={~p"/chat/help?topic=#{@topic}"} class="help-topic-link">
      {render_slot(@inner_block)}
    </a>
    """
  end

  @doc "Dynamically render a help topic's content by dispatching to HelpContent."
  attr :id, :string, required: true

  @spec render_topic_content(map()) :: Phoenix.LiveView.Rendered.t()
  def render_topic_content(assigns) do
    func = assigns.id |> String.replace("-", "_") |> String.to_existing_atom()
    apply(RetroHexChatWeb.HelpContent, func, [assigns])
  end
end
