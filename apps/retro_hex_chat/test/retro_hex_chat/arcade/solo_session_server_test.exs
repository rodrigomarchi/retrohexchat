defmodule RetroHexChat.Arcade.SoloSessionServerTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Arcade
  alias RetroHexChat.Arcade.{Queries, SoloSessionServer}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :arcade_pending_timeout, :timer.seconds(60))
    Application.put_env(:retro_hex_chat, :arcade_lobby_warning_timeout, :timer.seconds(60))
    Application.put_env(:retro_hex_chat, :arcade_lobby_expiry_timeout, :timer.seconds(60))

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :arcade_pending_timeout)
      Application.delete_env(:retro_hex_chat, :arcade_lobby_warning_timeout)
      Application.delete_env(:retro_hex_chat, :arcade_lobby_expiry_timeout)
    end)

    n = System.unique_integer([:positive])
    creator = create_registered_nick("arc#{n}")
    {:ok, creator: creator}
  end

  describe "session lifecycle" do
    test "create and join transitions to lobby", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)

      assert :ok = Arcade.join_session(token, creator.id)

      {:ok, state} = SoloSessionServer.get_state(token)
      assert state.session.status == "lobby"
      assert state.creator_joined == true
    end

    test "select_game transitions to playing", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)

      assert :ok = Arcade.select_game(token, creator.id, "doom_shareware")

      {:ok, state} = SoloSessionServer.get_state(token)
      assert state.session.status == "playing"
      assert state.session.game_id == "doom_shareware"
    end

    test "finish_game transitions to finished", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)
      :ok = Arcade.select_game(token, creator.id, "doom_shareware")

      assert :ok = Arcade.finish_game(token, creator.id)

      # Server stops after finish, check DB directly
      session = Queries.get_session_by_token(token)
      assert session.status == "finished"
      assert session.closed_reason == "game_over"
    end

    test "close_session closes the session", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)

      assert :ok = Arcade.close_session(token, creator.id, "user_left")

      session = Queries.get_session_by_token(token)
      assert session.status == "closed"
      assert session.closed_reason == "user_left"
    end
  end

  describe "select_game validation" do
    test "rejects invalid game_id", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)

      assert {:error, :invalid_game_id} = Arcade.select_game(token, creator.id, "nonexistent")
    end

    test "rejects select when not in lobby", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      # Still pending (not joined yet)
      assert {:error, :not_in_lobby} =
               SoloSessionServer.select_game(token, creator.id, "doom_shareware")
    end
  end

  describe "finish_game edge cases" do
    test "finish_game when not playing returns error", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)

      # Still in lobby, not playing
      assert {:error, :not_playing} = Arcade.finish_game(token, creator.id)
    end

    test "finish_game by non-creator returns error", %{creator: creator} do
      other = create_registered_nick("fnc#{System.unique_integer([:positive])}")
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)
      :ok = Arcade.select_game(token, creator.id, "doom_shareware")

      assert {:error, :not_creator} = SoloSessionServer.finish_game(token, other.id)
    end

    test "double finish_game returns not_found on second call", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)
      :ok = Arcade.select_game(token, creator.id, "doom_shareware")

      assert :ok = Arcade.finish_game(token, creator.id)
      # GenServer stopped — second call gets :not_found
      Process.sleep(10)
      assert {:error, :not_found} = Arcade.finish_game(token, creator.id)
    end

    test "finish_game stores duration_seconds as column", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)
      :ok = Arcade.select_game(token, creator.id, "doom_shareware")

      # Small delay to get a non-zero duration
      Process.sleep(50)
      assert :ok = Arcade.finish_game(token, creator.id)

      session = Queries.get_session_by_token(token)
      assert is_integer(session.duration_seconds)
      assert session.duration_seconds >= 0
    end

    test "finish_game broadcasts duration_seconds via PubSub", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "arcade:#{token}")
      :ok = Arcade.select_game(token, creator.id, "doom_shareware")

      # Drain the "playing" broadcast
      assert_receive %{event: "arcade_status_changed", payload: %{status: "playing"}}, 1000

      :ok = Arcade.finish_game(token, creator.id)

      assert_receive %{
                       event: "arcade_status_changed",
                       payload: %{
                         status: "finished",
                         reason: "game_over",
                         duration_seconds: duration
                       }
                     },
                     1000

      assert is_integer(duration)
      assert duration >= 0
    end
  end

  describe "select_game edge cases" do
    test "select_game by non-creator returns error", %{creator: creator} do
      other = create_registered_nick("snc#{System.unique_integer([:positive])}")
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)

      assert {:error, :not_creator} =
               SoloSessionServer.select_game(token, other.id, "doom_shareware")
    end

    test "select_game broadcasts playing with started_at", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "arcade:#{token}")
      :ok = Arcade.select_game(token, creator.id, "doom_shareware")

      assert_receive %{
                       event: "arcade_status_changed",
                       payload: %{
                         status: "playing",
                         game_id: "doom_shareware",
                         started_at: started_at
                       }
                     },
                     1000

      assert is_binary(started_at)
      assert {:ok, _, _} = DateTime.from_iso8601(started_at)
    end
  end

  describe "audit trail" do
    test "join persists lobby_at in DB", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)

      # Before join — no lobby_at
      session = Queries.get_session_by_token(token)
      assert is_nil(session.lobby_at)

      :ok = Arcade.join_session(token, creator.id)

      session = Queries.get_session_by_token(token)
      assert %DateTime{} = session.lobby_at
    end

    test "select_game persists game_started_at in DB", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)

      # Before select — no game_started_at
      session = Queries.get_session_by_token(token)
      assert is_nil(session.game_started_at)

      :ok = Arcade.select_game(token, creator.id, "doom_shareware")

      session = Queries.get_session_by_token(token)
      assert %DateTime{} = session.game_started_at
    end

    test "finish_game persists duration_seconds in DB", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)
      :ok = Arcade.select_game(token, creator.id, "doom_shareware")
      Process.sleep(50)

      :ok = Arcade.finish_game(token, creator.id)

      session = Queries.get_session_by_token(token)
      assert is_integer(session.duration_seconds)
      assert session.duration_seconds >= 0
    end

    test "close during playing calculates duration_seconds", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)
      :ok = Arcade.select_game(token, creator.id, "doom_shareware")
      Process.sleep(50)

      :ok = Arcade.close_session(token, creator.id, "user_closed")

      session = Queries.get_session_by_token(token)
      assert session.status == "closed"
      assert is_integer(session.duration_seconds)
      assert session.duration_seconds >= 0
    end

    test "close from lobby has no duration_seconds", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)

      :ok = Arcade.close_session(token, creator.id, "user_closed")

      session = Queries.get_session_by_token(token)
      assert session.status == "closed"
      assert is_nil(session.duration_seconds)
    end

    test "full lifecycle has all audit timestamps", %{creator: creator} do
      {:ok, %{token: token}} = Arcade.create_session(creator.id)
      :ok = Arcade.join_session(token, creator.id)
      :ok = Arcade.select_game(token, creator.id, "doom_shareware")
      Process.sleep(50)
      :ok = Arcade.finish_game(token, creator.id)

      session = Queries.get_session_by_token(token)

      # All timestamps present
      assert %DateTime{} = session.inserted_at
      assert %DateTime{} = session.lobby_at
      assert %DateTime{} = session.game_started_at
      assert %DateTime{} = session.closed_at

      # Chronological order
      assert DateTime.compare(session.inserted_at, session.lobby_at) in [:lt, :eq]
      assert DateTime.compare(session.lobby_at, session.game_started_at) in [:lt, :eq]
      assert DateTime.compare(session.game_started_at, session.closed_at) in [:lt, :eq]

      # Duration recorded
      assert is_integer(session.duration_seconds)
      assert session.game_id == "doom_shareware"
    end
  end

  describe "non-creator access" do
    test "non-creator cannot join", %{creator: creator} do
      other = create_registered_nick("oth#{System.unique_integer([:positive])}")
      {:ok, %{token: token}} = Arcade.create_session(creator.id)

      assert {:error, "You are not the owner of this arcade session"} =
               Arcade.join_session(token, other.id)
    end
  end

  # --- Helpers ---

  defp create_registered_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{
        nickname: nickname,
        password: "password123"
      })
      |> Repo.insert()

    nick
  end
end
