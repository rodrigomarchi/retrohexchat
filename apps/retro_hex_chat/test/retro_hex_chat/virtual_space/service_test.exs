defmodule RetroHexChat.VirtualSpace.ServiceTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.VirtualSpace.{Queries, Registry, Service}

  @moduletag :integration

  defp unique_channel, do: "#space-svc-#{System.unique_integer([:positive])}"

  defp channel_with_member do
    channel = unique_channel()
    {:ok, pid} = ChannelSupervisor.start_child(channel)

    on_exit(fn ->
      if Process.alive?(pid), do: ChannelSupervisor.stop_child(pid)
    end)

    nick = insert(:registered_nick)
    {:ok, _} = ChannelServer.join(channel, nick.nickname)
    {channel, nick}
  end

  defp actor(nick) do
    %{
      user_id: nick.id,
      nickname: nick.nickname,
      identified: true,
      is_admin: false,
      is_server_operator: false
    }
  end

  defp stop_process(token) do
    case Registry.lookup(token) do
      {:ok, pid} ->
        GenServer.stop(pid, :normal)
        wait_for_deregistration(token, 50)

      {:error, :not_found} ->
        :ok
    end
  end

  # Registry cleanup is monitor-based and lags the process death briefly.
  defp wait_for_deregistration(_token, 0), do: flunk("process never left the registry")

  defp wait_for_deregistration(token, retries) do
    case Registry.lookup(token) do
      {:error, :not_found} ->
        :ok

      {:ok, _pid} ->
        Process.sleep(10)
        wait_for_deregistration(token, retries - 1)
    end
  end

  describe "create_session/3" do
    test "generates a strong token, persists pending and starts the child" do
      {channel, nick} = channel_with_member()

      assert {:ok, %{session: session, token: token}} =
               Service.create_session(actor(nick), channel, %{})

      on_exit(fn -> stop_process(token) end)

      assert byte_size(Base.url_decode64!(token, padding: false)) == 32
      assert session.status == "pending"
      assert session.channel_name == channel
      assert session.creator_nick == nick.nickname
      assert {:ok, _pid} = Registry.lookup(token)
    end

    test "respects the session rate limit" do
      Application.put_env(:retro_hex_chat, :p2p_session_rate_limit, {1, 60_000})
      on_exit(fn -> Application.delete_env(:retro_hex_chat, :p2p_session_rate_limit) end)

      {channel, nick} = channel_with_member()

      assert {:ok, %{token: token}} = Service.create_session(actor(nick), channel, %{})
      on_exit(fn -> stop_process(token) end)

      assert {:error, {:rate_limited, _seconds}} =
               Service.create_session(actor(nick), channel, %{})
    end

    test "applies the default 2h TTL" do
      {channel, nick} = channel_with_member()

      assert {:ok, %{session: session, token: token}} =
               Service.create_session(actor(nick), channel, %{})

      on_exit(fn -> stop_process(token) end)

      expected = DateTime.add(DateTime.utc_now(), 2 * 60 * 60, :second)
      assert_in_delta DateTime.to_unix(session.expires_at), DateTime.to_unix(expected), 5
    end

    test "accepts a ttl under the ceiling and rejects one above it" do
      {channel, nick} = channel_with_member()

      assert {:ok, %{session: session, token: token}} =
               Service.create_session(actor(nick), channel, %{ttl_ms: :timer.hours(4)})

      on_exit(fn -> stop_process(token) end)

      expected = DateTime.add(DateTime.utc_now(), 4 * 60 * 60, :second)
      assert_in_delta DateTime.to_unix(session.expires_at), DateTime.to_unix(expected), 5

      assert {:error, :ttl_too_long} =
               Service.create_session(actor(nick), channel, %{ttl_ms: :timer.hours(9)})
    end

    test "carries the title into the session" do
      {channel, nick} = channel_with_member()

      assert {:ok, %{session: session, token: token}} =
               Service.create_session(actor(nick), channel, %{title: "Guild sync"})

      on_exit(fn -> stop_process(token) end)
      assert session.title == "Guild sync"
    end
  end

  describe "create_session/3 max participants setting" do
    test "reads space_max_participants from server settings with fallback" do
      {channel, nick} = channel_with_member()

      {:ok, %{session: default_session, token: token1}} =
        Service.create_session(actor(nick), channel, %{})

      on_exit(fn -> stop_process(token1) end)
      assert default_session.max_participants == 20

      {:ok, _} =
        RetroHexChat.Services.Queries.upsert_setting("space_max_participants", "8", "Admin")

      other = insert(:registered_nick)
      {:ok, _} = ChannelServer.join(channel, other.nickname)

      {:ok, %{session: tuned_session, token: token2}} =
        Service.create_session(actor(other), channel, %{})

      on_exit(fn -> stop_process(token2) end)
      assert tuned_session.max_participants == 8
    end

    test "caps the setting at the configured ceiling" do
      {:ok, _} =
        RetroHexChat.Services.Queries.upsert_setting("space_max_participants", "500", "Admin")

      {channel, nick} = channel_with_member()

      {:ok, %{session: session, token: token}} =
        Service.create_session(actor(nick), channel, %{})

      on_exit(fn -> stop_process(token) end)
      assert session.max_participants == 50
    end
  end

  describe "join_session/2" do
    test "returns not_found for an unknown token" do
      nick = insert(:registered_nick)
      assert {:error, :not_found} = Service.join_session("no-such-token", actor(nick))
    end

    test "marks an overdue session expired before refusing" do
      {channel, nick} = channel_with_member()

      {:ok, %{session: session, token: token}} =
        Service.create_session(actor(nick), channel, %{})

      stop_process(token)

      {:ok, _} =
        session
        |> Queries.update_status("active", %{
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })

      assert {:error, :terminal_session} = Service.join_session(token, actor(nick))
      assert Queries.get_session_by_token(token).status == "expired"
    end

    test "restarts the child when the token is valid but the process is gone" do
      {channel, nick} = channel_with_member()

      {:ok, %{token: token}} = Service.create_session(actor(nick), channel, %{})
      stop_process(token)
      assert {:error, :not_found} = Registry.lookup(token)

      assert {:ok, %{participant: participant}} = Service.join_session(token, actor(nick))
      on_exit(fn -> stop_process(token) end)

      assert participant.key == "registered:#{nick.id}"
      assert {:ok, _pid} = Registry.lookup(token)
    end
  end

  describe "close_session/3" do
    test "records closed_at/closed_reason and stops the process" do
      {channel, nick} = channel_with_member()

      {:ok, %{token: token}} = Service.create_session(actor(nick), channel, %{})
      {:ok, _} = Service.join_session(token, actor(nick))

      assert :ok = Service.close_session(token, actor(nick), "creator_closed")

      db_session = Queries.get_session_by_token(token)
      assert db_session.status == "closed"
      assert db_session.closed_at
      assert db_session.closed_reason == "creator_closed"
      assert {:error, :not_found} = Registry.lookup(token)
    end

    test "a non-creator cannot close" do
      {channel, nick} = channel_with_member()
      other = insert(:registered_nick)

      {:ok, %{token: token}} = Service.create_session(actor(nick), channel, %{})
      on_exit(fn -> stop_process(token) end)

      assert {:error, :forbidden} = Service.close_session(token, actor(other), "nope")
    end

    test "does not rewrite an already-terminal (expired) session" do
      {channel, nick} = channel_with_member()
      {:ok, %{token: token}} = Service.create_session(actor(nick), channel, %{})

      stop_process(token)
      wait_for_deregistration(token, 50)

      session = Queries.get_session_by_token(token)

      {:ok, _} =
        Queries.update_status(session, "expired", %{
          closed_at: DateTime.utc_now(),
          closed_reason: "expired"
        })

      assert :ok = Service.close_session(token, actor(nick), "manual")

      reloaded = Queries.get_session_by_token(token)
      assert reloaded.status == "expired"
      assert reloaded.closed_reason == "expired"
    end

    test "closes a session whose process is already gone" do
      {channel, nick} = channel_with_member()

      {:ok, %{token: token}} = Service.create_session(actor(nick), channel, %{})
      stop_process(token)

      assert :ok = Service.close_session(token, actor(nick), "cleanup")
      assert Queries.get_session_by_token(token).status == "closed"
    end
  end

  describe "session_summary/1" do
    test "prefers the live process and falls back to the database" do
      {channel, nick} = channel_with_member()

      {:ok, %{token: token}} = Service.create_session(actor(nick), channel, %{})
      {:ok, _} = Service.join_session(token, actor(nick))

      assert {:ok, live} = Service.session_summary(token)
      assert live.participant_count == 1
      assert live.status == "active"
      assert live.kind == :space
      assert live.terminal? == false
      assert %DateTime{} = live.created_at

      stop_process(token)

      assert {:ok, db} = Service.session_summary(token)
      assert db.status == "active"
      assert db.participant_count == 1
      assert db.kind == :space
      assert db.terminal? == false
      assert %DateTime{} = db.created_at

      assert {:error, :not_found} = Service.session_summary("no-such-token")
    end
  end
end
