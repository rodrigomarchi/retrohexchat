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
