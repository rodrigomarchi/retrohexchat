defmodule RetroHexChatWeb.AutojoinAutoAddTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChat.Services.NickServ

  defp register_and_identify(nick) do
    NickServ.register(nick, "pass123")
    {:ok, _} = NickServ.identify(nick, "pass123")
  end

  # ── US3: Auto-Join on /join ──────────────────────────────

  describe "US3: auto-add channel to auto-join on /join" do
    test "identified user gets channel added to auto-join on /join", %{conn: conn} do
      nick = "AJ#{uid()}"
      register_and_identify(nick)

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # Join a channel
      view |> render_submit("send_input", %{"input" => "/join #test-aj-#{uid()}"})

      # Give async persistence time to complete
      Process.sleep(100)

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
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})

      Process.sleep(100)

      # Guest has no persisted auto-join list
      assert {:error, :not_found} = AutoJoinList.load(nick)
    end

    test "#lobby is NOT added to auto-join", %{conn: conn} do
      nick = "LJ#{uid()}"
      register_and_identify(nick)

      {:ok, _view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # #lobby is auto-joined on connect, but should NOT be in auto-join list
      Process.sleep(100)

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
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      Process.sleep(50)

      # Part and rejoin
      view |> render_submit("send_input", %{"input" => "/part #{channel}"})
      Process.sleep(50)
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      Process.sleep(100)

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
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      Process.sleep(100)

      # Verify it was added
      {:ok, autojoin} = AutoJoinList.load(nick)
      entries = AutoJoinList.entries(autojoin)
      assert Enum.any?(entries, &(&1.channel_name == channel))

      # Part the channel
      view |> render_submit("send_input", %{"input" => "/part #{channel}"})
      Process.sleep(100)

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
      view |> render_submit("send_input", %{"input" => "/join #{channel}"})
      Process.sleep(50)
      view |> render_submit("send_input", %{"input" => "/part #{channel}"})
      Process.sleep(50)

      # No auto-join list should exist for guest
      assert {:error, :not_found} = AutoJoinList.load(nick)
    end
  end
end
