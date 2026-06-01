defmodule RetroHexChatWeb.HelpContent.Channels do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.Diagrams, warn: false

  def help_h4(assigns) do
    ~H"""
    <h4 class="flex items-center gap-1.5 text-sm font-bold mt-4 mb-1.5 text-text">
      <.help_icon name={@icon} class="w-3.5 h-3.5 flex-shrink-0" />
      {render_slot(@inner_block)}
    </h4>
    """
  end

  def help_link(assigns) do
    ~H"""
    <.link navigate={"/chat/help/#{@topic}"} class="text-link hover:underline">
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def help_icon(assigns), do: apply(Icons, assigns.name, [%{class: assigns.class}])

  embed_templates "{channel_*,channels*,chanserv*,nickserv*,mode_*}"
end
