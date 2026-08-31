defmodule RetroHexChatWeb.Components.UI.ShareBarTest do
  @moduledoc """
  The bar that mints an address and lets you take it away.

  Copying used to be the chat's alone: a menu item pushed `clipboard_copy` and
  the chat's viewport hook received it, so on a surface in a tab of its own the
  event arrived nowhere. This bar therefore shipped with a readonly field and
  no button — correct at the time, and the wrong answer once there was one.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ShareBar

  @moduletag :unit

  @url "http://localhost:4000/join/abc123"

  test "offers to mint before there is anything to copy" do
    html = render_component(&share_bar/1, url: nil, available: true, on_share: "share")

    assert html =~ ~s(data-testid="share-create")
    refute html =~ ~s(data-testid="share-copy")
    refute html =~ ~s(data-testid="share-url")
  end

  test "says why, rather than nothing, when the viewer may not mint one" do
    html = render_component(&share_bar/1, url: nil, available: false, on_share: "share")

    assert html =~ "Register your nickname"
  end

  # The field stays: an address you can see and select is what still works when
  # the browser refuses the clipboard.
  test "shows the address and a way to take it, once there is one" do
    html = render_component(&share_bar/1, url: @url, available: true, on_share: "share")

    assert html =~ ~s(data-testid="share-url")
    assert html =~ @url
    assert html =~ ~s(data-testid="share-copy")
    assert html =~ ~s(phx-hook="CopyValueHook")
  end

  # No round trip: the text is already in the document, which is exactly why
  # this works on a screen that has no chat behind it.
  test "the button points at the field beside it, by id" do
    html = render_component(&share_bar/1, url: @url, available: true, on_share: "share")

    assert [field_id] = Regex.run(~r/id="(share-url-[^"]+)"/, html, capture: :all_but_first)
    assert html =~ ~s(data-copy-from="#{field_id}")
  end

  test "two bars on one screen do not share an id" do
    one = render_component(&share_bar/1, url: @url, available: true, on_share: "share")
    two = render_component(&share_bar/1, url: @url <> "x", available: true, on_share: "share")

    assert [id_one] = Regex.run(~r/id="(share-url-[^"]+)"/, one, capture: :all_but_first)
    assert [id_two] = Regex.run(~r/id="(share-url-[^"]+)"/, two, capture: :all_but_first)
    refute id_one == id_two
  end
end
