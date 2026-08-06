defmodule RetroHexChat.Lobby.ServiceTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Chat.{IgnoreList, PreferencePersistence}
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.{Queries, Service}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  defp create_registered_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nick
  end

  defp create_session_record(creator_id, peer_id, attrs \\ %{}) do
    {:ok, session} =
      Queries.insert_session(
        Map.merge(
          %{
            token: "lobby-#{System.unique_integer([:positive])}",
            creator_id: creator_id,
            peer_id: peer_id,
            status: "pending"
          },
          attrs
        )
      )

    session
  end

  defp pair(suffix) do
    creator = create_registered_nick("svc_c#{suffix}")
    peer = create_registered_nick("svc_p#{suffix}")
    {creator, peer}
  end

  describe "decline_session/2" do
    test "the invited peer declining closes the pending session with reason declined" do
      {creator, peer} = pair("d1")
      session = create_session_record(creator.id, peer.id)

      assert :ok = Service.decline_session(session.token, peer.id)

      reloaded = Queries.get_session_by_token(session.token)
      assert reloaded.status == "closed"
      assert reloaded.closed_reason == "declined"
    end

    test "the creator cannot decline their own invite" do
      {creator, peer} = pair("d2")
      session = create_session_record(creator.id, peer.id)

      assert {:error, _message} = Service.decline_session(session.token, creator.id)
      assert Queries.get_session_by_token(session.token).status == "pending"
    end

    test "declining is only possible while the session is pending" do
      {creator, peer} = pair("d3")
      session = create_session_record(creator.id, peer.id, %{status: "lobby"})

      assert {:error, _message} = Service.decline_session(session.token, peer.id)
      assert Queries.get_session_by_token(session.token).status == "lobby"
    end
  end

  describe "cancel_invite/2" do
    test "the creator cancelling closes the pending session with reason invite_cancelled" do
      {creator, peer} = pair("c1")
      session = create_session_record(creator.id, peer.id)

      assert :ok = Service.cancel_invite(session.token, creator.id)

      reloaded = Queries.get_session_by_token(session.token)
      assert reloaded.status == "closed"
      assert reloaded.closed_reason == "invite_cancelled"
    end

    test "the invited peer cannot cancel the invite" do
      {creator, peer} = pair("c2")
      session = create_session_record(creator.id, peer.id)

      assert {:error, _message} = Service.cancel_invite(session.token, peer.id)
      assert Queries.get_session_by_token(session.token).status == "pending"
    end
  end

  describe "active_session_for_user/1" do
    test "finds the user's non-terminal session in either role, most recent first" do
      {creator, peer} = pair("a1")
      other = create_registered_nick("svc_oa1")

      _closed =
        create_session_record(creator.id, other.id, %{
          status: "closed",
          closed_at: DateTime.utc_now(),
          closed_reason: "user_closed"
        })

      session = create_session_record(other.id, creator.id)

      assert Lobby.active_session_for_user(creator.id).id == session.id
      assert Lobby.active_session_for_user(other.id).id == session.id
      assert Lobby.active_session_for_user(peer.id) == nil
    end
  end

  describe "can_create_session?/2" do
    test "blocks P2P from an unapplied pending ignore-list snapshot" do
      {creator, peer} = pair("b1")
      {:ok, ignore_list} = IgnoreList.add_entry(IgnoreList.new(), peer.nickname, :invites, nil)

      assert :ok = PreferencePersistence.enqueue(creator.nickname, :ignore_list, ignore_list)

      assert {:error, _message} = Lobby.can_create_session?(peer.id, creator.id)
    end

    test "pending ignore-list snapshot overrides the materialized table" do
      {creator, peer} = pair("b2")
      {:ok, ignore_list} = IgnoreList.add_entry(IgnoreList.new(), peer.nickname, :invites, nil)

      assert :ok = IgnoreList.save(creator.nickname, ignore_list)
      assert {:error, _message} = Lobby.can_create_session?(peer.id, creator.id)

      assert :ok = PreferencePersistence.enqueue(creator.nickname, :ignore_list, IgnoreList.new())
      assert :ok = Lobby.can_create_session?(peer.id, creator.id)
    end
  end
end
