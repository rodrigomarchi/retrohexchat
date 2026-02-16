defmodule RetroHexChatWeb.ChatLivePreIdentifiedTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Chat.{AliasList, HighlightWords, PerformList}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.Queries, as: SvcQueries

  setup do
    ensure_channel("#lobby")
    :ok
  end

  defp unique_nick(prefix) do
    n = System.unique_integer([:positive])
    "#{prefix}#{n}"
  end

  defp register_and_cleanup(nick) do
    {:ok, _} = SvcQueries.insert_registered_nick(nick, "pass123")

    on_exit(fn ->
      case SvcQueries.find_by_nickname(nick) do
        nil -> :ok
        reg -> SvcQueries.delete_registered_nick(reg)
      end
    end)
  end

  # ── Pre-identified user loads persisted data on mount ────────────

  describe "pre-identified user loads persisted data on mount" do
    test "loads perform list from DB", %{conn: conn} do
      nick = unique_nick("PrPf")
      register_and_cleanup(nick)

      # Pre-save a perform list to DB
      list = PerformList.new()
      {:ok, list} = PerformList.add_entry(list, "/join #saved-channel")
      :ok = PerformList.save(nick, list)

      # Identify the nick (sets it in NickServ GenServer state)
      {:ok, _} = NickServ.identify(nick, "pass123")

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # Open perform dialog to verify entries loaded
      html = render_click(view, "open_perform_dialog")
      assert html =~ "/join #saved-channel"
    end

    test "loads aliases from DB", %{conn: conn} do
      nick = unique_nick("PrAl")
      register_and_cleanup(nick)

      # Pre-save aliases to DB
      aliases = AliasList.new()
      {:ok, aliases} = AliasList.add_entry(aliases, "greet", "/say hello everyone!")
      :ok = AliasList.save(nick, aliases)

      {:ok, _} = NickServ.identify(nick, "pass123")

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # Open alias dialog to verify entries loaded
      html = render_click(view, "open_alias_dialog")
      assert html =~ "greet"
    end

    test "loads highlight words from DB", %{conn: conn} do
      nick = unique_nick("PrHl")
      register_and_cleanup(nick)

      # Pre-save highlight words to DB
      words = HighlightWords.new()
      {:ok, words} = HighlightWords.add_entry(words, "saved-highlight-word", 1)
      :ok = HighlightWords.save(nick, words)

      {:ok, _} = NickServ.identify(nick, "pass123")

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # Open highlight dialog to verify entries loaded
      html = render_click(view, "open_highlight_dialog")
      assert html =~ "saved-highlight-word"
    end
  end

  # ── Pre-identified user can persist new data ─────────────────────

  describe "pre-identified user can persist new data" do
    test "identified flag is true so new data persists to DB", %{conn: conn} do
      nick = unique_nick("PrPs")
      register_and_cleanup(nick)

      {:ok, _} = NickServ.identify(nick, "pass123")

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # Open perform dialog and add an entry
      render_click(view, "open_perform_dialog")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #new-persist"})

      # Wait for async Task.start persistence
      Process.sleep(200)

      # Verify it persisted to DB
      assert {:ok, loaded} = PerformList.load(nick)
      entries = PerformList.entries(loaded)
      assert Enum.any?(entries, &(&1.command == "/join #new-persist"))
    end
  end

  # ── Pre-identified user sees identified status message ───────────

  describe "pre-identified user sees identified status message" do
    test "shows 'identified as' status message on mount", %{conn: conn} do
      nick = unique_nick("PrMs")
      register_and_cleanup(nick)

      {:ok, _} = NickServ.identify(nick, "pass123")

      {:ok, _view, html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      assert html =~ "You are now identified as #{nick}"
    end
  end

  # ── Force-renamed user loses identified status ───────────────────

  describe "force-renamed user loses identified status" do
    test "data added after force_rename does NOT persist", %{conn: conn} do
      nick = unique_nick("PrFr")
      register_and_cleanup(nick)

      {:ok, _} = NickServ.identify(nick, "pass123")

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      # Force rename — should reset identified to false
      send(view.pid, {:force_rename, %{reason: "Identify timeout"}})
      Process.sleep(100)

      html = render(view)
      assert html =~ "Identify timeout"

      # Now add a perform entry — it should NOT persist (identified = false)
      render_click(view, "open_perform_dialog")

      render_submit(view, "perform_dialog_add_confirm", %{
        "command" => "/join #should-not-persist"
      })

      Process.sleep(200)

      # The guest nick won't have any saved data
      # And the original nick should not have this entry either
      case PerformList.load(nick) do
        {:ok, loaded} ->
          entries = PerformList.entries(loaded)
          refute Enum.any?(entries, &(&1.command == "/join #should-not-persist"))

        {:error, :not_found} ->
          # No saved data at all — that's fine
          :ok
      end
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
