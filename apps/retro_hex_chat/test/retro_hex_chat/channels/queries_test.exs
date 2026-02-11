defmodule RetroHexChat.Channels.QueriesTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :integration

  alias RetroHexChat.Channels.Queries
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  describe "find_registered_channel/1" do
    test "delegates to Services.Queries" do
      {:ok, _} = ServiceQueries.insert_registered_channel("#delegate", "founder1")
      channel = Queries.find_registered_channel("#delegate")
      assert channel.name == "#delegate"
      assert channel.founder_nickname == "founder1"
    end

    test "returns nil for unregistered channel" do
      assert nil == Queries.find_registered_channel("#unregistered")
    end
  end

  describe "load_persisted_state/1" do
    test "loads topic, modes, bans for a registered channel" do
      {:ok, _} = ServiceQueries.insert_registered_channel("#loaded", "founder1")
      {:ok, _} = ServiceQueries.add_ban("#loaded", "banned1", "founder1")
      {:ok, _} = ServiceQueries.add_ban("#loaded", "banned2", "founder1")

      state = Queries.load_persisted_state("#loaded")
      assert state.topic == ""
      assert state.modes == ""
      assert state.mode_key == nil
      assert state.mode_limit == nil
      assert Enum.sort(state.bans) == ["banned1", "banned2"]
    end

    test "returns nil for unregistered channel" do
      assert nil == Queries.load_persisted_state("#notreg")
    end

    test "loads topic from channel" do
      {:ok, channel} = ServiceQueries.insert_registered_channel("#withtopic", "founder1")

      channel
      |> Ecto.Changeset.change(%{topic: "Hello World"})
      |> Repo.update!()

      state = Queries.load_persisted_state("#withtopic")
      assert state.topic == "Hello World"
    end

    test "loads ban exceptions for registered channel" do
      {:ok, _} = ServiceQueries.insert_registered_channel("#withbex", "founder1")
      {:ok, _} = ServiceQueries.add_ban_exception("#withbex", "exempt1", "founder1")
      {:ok, _} = ServiceQueries.add_ban_exception("#withbex", "exempt2", "founder1")

      state = Queries.load_persisted_state("#withbex")
      assert Enum.sort(state.ban_exceptions) == ["exempt1", "exempt2"]
    end

    test "loads invite exceptions for registered channel" do
      {:ok, _} = ServiceQueries.insert_registered_channel("#withiex", "founder1")
      {:ok, _} = ServiceQueries.add_invite_exception("#withiex", "invited1", "founder1")

      state = Queries.load_persisted_state("#withiex")
      assert state.invite_exceptions == ["invited1"]
    end

    test "returns empty exception lists for channel with no exceptions" do
      {:ok, _} = ServiceQueries.insert_registered_channel("#noex", "founder1")

      state = Queries.load_persisted_state("#noex")
      assert state.ban_exceptions == []
      assert state.invite_exceptions == []
    end
  end
end
