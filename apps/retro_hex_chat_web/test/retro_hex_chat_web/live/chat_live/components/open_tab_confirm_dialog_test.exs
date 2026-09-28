defmodule RetroHexChatWeb.ChatLive.Components.OpenTabConfirmDialogTest do
  @moduledoc """
  The island owns the pending destination and derives its visibility from it, so
  "is the dialog open" is answered here by the presence of the show-trigger —
  a hidden dialog still renders all of its markup.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.OpenTabConfirmDialog

  @moduletag :unit

  defp render_island(assigns) do
    render_component(
      OpenTabConfirmDialog,
      Keyword.merge([id: OpenTabConfirmDialog.id()], assigns)
    )
  end

  test "the id the parent sends updates to is stable" do
    assert OpenTabConfirmDialog.id() == "open-tab-confirm-dialog"
  end

  test "with no target it is closed" do
    html = render_island([])

    assert html =~ ~s(data-testid="open-tab-confirm-dialog")
    refute html =~ ~s(id="open-tab-confirm-dialog-show-trigger")
  end

  test "the click gate is mounted on this island, never on the shell" do
    assert render_island([]) =~ ~s(phx-hook="OpenTabConfirmHook")
  end
end
