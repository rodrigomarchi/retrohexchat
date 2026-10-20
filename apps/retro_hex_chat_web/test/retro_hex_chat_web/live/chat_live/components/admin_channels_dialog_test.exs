defmodule RetroHexChatWeb.ChatLive.Components.AdminChannelsDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :unit

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Components.AdminChannelsDialog

  defp island(assigns) do
    session = %Session{Session.new("TestAdmin") | identified: true}

    render_component(
      AdminChannelsDialog,
      Map.merge(%{id: AdminChannelsDialog.id(), session: session}, assigns)
    )
  end

  test "routes every action to itself rather than the parent LiveView" do
    html = island(%{})

    assert html =~ ~s(phx-target=)
    assert html =~ ~s(phx-submit="admin_channels_refresh")
    assert html =~ ~s(phx-submit="admin_channels_delete")
    assert html =~ ~s(phx-submit="admin_channels_cs_access_add")
  end

  test "loads the channel list on mount rather than waiting for an open directive" do
    html = island(%{})

    assert [pane] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find("#admin-channels-output")

    # The pane renders the listing as rows, so its table element is what proves
    # the load ran on mount.
    assert [_table] = Floki.find(pane, ~s([data-testid="admin-channels-table"]))
  end

  test "leaves the ban list empty until a channel is named" do
    html = island(%{})

    assert [pane] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find("#admin-channels-banlist")

    assert Floki.text(pane) == ""
  end

  test "asks for a typed confirmation on every destructive action" do
    html = island(%{})

    assert html =~ "Type channel name to confirm"
  end
end
