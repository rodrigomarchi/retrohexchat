defmodule RetroHexChatWeb.SpacePanelsTest do
  use RetroHexChatWeb.ConnCase, async: false

  import RetroHexChat.Factory

  @moduletag :integration

  alias RetroHexChat.Accounts.Avatars
  alias RetroHexChat.Channels.Pins
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Queries
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.SpacePanels

  defp channel_with(members) do
    channel = "#sp-panels-#{System.unique_integer([:positive])}"
    {:ok, pid} = ChannelSupervisor.start_child(channel)
    Enum.each(members, &({:ok, _} = Server.join(channel, &1)))

    on_exit(fn ->
      case ChannelRegistry.lookup(channel) do
        {:ok, ^pid} -> ChannelSupervisor.stop_child(pid)
        _gone -> :ok
      end
    end)

    channel
  end

  test "an arcade cabinet shelves every game with its cover" do
    channel = channel_with(["ana"])
    %{games: games} = SpacePanels.fill(%{kind: "arcade"}, "construct:" <> channel, "ana")

    assert length(games) == length(GameCatalog.list())

    for game <- GameCatalog.list() do
      shelved = Enum.find(games, &(&1.id == game.id))

      if game.screenshot do
        # The digested address the rest of the site serves it from.
        assert shelved.cover == game.screenshot.path
        assert shelved.cover =~ ~r{^/images/games/.+\.webp}
      else
        assert shelved.cover == nil
      end
    end
  end

  test "a pinned line carries the portrait of whoever wrote it, if they chose one" do
    insert(:registered_nick, nickname: "bob")
    insert(:registered_nick, nickname: "cy")
    :ok = Avatars.remember("bob", "knight")
    channel = channel_with(["ana"])

    for {author, text} <- [{"bob", "Bring snacks"}, {"cy", "Bring drinks"}] do
      {:ok, message} =
        Queries.insert_message(%{channel_name: channel, author_nickname: author, content: text})

      {:ok, _pin} = Pins.pin(channel, message.id, "ana")
    end

    %{pins: pins} = SpacePanels.fill(%{kind: "board"}, "construct:" <> channel, "ana")

    assert %{avatar: "knight"} = Enum.find(pins, &(&1.author == "bob"))
    assert %{avatar: nil} = Enum.find(pins, &(&1.author == "cy"))
  end
end
