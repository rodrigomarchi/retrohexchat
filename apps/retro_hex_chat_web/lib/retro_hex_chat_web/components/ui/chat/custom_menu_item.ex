defmodule RetroHexChatWeb.Components.UI.Chat.CustomMenuItem do
  @moduledoc """
  Reading a user-defined context-menu entry.

  Custom entries are configured by the operator and reach a menu as a plain map,
  so every field is optional and a menu that renders one has to decide what an
  absent field means. Deciding it here is what keeps the three chat context
  menus agreeing: the event name a click pushes is a contract with the client,
  and a menu that spelled its default differently would fire an event nothing
  handles.
  """

  @default_action "custom_menu_execute"

  @doc "The event a click on this entry pushes."
  @spec action(map()) :: String.t()
  def action(item), do: Map.get(item, :action) || @default_action

  @doc "The command the entry runs, empty when it carries none."
  @spec command(map()) :: String.t()
  def command(item), do: Map.get(item, :command) || ""

  @doc "The text shown for the entry, empty when it carries none."
  @spec label(map()) :: String.t()
  def label(item), do: Map.get(item, :label) || ""
end
