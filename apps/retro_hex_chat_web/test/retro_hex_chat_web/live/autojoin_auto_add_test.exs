defmodule RetroHexChatWeb.AutojoinAutoAddTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Chat.{AutoJoinList, PreferencePersistence}
  alias RetroHexChat.Services.NickServ

  defp register_and_identify(nick) do
    NickServ.register(nick, "pass123")
    {:ok, _} = NickServ.identify(nick, "pass123")
  end

  defp submit_command_sync(view, command) do
    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => command})

    render(view)
  end

  defp apply_autojoin(nick) do
    assert {:ok, :applied} = PreferencePersistence.apply_pending(nick, "autojoin_list")
  end

  # ── US3: Auto-Join on /join ──────────────────────────────

  describe "US3: auto-add channel to auto-join on /join" do
    test "identified user gets channel added to auto-join on /join", %{conn: conn} do
      nick = "AJ#{uid()}"
      register_and_identify(nick)

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      submit_command_sync(view, "/join #test-aj-#{uid()}")
      apply_autojoin(nick)

      # Load the auto-join list from DB and verify the channel was added
      {:ok, autojoin} = AutoJoinList.load(nick)
      entries = AutoJoinList.entries(autojoin)
      channel_names = Enum.map(entries, & &1.channel_name)

      # Should contain the joined channel (may also contain #lobby from initial join)
      assert Enum.any?(channel_names, &String.starts_with?(&1, "#test-aj-"))
    end

    test "guest user does NOT get channel added to auto-join", %{conn: conn} do
      nick = "GJ#{uid()}"

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      channel = "#guest-aj-#{uid()}"

      submit_command_sync(view, "/join #{channel}")

      # Guest has no persisted auto-join list
      assert {:error, :not_found} = AutoJoinList.load(nick)
    end

    test "#lobby is NOT added to auto-join", %{conn: conn} do
      nick = "LJ#{uid()}"
      register_and_identify(nick)

      {:ok, _view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # #lobby is auto-joined on connect, but should NOT be in auto-join list
      refute PreferencePersistence.get_request(nick, "autojoin_list")

      case AutoJoinList.load(nick) do
        {:error, :not_found} ->
          # No auto-join entries at all — correct, #lobby was excluded
          assert true

        {:ok, autojoin} ->
          entries = AutoJoinList.entries(autojoin)
          channel_names = Enum.map(entries, & &1.channel_name)
          refute "#lobby" in channel_names
      end
    end

    test "rejoin does not create duplicate in auto-join", %{conn: conn} do
      nick = "RJ#{uid()}"
      register_and_identify(nick)

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      channel = "#dup-aj-#{uid()}"

      submit_command_sync(view, "/join #{channel}")

      # Part and rejoin
      submit_command_sync(view, "/part #{channel}")

      submit_command_sync(view, "/join #{channel}")
      apply_autojoin(nick)

      {:ok, autojoin} = AutoJoinList.load(nick)
      entries = AutoJoinList.entries(autojoin)

      matching = Enum.filter(entries, &(&1.channel_name == channel))
      assert length(matching) == 1
    end
  end

  # ── US3: Auto-Remove on /part ────────────────────────────

  describe "US3: auto-remove channel from auto-join on /part" do
    test "identified user gets channel removed from auto-join on /part", %{conn: conn} do
      nick = "AP#{uid()}"
      register_and_identify(nick)

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      channel = "#part-aj-#{uid()}"

      submit_command_sync(view, "/join #{channel}")
      apply_autojoin(nick)

      # Verify it was added
      {:ok, autojoin} = AutoJoinList.load(nick)
      entries = AutoJoinList.entries(autojoin)
      assert Enum.any?(entries, &(&1.channel_name == channel))

      # Part the channel
      submit_command_sync(view, "/part #{channel}")
      apply_autojoin(nick)

      # Verify it was removed
      case AutoJoinList.load(nick) do
        {:error, :not_found} ->
          assert true

        {:ok, autojoin_after} ->
          entries_after = AutoJoinList.entries(autojoin_after)
          refute Enum.any?(entries_after, &(&1.channel_name == channel))
      end
    end

    test "guest user does NOT trigger auto-join removal on /part", %{conn: conn} do
      nick = "GP#{uid()}"

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Guest joins and parts — no persistence at all
      channel = "#guest-pt-#{uid()}"

      submit_command_sync(view, "/join #{channel}")

      submit_command_sync(view, "/part #{channel}")

      # No auto-join list should exist for guest
      assert {:error, :not_found} = AutoJoinList.load(nick)
    end
  end

  # ── A refused join is not a join ─────────────────────────

  describe "a channel that refused you never reaches the list" do
    test "an invite-only room that turned you away stays off the list", %{conn: conn} do
      owner = "AJO#{uid()}"
      outsider = "AJK#{uid()}"
      register_and_identify(owner)
      register_and_identify(outsider)
      channel = "#test-ajk-#{uid()}"

      {:ok, owner_view, _} = live(chat_conn(conn, owner, pre_identified: true), "/chat")
      submit_command_sync(owner_view, "/join #{channel}")
      submit_command_sync(owner_view, "/mode +i")

      {:ok, view, _} = live(chat_conn(conn, outsider, pre_identified: true), "/chat")
      submit_command_sync(view, "/join #{channel}")
      PreferencePersistence.apply_pending(outsider, "autojoin_list")

      refute channel in :sys.get_state(view.pid).socket.assigns.session.channels,
             "the room was supposed to refuse the join"

      refute channel in autojoin_names(outsider),
             "a room that refused the join must not be on the list it is joined from"
    end

    test "leaving from the row's menu takes it off the list, like the command", %{conn: conn} do
      nick = "AJM#{uid()}"
      register_and_identify(nick)
      channel = "#test-ajm-#{uid()}"

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      submit_command_sync(view, "/join #{channel}")
      apply_autojoin(nick)
      assert channel in autojoin_names(nick)

      # Not the command: the menu item, which reaches part_channel/3 directly.
      render_click(view, "ctx_conversations_leave", %{"channel" => channel})
      PreferencePersistence.apply_pending(nick, "autojoin_list")

      refute channel in autojoin_names(nick),
             "every way of leaving has to mean the same thing"
    end

    test "being kicked takes the channel back off the list", %{conn: conn} do
      nick = "AJX#{uid()}"
      register_and_identify(nick)
      channel = "#test-ajx-#{uid()}"

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
      submit_command_sync(view, "/join #{channel}")
      apply_autojoin(nick)
      assert channel in autojoin_names(nick)

      send(
        view.pid,
        {:user_kicked, %{operator: "op", target: nick, reason: "bye", channel: channel}}
      )

      render(view)
      PreferencePersistence.apply_pending(nick, "autojoin_list")

      refute channel in autojoin_names(nick),
             "a room that put you out must not be walked back into on every connect"
    end
  end

  defp autojoin_names(nick) do
    case AutoJoinList.load(nick) do
      {:ok, list} -> list |> AutoJoinList.entries() |> Enum.map(& &1.channel_name)
      {:error, :not_found} -> []
    end
  end
end
