defmodule RetroHexChatWeb.Components.UI.ShareLinkDialogTest do
  @moduledoc """
  The window that holds an address, and the two things you do with it.

  Inline, this content was a permanent band whose width came from whatever
  chrome it was wedged into: 1052 pixels for 336 pixels of address on a call
  surface, and 8 pixels for the same address at 390. A dialog is sized by
  itself, which is the whole reason the address moved into one.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ShareLinkDialog

  @moduletag :unit

  @url "http://localhost:4000/join/abc123"

  defp render_dialog(opts) do
    render_component(
      &share_link_dialog/1,
      Keyword.merge([id: "share-x", show: true, url: @url, on_close: "close"], opts)
    )
  end

  test "shows the address and a way to take it" do
    html = render_dialog([])

    assert html =~ ~s(data-testid="share-url")
    assert html =~ @url
    assert html =~ ~s(data-testid="share-copy")
    assert html =~ ~s(phx-hook="CopyValueHook")
  end

  # No round trip: the text is already in the document, which is exactly why
  # this works on a screen that has no chat behind it.
  test "the copy button points at the field beside it, by id" do
    html = render_dialog([])

    assert html =~ ~s(id="share-x-url")
    assert html =~ ~s(data-copy-from="share-x-url")
  end

  # A dialog can be rendered inside a form — the call's antechamber is one —
  # and a button with no type submits it instead of doing what it says.
  test "no button in it submits the form it may be sitting inside" do
    html = render_dialog(on_revoke: "revoke")

    for testid <- ~w(share-copy share-close share-revoke) do
      [button] = Regex.run(~r/<button[^>]*data-testid="#{testid}"[^>]*>/, html)
      assert button =~ ~s(type="button"), "#{testid} would submit its form"
    end
  end

  test "offers no way to close a link the viewer may not close" do
    refute render_dialog([]) =~ ~s(data-testid="share-revoke")
    assert render_dialog(on_revoke: "revoke") =~ ~s(data-testid="share-revoke")
  end

  test "revoking asks first, and says the room survives it" do
    html = render_dialog(on_revoke: "revoke")

    assert html =~ "data-confirm"
    assert html =~ "The room stays open"
  end
end
