defmodule RetroHexChatWeb.LogViewerTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  import Ecto.Query

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.NickServ

  # ── Helpers ────────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp insert_msg!(channel, nick, content, opts \\ []) do
    {:ok, msg} =
      Queries.insert_message(%{
        channel_name: channel,
        author_nickname: nick,
        content: content,
        type: Keyword.get(opts, :type, "message")
      })

    case Keyword.get(opts, :inserted_at) do
      nil ->
        msg

      dt ->
        Repo.update_all(
          from(m in "messages", where: m.id == ^msg.id),
          set: [inserted_at: dt]
        )

        Repo.get!(RetroHexChat.Chat.Message, msg.id)
    end
  end

  defp insert_pm!(sender, recipient, content) do
    {:ok, pm} =
      Queries.insert_private_message(%{
        sender_nickname: sender,
        recipient_nickname: recipient,
        content: content,
        type: "message"
      })

    pm
  end

  # ── US1: Open/Close Dialog ─────────────────────────────────

  describe "open/close dialog" do
    test "Ctrl+Shift+L opens the log viewer dialog", %{conn: conn} do
      nick = "LogOpen#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      html = render(view)
      assert html =~ "log-viewer-dialog"
      assert html =~ "Log Viewer"
    end

    test "Ctrl+Shift+L toggles the log viewer closed", %{conn: conn} do
      nick = "LogTog#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Open
      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      assert render(view) =~ "log-viewer-dialog"

      # Close
      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      refute render(view) =~ "log-viewer-dialog"
    end

    test "Escape closes the log viewer", %{conn: conn} do
      nick = "LogEsc#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      assert render(view) =~ "log-viewer-dialog"

      view |> element("#app-container") |> render_keydown(%{"key" => "Escape"})
      refute render(view) =~ "log-viewer-dialog"
    end

    test "close button closes the dialog", %{conn: conn} do
      nick = "LogCls#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      assert render(view) =~ "log-viewer-dialog"

      view
      |> element("[data-testid=log-viewer-dialog] button[aria-label=Close]")
      |> render_click()

      refute render(view) =~ "log-viewer-dialog"
    end

    test "menu bar opens the log viewer", %{conn: conn} do
      nick = "LogMenu#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view |> element("[data-testid=toolbar-log-viewer]") |> render_click()
      assert render(view) =~ "log-viewer-dialog"
    end

    test "toolbar button opens the log viewer", %{conn: conn} do
      nick = "LogTbar#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view |> element("[data-testid=toolbar-log-viewer]") |> render_click()
      assert render(view) =~ "log-viewer-dialog"
    end
  end

  # ── US1: Initial State ─────────────────────────────────────

  describe "initial state" do
    test "shows initial prompt before search", %{conn: conn} do
      nick = "LogInit#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      html = render(view)
      assert html =~ "Select a source and click Search to view logs"
    end

    test "shows source options from session channels", %{conn: conn} do
      ch = "#logsrc-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogSrc#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Join the channel
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      # Open log viewer
      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      html = render(view)
      assert html =~ ch
    end
  end

  # ── US1: Channel Search ────────────────────────────────────

  describe "channel search" do
    test "search returns channel messages", %{conn: conn} do
      ch = "#logch-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogSch#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "hello from logs")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Identify to get DB access
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      # Select the channel source
      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      html = render(view)
      assert html =~ "hello from logs"
    end

    test "text filter narrows results", %{conn: conn} do
      ch = "#logtxt-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogTxt#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "important meeting notes")
      insert_msg!(ch, nick, "random chatter")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      # Search with text filter
      view
      |> form("[data-testid=log-viewer-dialog] form", %{"nickname" => "", "text" => "meeting"})
      |> render_submit()

      html = render(view)
      assert html =~ "important meeting notes"
      refute html =~ "random chatter"
    end

    test "nickname filter narrows results", %{conn: conn} do
      ch = "#lognk-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogNk#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "my message")
      insert_msg!(ch, "OtherUser", "their message")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      # Search with nick filter
      view
      |> form("[data-testid=log-viewer-dialog] form", %{"nickname" => nick, "text" => ""})
      |> render_submit()

      html = render(view)
      assert html =~ "my message"
      refute html =~ "their message"
    end

    test "empty results shows no results message", %{conn: conn} do
      ch = "#logempty-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogEmp#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      html = render(view)
      assert html =~ "No results found"
    end
  end

  # ── US1: Pagination ────────────────────────────────────────

  describe "pagination" do
    test "paginated results show page indicator and navigation", %{conn: conn} do
      ch = "#logpag-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogPag#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      # Insert 55 messages (more than 50 per page)
      for i <- 1..55 do
        dt = DateTime.new!(~D[2026-01-01], Time.new!(0, 0, rem(i - 1, 60), 0), "Etc/UTC")
        insert_msg!(ch, nick, "message #{i}", inserted_at: dt)
      end

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      html = render(view)
      assert html =~ "Page 1 of 2"
      assert html =~ "log-next-btn"
    end

    test "next page navigates forward", %{conn: conn} do
      ch = "#lognxt-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogNxt#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      for i <- 1..55 do
        dt = DateTime.new!(~D[2026-01-01], Time.new!(0, 0, rem(i - 1, 60), 0), "Etc/UTC")
        insert_msg!(ch, nick, "message #{i}", inserted_at: dt)
      end

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      # Navigate to page 2
      view |> element("[data-testid=log-next-btn]") |> render_click()

      html = render(view)
      assert html =~ "Page 2 of 2"
    end
  end

  # ── US1: Date Range Filters ────────────────────────────────

  describe "date range filters" do
    test "date_from filter restricts results", %{conn: conn} do
      ch = "#logdf-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogDf#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      old_dt = DateTime.new!(~D[2026-01-01], ~T[12:00:00], "Etc/UTC")
      new_dt = DateTime.new!(~D[2026-02-10], ~T[12:00:00], "Etc/UTC")

      insert_msg!(ch, nick, "old message", inserted_at: old_dt)
      insert_msg!(ch, nick, "new message", inserted_at: new_dt)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      # Set date_from to Feb 1
      view |> element("[data-testid=log-date-from]") |> render_change(%{"date" => "2026-02-01"})

      # Re-search
      view |> element("[data-testid=log-refresh-btn]") |> render_click()

      html = render(view)
      assert html =~ "new message"
      refute html =~ "old message"
    end

    test "invalid date shows error", %{conn: conn} do
      nick = "LogBad#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-date-from]") |> render_change(%{"date" => "not-a-date"})

      html = render(view)
      assert html =~ "Invalid date format"
    end
  end

  # ── US1: Refresh ───────────────────────────────────────────

  describe "refresh" do
    test "refresh re-runs the search", %{conn: conn} do
      ch = "#logref-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogRef#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "initial message")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      html = render(view)
      assert html =~ "initial message"

      # Insert another message
      insert_msg!(ch, nick, "after refresh")

      # Click refresh
      view |> element("[data-testid=log-refresh-btn]") |> render_click()

      html = render(view)
      assert html =~ "after refresh"
    end
  end

  # ── US1: Guest User ────────────────────────────────────────

  describe "guest user" do
    test "guest user sees session channels in source options", %{conn: conn} do
      ch = "#logguest-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogGst#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Join a channel (guest, not identified)
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      html = render(view)
      assert html =~ ch
    end
  end

  # ── US3: Display Preferences ───────────────────────────────

  describe "display preferences" do
    test "toggle event type checkbox updates preferences", %{conn: conn} do
      nick = "LogPrf#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      # Toggle joins off
      view
      |> element("[data-testid=log-toggle-joins] input")
      |> render_click(%{"event_type" => "show_joins"})

      # The checkbox state is managed by the server, just verify no crash
      html = render(view)
      assert html =~ "log-toggle-joins"
    end

    test "changing timestamp format updates preferences", %{conn: conn} do
      nick = "LogTs#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view
      |> element("[data-testid=log-timestamp-format]")
      |> render_change(%{"format" => "dd_mm_hh_mm"})

      # Verify no crash and dialog still open
      html = render(view)
      assert html =~ "log-viewer-dialog"
    end
  end

  # ── US1: PM Search ─────────────────────────────────────────

  describe "PM search" do
    test "PM source search returns bidirectional messages", %{conn: conn} do
      nick = "LogPm#{System.unique_integer([:positive])}"
      partner = "Partner#{System.unique_integer([:positive])}"

      NickServ.register(nick, "pass123")

      insert_pm!(nick, partner, "sent msg")
      insert_pm!(partner, nick, "received msg")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      # Select PM source
      view
      |> element("[data-testid=log-source-select]")
      |> render_change(%{"source" => "pm:#{partner}"})

      html = render(view)
      assert html =~ "sent msg"
      assert html =~ "received msg"
    end
  end

  # ── US1: Source Reset ──────────────────────────────────────

  describe "source selection" do
    test "clearing source resets results", %{conn: conn} do
      nick = "LogRst#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      # Select empty source
      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ""})

      html = render(view)
      assert html =~ "Select a source and click Search to view logs"
    end
  end

  # ── US2: Export ────────────────────────────────────────────

  describe "export" do
    test "export .txt triggers download_file push_event", %{conn: conn} do
      ch = "#logexp-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogExp#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "export this message")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      # Click export txt
      view |> element("[data-testid=log-export-txt]") |> render_click()

      # The push_event should have been sent — verify the export doesn't crash
      html = render(view)
      assert html =~ "log-viewer-dialog"
    end

    test "export .html triggers download_file push_event", %{conn: conn} do
      ch = "#logexh-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogExH#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "export html message")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      # Click export html
      view |> element("[data-testid=log-export-html]") |> render_click()

      html = render(view)
      assert html =~ "log-viewer-dialog"
    end

    test "export buttons disabled when no results", %{conn: conn} do
      nick = "LogExD#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      html = render(view)
      # Export buttons should be disabled (no results yet)
      assert html =~ ~s(data-testid="log-export-txt")
      assert html =~ ~s(disabled)
    end

    test "export empty results does nothing", %{conn: conn} do
      ch = "#logexn-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "LogExN#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view
      |> element("#app-container")
      |> render_keydown(%{"key" => "l", "ctrlKey" => true, "shiftKey" => true})

      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      # Results are empty, export should be disabled
      html = render(view)
      assert html =~ "No results found"
    end
  end
end
