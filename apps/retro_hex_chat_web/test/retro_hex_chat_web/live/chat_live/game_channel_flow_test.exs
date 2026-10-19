defmodule RetroHexChatWeb.ChatLive.GameChannelFlowTest do
  @moduledoc """
  A game's channel, as somebody reading it meets it: the strip that names the
  game, the seat it offers, and — for a visitor — the account that pressing it
  asks for.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.Games.Channels
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.ShareLinks

  setup do
    :created = Channels.ensure("#hex-pong")

    on_exit(fn ->
      case ChannelRegistry.lookup("#hex-pong") do
        {:ok, pid} -> ChannelSupervisor.stop_child(pid)
        {:error, :not_found} -> :ok
      end
    end)
  end

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp seat_lines do
    "#hex-pong"
    |> ChatQueries.list_messages(limit: 50)
    |> Map.fetch!(:items)
    |> Enum.filter(&(&1.type == "system" and &1.content =~ "/join/"))
  end

  test "Find a partner puts one seat's card in the channel, once", %{conn: conn} do
    nick = register("lfg#{uid()}" |> String.slice(0, 16))

    {:ok, view, _html} =
      live(chat_conn(conn, nick.nickname, pre_identified: true), "/c/hex-pong")

    assert has_element?(view, ~s([data-testid="game-channel-bar"][data-game-id="hex_pong"]))

    view |> element(~s([data-testid="game-channel-lfg"])) |> render_click()
    _ = :sys.get_state(view.pid)

    assert [line] = seat_lines()
    assert line.content =~ "#{nick.nickname} is looking for a partner in Hex Pong"

    slug = line.content |> String.split("/join/") |> List.last() |> String.trim()
    assert {:ok, %{kind: "play", target: target}} = ShareLinks.resolve(slug)
    assert target["game_id"] == "hex_pong"

    {:ok, session} = Lobby.get_session(target["session_token"])
    assert Lobby.open_session?(session)
    assert session.metadata["channel"] == "#hex-pong"

    # The card is still the newest line: a second press brings nothing new.
    view |> element(~s([data-testid="game-channel-lfg"])) |> render_click()
    _ = :sys.get_state(view.pid)
    assert [_still_one] = seat_lines()
  end

  test "a visitor sees the game's strip, and pressing it asks for an account", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/c/hex-pong")

    assert has_element?(view, ~s([data-testid="game-channel-bar"]))

    view |> element(~s([data-testid="game-channel-lfg"])) |> render_click()

    assert_patch(view, "/connect?return_to=%2Fc%2Fhex-pong&signup=games")
    assert seat_lines() == []
  end
end
