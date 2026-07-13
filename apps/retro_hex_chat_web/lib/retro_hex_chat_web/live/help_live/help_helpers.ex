defmodule RetroHexChatWeb.HelpLive.HelpHelpers do
  @moduledoc false
  use Phoenix.Component

  defdelegate help_layout(assigns), to: RetroHexChatWeb.Components.UI.Help.HelpViewer
  defdelegate help_topic(assigns), to: RetroHexChatWeb.Components.UI.Help.HelpViewer
  defdelegate help_empty_state(assigns), to: RetroHexChatWeb.Components.UI.Help.HelpViewer
  defdelegate see_also_section(assigns), to: RetroHexChatWeb.Components.UI.Help.HelpViewer

  # Same API as the old HelpHTML helpers so help-content templates need zero changes.
  defdelegate help_h4(assigns), to: RetroHexChatWeb.HelpContent.Helpers
  defdelegate help_link(assigns), to: RetroHexChatWeb.HelpContent.Helpers
  defdelegate help_icon(assigns), to: RetroHexChatWeb.HelpContent.Helpers

  @doc "Dynamically render a help topic's content by dispatching to HelpContent."
  attr :id, :string, required: true

  @help_content_modules [
    RetroHexChatWeb.HelpContent.CommandsAdmin,
    RetroHexChatWeb.HelpContent.CommandsAtoM,
    RetroHexChatWeb.HelpContent.CommandsNtoZ,
    RetroHexChatWeb.HelpContent.Bots,
    RetroHexChatWeb.HelpContent.Channels,
    RetroHexChatWeb.HelpContent.Arcade,
    RetroHexChatWeb.HelpContent.Games,
    RetroHexChatWeb.HelpContent.P2P,
    RetroHexChatWeb.HelpContent.UI,
    RetroHexChatWeb.HelpContent.ChatFeatures,
    RetroHexChatWeb.HelpContent.ChatStatusFeatures
  ]

  @spec render_topic_content(map()) :: Phoenix.LiveView.Rendered.t()
  def render_topic_content(assigns) do
    func = assigns.id |> String.replace("-", "_") |> String.to_existing_atom()

    @help_content_modules
    |> Enum.find(fn module ->
      Code.ensure_loaded?(module) and function_exported?(module, func, 1)
    end)
    |> case do
      nil -> raise ArgumentError, "missing help content template for #{assigns.id}"
      module -> apply(module, func, [assigns])
    end
  end
end
