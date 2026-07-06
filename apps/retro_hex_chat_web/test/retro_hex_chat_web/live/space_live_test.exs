defmodule RetroHexChatWeb.App.SpaceLiveTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.Queries, as: ServiceQueries
  alias RetroHexChat.VirtualSpace.{JoinToken, Queries, Registry, SessionServer}
  alias RetroHexChat.VirtualSpace.Supervisor, as: SpaceSupervisor

  @moduletag :liveview

  defp register_and_identify(nick) do
    NickServ.register(nick, "pass123")
    {:ok, _} = NickServ.identify(nick, "pass123")
    RetroHexChat.Repo.get_by!(RetroHexChat.Services.RegisteredNick, nickname: nick)
  end

  defp insert_space(creator, attrs \\ %{}) do
    base = %{
      token: "lvspace-#{System.unique_integer([:positive])}",
      channel_name: "#space-lv-#{uid()}",
      creator_id: creator.id,
      creator_nick: creator.nickname,
      title: "Guild Tavern",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }

    {:ok, session} = Queries.insert_session(Map.merge(base, attrs))
    session
  end

  defp stop_space(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      _ -> :ok
    end
  end

  describe "mount" do
    test "redirects to /connect without a chat_nickname", %{conn: conn} do
      creator = register_and_identify("spc#{uid()}")
      session = insert_space(creator)

      assert {:error, {:live_redirect, %{to: "/connect"}}} =
               live(conn, "/space/#{session.token}")
    end

    test "renders the invalid state for an unknown token", %{conn: conn} do
      nick = register_and_identify("spi#{uid()}")

      {:ok, _view, html} = live(chat_conn(conn, nick.nickname), "/space/no-such-token")
      assert html =~ ~s(data-testid="space-invalid")
    end

    test "renders the terminal state for an expired session", %{conn: conn} do
      creator = register_and_identify("spt#{uid()}")
      session = insert_space(creator)

      {:ok, _} =
        Queries.update_status(session, "expired", %{
          closed_at: DateTime.utc_now(),
          closed_reason: "expired"
        })

      {:ok, _view, html} = live(chat_conn(conn, creator.nickname), "/space/#{session.token}")
      assert html =~ ~s(data-testid="space-terminal")
      assert html =~ "expired"
    end

    test "renders the full state when the space is at capacity", %{conn: conn} do
      creator = register_and_identify("spf#{uid()}")
      other = register_and_identify("spo#{uid()}")
      session = insert_space(creator, %{max_participants: 1})

      {:ok, _pid} = SpaceSupervisor.start_child(session.token)
      on_exit(fn -> stop_space(session.token) end)

      {:ok, _} =
        SessionServer.join(session.token, %{
          user_id: creator.id,
          nickname: creator.nickname
        })

      {:ok, _view, html} = live(chat_conn(conn, other.nickname), "/space/#{session.token}")
      assert html =~ ~s(data-testid="space-full")
    end

    test "renders the shell with the canvas hook and signed join token", %{conn: conn} do
      creator = register_and_identify("sps#{uid()}")
      session = insert_space(creator)

      {:ok, _view, html} = live(chat_conn(conn, creator.nickname), "/space/#{session.token}")

      assert html =~ ~s(data-testid="space-shell")
      assert html =~ "Guild Tavern"
      assert html =~ ~s(phx-hook="SpaceCanvasHook")
      assert html =~ ~s(data-space-token="#{session.token}")

      [_, join_token] = Regex.run(~r/data-join-token="([^"]+)"/, html)
      assert {:ok, data} = JoinToken.verify(join_token)
      assert data.space_token == session.token
      assert data.user_id == creator.id
      assert data.nickname == creator.nickname
    end

    test "grants access after a reconnect restores identification wiped by a restart",
         %{conn: conn} do
      creator = register_and_identify("spr#{uid()}")
      session = insert_space(creator)

      # Simulate a server restart / deploy: NickServ's in-memory identified set is
      # wiped, but the DB registration and the user's signed pre-identified session
      # survive. The user is still legitimately identified.
      NickServ.remove_identified(creator.nickname)
      refute NickServ.identified?(creator.nickname)

      # The chat reconnects with the pre-identified session flag. This must restore
      # the NickServ identification so downstream checks (the space) stay consistent.
      {:ok, _view, _html} = live(chat_conn(conn, creator.nickname, pre_identified: true), "/chat")
      assert NickServ.identified?(creator.nickname)

      # Opening the already-running space now grants access instead of denying it.
      {:ok, _view, html} =
        live(chat_conn(conn, creator.nickname, pre_identified: true), "/space/#{session.token}")

      assert html =~ ~s(data-testid="space-shell")
    end

    test "denies a user without access to the session's invite-only channel", %{conn: conn} do
      creator = register_and_identify("spd#{uid()}")
      outsider = register_and_identify("spx#{uid()}")

      channel = "#space-priv-#{uid()}"
      insert_registered_channel(channel)
      session = insert_space(creator, %{channel_name: channel})

      {:ok, _view, html} = live(chat_conn(conn, outsider.nickname), "/space/#{session.token}")
      assert html =~ ~s(data-testid="space-denied")
    end
  end

  defp insert_registered_channel(channel) do
    {:ok, _} =
      %RetroHexChat.Services.RegisteredChannel{}
      |> Ecto.Changeset.change(%{
        name: channel,
        founder_nickname: "founder",
        modes: "+i",
        registered_at: DateTime.utc_now()
      })
      |> RetroHexChat.Repo.insert()

    ServiceQueries.list_invite_exceptions(channel)
  end
end
