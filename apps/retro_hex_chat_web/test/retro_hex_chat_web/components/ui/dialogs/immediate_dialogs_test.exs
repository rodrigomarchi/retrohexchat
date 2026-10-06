defmodule RetroHexChatWeb.Components.UI.ImmediateDialogsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.AliasDialog
  alias RetroHexChatWeb.Components.UI.AutojoinDialog
  alias RetroHexChatWeb.Components.UI.AutoRespondDialog
  alias RetroHexChatWeb.Components.UI.CustomMenusDialog
  alias RetroHexChatWeb.Components.UI.HighlightDialog
  alias RetroHexChatWeb.Components.UI.PerformDialog
  alias RetroHexChatWeb.Components.UI.TimersDialog

  @moduletag :unit

  # Every change in these windows applies the moment it is made — Add saves,
  # Remove removes — so there is nothing for an OK to confirm, and one beside
  # no Cancel only suggests that the title bar's close would lose something.
  # The window closes from its title bar; `on_close` is passed the way the
  # chat's windows once did, so a footer brought back behind it shows up here.
  @panels [
    {AliasDialog, :alias_panel, []},
    {AutoRespondDialog, :auto_respond_panel, [rules: []]},
    {AutojoinDialog, :autojoin_panel, []},
    {CustomMenusDialog, :custom_menus_panel, [entries: %{}]},
    {HighlightDialog, :highlight_panel, []},
    {PerformDialog, :perform_panel, []},
    {TimersDialog, :timers_panel, []}
  ]

  for {module, fun, assigns} <- @panels do
    test "#{inspect(module)}.#{fun} has no OK that only closes the window" do
      html =
        render_component(
          &(unquote(module).unquote(fun) / 1),
          [id: "panel", on_close: "close"] ++ unquote(Macro.escape(assigns))
        )

      refute html =~ ~r/>\s*OK\s*</
    end
  end
end
