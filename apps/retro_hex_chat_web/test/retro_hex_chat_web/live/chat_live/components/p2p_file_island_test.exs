defmodule RetroHexChatWeb.ChatLive.Components.P2PFileIslandTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.P2PFileIsland

  @moduletag :unit

  defp ft(name, params \\ %{}), do: {:ft_event, name, params}

  test "id/0 is stable" do
    assert P2PFileIsland.id() == "lobby-file"
  end

  test "prompts to connect before the lobby is connected" do
    html = render_component(P2PFileIsland, id: P2PFileIsland.id(), connected: false)

    refute html =~ ~s(data-testid="lobby-file-panel")
    assert html =~ "Connect to send a file"
  end

  test "mounts the transfer hook and offers a browse control once ready" do
    html =
      render_component(P2PFileIsland,
        id: P2PFileIsland.id(),
        connected: true,
        action: ft("file_transfer_ready")
      )

    assert html =~ ~s(data-testid="lobby-file-panel")
    # The hook element is present so the data channel stays live for the connection.
    assert html =~ ~s(phx-hook="FileTransferHook")
    assert html =~ ~s(id="lobby-file-transfer")
    assert html =~ "Browse files"
  end

  test "shows an incoming offer with the sender's file" do
    html =
      render_component(P2PFileIsland,
        id: P2PFileIsland.id(),
        connected: true,
        peer_nick: "trinity",
        action: ft("ft_offer_received", %{"file_name" => "photo.png", "formatted_size" => "1 MB"})
      )

    assert html =~ "photo.png"
  end

  test "renders a blocked-extension validation error" do
    html =
      render_component(P2PFileIsland,
        id: P2PFileIsland.id(),
        connected: true,
        action: ft("ft_validation_error", %{"error" => "Blocked file type: .exe"})
      )

    assert html =~ ~s(data-testid="lobby-ft-validation-error")
    assert html =~ "Blocked file type: .exe"
  end
end
