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

  @moduletag :liveview_feature

  @hook_id "#open-tab-confirm-dialog-mount"

  defp open_chat(conn, prefix) do
    nick = "#{prefix}#{uid()}"
    {:ok, view, _html} = live(chat_conn(conn, nick), "/")
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
    test "a door of ours raises it, named and without an address; cancelling puts it away",
         %{conn: conn} do
      view = open_chat(conn, "OT1")

      html = gate(view, %{"url" => "/call/abc", "kind" => "surface", "label" => "Call in #retro"})

      assert html =~ ~s(id="open-tab-confirm-dialog-show-trigger")
      assert html =~ "This opens Call in #retro."
      refute html =~ ~s(data-testid="open-tab-confirm-url")

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
    #
    # `//evil.example` has no scheme and reads like a path, and a browser would
    # resolve it against the current protocol and go there.
    #
    # A refusal opens nothing, so every refused payload is asked of one chat in
    # turn, and the path of ours last proves the same chat still raises the
    # question.
    @refused [
      %{"url" => "javascript:alert(1)", "kind" => "external"},
      %{"url" => "data:text/html,<script>1</script>", "kind" => "external"},
      %{"url" => "vbscript:x", "kind" => "external"},
      %{"url" => "//evil.example/x", "kind" => "surface"}
    ]

    test "unsafe schemes and a protocol-relative address open no dialog; a path of ours does",
         %{conn: conn} do
      view = open_chat(conn, "OT5")

      for payload <- @refused do
        html = gate(view, payload)

        refute html =~ ~s(id="open-tab-confirm-dialog-show-trigger"),
               "#{payload["url"]} opened the dialog"
      end

      html = gate(view, %{"url" => "/play/arcade/pong", "kind" => "external"})

      assert html =~ ~s(id="open-tab-confirm-dialog-show-trigger")
    end
  end
end
