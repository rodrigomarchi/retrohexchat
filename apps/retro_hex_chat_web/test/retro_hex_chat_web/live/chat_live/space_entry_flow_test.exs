defmodule RetroHexChatWeb.ChatLive.SpaceEntryFlowTest do
  @moduledoc """
  What the entry beside the tabs does about a space, which is write its card.

  It used to be an anchor, so pressing it opened the space in a tab and the
  conversation never heard about it: the gathering existed for whoever pressed
  and for nobody else until they walked in. The card is the door now, and the
  press is what puts it there.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.ShareLinks

  defp unique_nick(prefix), do: "#{prefix}#{uid()}" |> String.slice(0, 16)

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp mount_identified(conn, prefix) do
    nick = register(unique_nick(prefix))
    {:ok, view, _html} = live(chat_conn(conn, nick.nickname, pre_identified: true), "/chat")
    %{nick: nick, view: view}
  end

  defp flush(view), do: :sys.get_state(view.pid)
  defp active_channel(view), do: :sys.get_state(view.pid).socket.assigns.session.active_channel

  defp press_space(view) do
    view |> element(~s([data-testid="space-open"])) |> render_click()
    flush(view)
  end

  defp system_messages(channel) do
    channel
    |> ChatQueries.list_messages(limit: 50)
    |> Map.fetch!(:items)
    |> Enum.filter(&(&1.type == "system"))
  end

  describe "the space entry beside the conversation's tabs" do
    test "goes nowhere, and writes the space's card into the channel", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "spf")
      channel = active_channel(view)

      # The entry is a control, never an address: a link here would be a door
      # that skipped the conversation.
      entry = render(element(view, ~s([data-testid="space-open"])))
      assert entry =~ "<button"
      assert entry =~ ~s(phx-click="space_open")
      # The only href in it belongs to the icon sprite, never to an address.
      refute entry =~ ~s(href="/space/)
      refute entry =~ "_blank"

      press_space(view)

      [message] = system_messages(channel)
      assert message.content =~ nick.nickname
      assert message.content =~ "/join/"

      # And what it carries resolves to this conversation's space.
      slug = message.content |> String.split("/join/") |> List.last() |> String.trim()
      assert {:ok, resolution} = ShareLinks.resolve(slug)
      assert resolution.kind == "space"
      assert resolution.target["space_id"] == channel
      assert resolution.live?
    end

    # One room, one card. A second press answers in the conversation without
    # putting a second door in it.
    test "pressing it again does not post a second card", %{conn: conn} do
      %{view: view} = mount_identified(conn, "spg")
      channel = active_channel(view)

      press_space(view)
      assert [_one] = system_messages(channel)

      press_space(view)
      assert [_still_one] = system_messages(channel)
    end

    # A card carries who is accountable for the address on it, so the control is
    # refused before the press rather than after it.
    test "a guest is refused at the control, not after pressing it", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SpcGuest#{uid()}"), "/chat")
      flush(view)

      assert has_element?(view, ~s([data-testid="space-open"][disabled]))
      assert render(element(view, ~s([data-testid="space-open"]))) =~ "Register your nickname"
    end
  end
end
