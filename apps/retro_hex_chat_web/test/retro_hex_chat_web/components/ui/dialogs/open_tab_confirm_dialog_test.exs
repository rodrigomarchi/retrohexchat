defmodule RetroHexChatWeb.Components.UI.OpenTabConfirmDialogTest do
  @moduledoc """
  The dialog that stands between a click and a second tab.

  The assertion that matters most here is not any sentence: it is that the
  confirm button comes out as an anchor carrying `target="_blank"` **and**
  `rel="noopener"`. Without the anchor a pop-up blocker refuses the open;
  without the `rel` the new tab shares this one's event loop, measured in
  `docs/guide/surfaces.md` at 1203 ms against 12 ms. Both are invisible to a
  reader and to every other test in the suite.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.OpenTabConfirmDialog

  @moduletag :unit

  defp render_dialog(assigns) do
    render_component(
      &open_tab_confirm_dialog/1,
      Keyword.merge(
        [
          id: "open-tab-confirm",
          show: true,
          target: %{kind: :surface, url: "/call/abc", label: "Call in #retro"},
          on_open: "open_tab_confirm_open",
          on_cancel: "open_tab_confirm_cancel"
        ],
        assigns
      )
    )
  end

  describe "the way out" do
    test "the confirm button is an anchor that cannot share this tab's event loop" do
      html = render_dialog([])

      assert html =~ ~s(data-testid="open-tab-confirm-open")
      assert html =~ ~s(href="/call/abc")
      assert html =~ ~s(target="_blank")
      assert html =~ ~s(rel="noopener")
    end

    test "cancelling is offered beside it" do
      assert render_dialog([]) =~ ~s(data-testid="open-tab-confirm-cancel")
    end
  end

  describe "what the reader is told" do
    test "a room of ours is named, and no address is shown" do
      html = render_dialog([])

      assert html =~ "Open in a New Tab"
      assert html =~ "This opens Call in #retro."
      refute html =~ ~s(data-testid="open-tab-confirm-url")
    end

    test "an attachment is named by its file" do
      html =
        render_dialog(
          target: %{kind: :attachment, url: "/chat/attachments/7", label: "holiday.png"}
        )

      assert html =~ "This opens the attachment holiday.png."
      refute html =~ ~s(data-testid="open-tab-confirm-url")
    end

    test "an external link names the host and prints the whole address" do
      html =
        render_dialog(
          target: %{
            kind: :external,
            url: "https://tecnoblog.net/noticias/algo/",
            host: "tecnoblog.net"
          }
        )

      assert html =~ "Leaving RetroHexChat"
      assert html =~ "This link goes to tecnoblog.net, which is not part of RetroHexChat."
      assert html =~ ~s(data-testid="open-tab-confirm-url")
      assert html =~ "https://tecnoblog.net/noticias/algo/"
    end

    # The arcade: its address is ours and it redirects to the static host the
    # WASM bundle lives on. Printing `/play/arcade/pong` under "you are leaving"
    # would name the wrong place, so the sentence stands alone.
    test "a door of ours that leaves anyway says so without inventing an address" do
      html = render_dialog(target: %{kind: :external, url: "/play/arcade/pong", host: nil})

      assert html =~ "Leaving RetroHexChat"
      assert html =~ "This link goes somewhere outside RetroHexChat."
      refute html =~ ~s(data-testid="open-tab-confirm-url")
    end
  end

  # A closed dialog still renders its markup, so every reader in the component
  # has to answer for a missing target rather than raising inside a template.
  test "it renders with no target at all" do
    html = render_dialog(show: false, target: nil)

    assert html =~ ~s(data-testid="open-tab-confirm-dialog")
    refute html =~ ~s(id="open-tab-confirm-show-trigger")
  end
end
