defmodule RetroHexChatWeb.OpenTabConfirmFeatureTest do
  @moduledoc """
  The gate between a click on a door and a second browser tab, driven through the
  chat the way the hook drives it.

  `render_hook/3` is the honest stand-in for the hook here: the interception
  itself is a `document` click listener, which only a browser has, but everything
  after it — the refusal, the pending target, the dialog that appears, cancelling
  — is the server's and is exactly what this exercises.

  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChatWeb.ChatLive.Components.OpenTabConfirmDialog

  @moduletag :liveview_feature

  @hook_id "#open-tab-confirm-dialog-mount"

  defp open_chat(conn, prefix) do
    nick = "#{prefix}#{uid()}"
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  # The gate answers with a `send_update`, which lands in the LiveView's mailbox
  # rather than in the reply to the push — so the HTML `render_hook` hands back
  # is the one from *before* the dialog was told anything. `:sys.get_state/1` is
  # the sanctioned settle: the call sits behind everything already queued in that
  # process. A `Process.sleep` reads the same and guarantees nothing.
  defp gate(view, payload) do
    view
    |> element(@hook_id)
    |> render_hook("confirm_open_tab", payload)

    _settled = :sys.get_state(view.pid)
    render(view)
  end

  describe "the question" do
    test "a door of ours raises it, named and without an address", %{conn: conn} do
      view = open_chat(conn, "OT1")

      html = gate(view, %{"url" => "/call/abc", "kind" => "surface", "label" => "Call in #retro"})

      assert html =~ ~s(id="open-tab-confirm-dialog-show-trigger")
      assert html =~ "This opens Call in #retro."
      refute html =~ ~s(data-testid="open-tab-confirm-url")
    end

    test "an external link raises it with the host and the whole address", %{conn: conn} do
      view = open_chat(conn, "OT2")

      html =
        gate(view, %{
          "url" => "https://tecnoblog.net/noticias/algo/",
          "kind" => "external",
          "host" => "tecnoblog.net"
        })

      assert html =~ "Leaving RetroHexChat"
      assert html =~ "tecnoblog.net"
      assert html =~ "https://tecnoblog.net/noticias/algo/"
    end

    test "the way out is an anchor, so no pop-up blocker is involved", %{conn: conn} do
      view = open_chat(conn, "OT3")

      html = gate(view, %{"url" => "https://example.com/x", "kind" => "external"})

      assert html =~ ~s(href="https://example.com/x")
      assert html =~ ~s(target="_blank")
      assert html =~ ~s(rel="noopener")
    end

    test "cancelling puts it away", %{conn: conn} do
      view = open_chat(conn, "OT4")

      _open = gate(view, %{"url" => "/call/abc", "kind" => "surface"})

      view
      |> element(~s([data-testid="open-tab-confirm-cancel"]))
      |> render_click()

      _settled = :sys.get_state(view.pid)

      refute render(view) =~ ~s(id="open-tab-confirm-dialog-show-trigger")
    end
  end

  describe "what may become an href" do
    # The payload is the client's, and the dialog draws an anchor from it. Nothing
    # but a message can put a link in front of somebody else and a message yields
    # no other scheme, so this is self-inflicted only — but a sink that is safe
    # because of who can reach it is a sink waiting for its reach to change.
    for scheme <- ["javascript:alert(1)", "data:text/html,<script>1</script>", "vbscript:x"] do
      test "#{scheme} opens no dialog", %{conn: conn} do
        view = open_chat(conn, "OT5")

        html = gate(view, %{"url" => unquote(scheme), "kind" => "external"})

        refute html =~ ~s(id="open-tab-confirm-dialog-show-trigger")
      end
    end

    # `//evil.example` has no scheme and reads like a path, and a browser would
    # resolve it against the current protocol and go there.
    test "a protocol-relative address opens no dialog", %{conn: conn} do
      view = open_chat(conn, "OT6")

      html = gate(view, %{"url" => "//evil.example/x", "kind" => "surface"})

      refute html =~ ~s(id="open-tab-confirm-dialog-show-trigger")
    end

    test "a path of ours is fine", %{conn: conn} do
      view = open_chat(conn, "OT7")

      html = gate(view, %{"url" => "/play/arcade/pong", "kind" => "external"})

      assert html =~ ~s(id="open-tab-confirm-dialog-show-trigger")
    end
  end

  # The island is where the pending target lives, and reading it off the process
  # is the synchronous answer — never a wait on the `send_update` that put it
  # there.
  test "the pending target is the island's own state", %{conn: conn} do
    view = open_chat(conn, "OT8")

    _open = gate(view, %{"url" => "/call/abc", "kind" => "surface", "label" => "Call in #retro"})

    assert OpenTabConfirmDialog.id() == "open-tab-confirm-dialog"
    assert render(view) =~ "Call in #retro"
  end
end
