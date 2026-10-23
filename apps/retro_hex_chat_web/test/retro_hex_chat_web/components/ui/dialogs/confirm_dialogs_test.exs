defmodule RetroHexChatWeb.Components.UI.ConfirmDialogsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.{GroupCallConfirmDialog, P2PConfirmDialog}

  # The X, Escape and a click outside answer the same as Cancel. Before the
  # group-call and P2P confirmations were drawn by the shared dialog they only
  # hid themselves, so the server kept waiting for an answer nobody could give.
  defp cancel_reaches_the_server(html, event) do
    document = Floki.parse_document!(html)

    close = Floki.find(document, "[phx-click]") |> Enum.map(&Floki.attribute(&1, "phx-click"))
    keydown = Floki.attribute(document, "[phx-window-keydown]", "phx-window-keydown")

    assert Enum.any?(List.flatten(close), &(&1 =~ event)), "the X does not answer #{event}"
    assert Enum.any?(keydown, &(&1 =~ event)), "Escape does not answer #{event}"
  end

  test "the group call confirmation's X and Escape cancel on the server" do
    html =
      render_component(&GroupCallConfirmDialog.group_call_confirm_dialog/1,
        id: "gc-confirm",
        show: true,
        mode: :leave,
        channel: "#lobby",
        on_confirm: "group_call_confirm",
        on_cancel: "group_call_confirm_cancel"
      )

    cancel_reaches_the_server(html, "group_call_confirm_cancel")
    assert html =~ ~s(data-testid="gc-confirm-confirm")
  end

  test "the P2P confirmation's X and Escape cancel on the server" do
    html =
      render_component(&P2PConfirmDialog.p2p_confirm_dialog/1,
        id: "p2p-confirm",
        show: true,
        peer: "alice",
        on_confirm: "p2p_confirm_end",
        on_cancel: "p2p_confirm_cancel"
      )

    cancel_reaches_the_server(html, "p2p_confirm_cancel")
    assert html =~ "alice"
  end
end
