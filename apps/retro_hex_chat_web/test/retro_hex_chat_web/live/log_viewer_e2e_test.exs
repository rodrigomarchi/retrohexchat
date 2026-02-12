defmodule RetroHexChatWeb.LogViewerE2ETest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  import Ecto.Query

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.NickServ

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

  # ── US1: Open/Close ────────────────────────────────────────

  describe "E2E: open/close log viewer" do
    test "Alt+L opens and closes", %{conn: conn} do
      nick = "E2eLv#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("#app-container") |> render_keydown(%{"key" => "l", "altKey" => true})
      assert render(view) =~ "log-viewer-dialog"

      view |> element("#app-container") |> render_keydown(%{"key" => "l", "altKey" => true})
      refute render(view) =~ "log-viewer-dialog"
    end

    test "Escape closes dialog", %{conn: conn} do
      nick = "E2eEsc#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("#app-container") |> render_keydown(%{"key" => "l", "altKey" => true})
      view |> element("#app-container") |> render_keydown(%{"key" => "Escape"})
      refute render(view) =~ "log-viewer-dialog"
    end

    test "menu bar opens log viewer", %{conn: conn} do
      nick = "E2eMnu#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("[data-testid=menu-log-viewer]") |> render_click()
      assert render(view) =~ "log-viewer-dialog"
    end

    test "toolbar button opens log viewer", %{conn: conn} do
      nick = "E2eTlb#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("[data-testid=toolbar-log-viewer]") |> render_click()
      assert render(view) =~ "log-viewer-dialog"
    end

    test "close button closes dialog", %{conn: conn} do
      nick = "E2eCls#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("[data-testid=menu-log-viewer]") |> render_click()

      view
      |> element("[data-testid=log-viewer-dialog] button[aria-label=Close]")
      |> render_click()

      refute render(view) =~ "log-viewer-dialog"
    end
  end

  # ── US1: Channel Search ────────────────────────────────────

  describe "E2E: channel search" do
    test "registered user can search channel history", %{conn: conn} do
      ch = "#e2ech-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "E2eSch#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "searchable content")

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view |> element("[data-testid=menu-log-viewer]") |> render_click()
      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      assert render(view) =~ "searchable content"
    end

    test "text filter works end-to-end", %{conn: conn} do
      ch = "#e2etxt-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "E2eTxt#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "important meeting")
      insert_msg!(ch, nick, "random chat")

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view |> element("[data-testid=menu-log-viewer]") |> render_click()
      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      view
      |> form("[data-testid=log-viewer-dialog] form", %{"nickname" => "", "text" => "meeting"})
      |> render_submit()

      html = render(view)
      assert html =~ "important meeting"
      refute html =~ "random chat"
    end

    test "empty results show message", %{conn: conn} do
      ch = "#e2eempt-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "E2eEm#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view |> element("[data-testid=menu-log-viewer]") |> render_click()
      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      assert render(view) =~ "No results found"
    end
  end

  # ── US1: Pagination ────────────────────────────────────────

  describe "E2E: pagination" do
    test "paginated results with navigation", %{conn: conn} do
      ch = "#e2epag-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "E2ePg#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      for i <- 1..55 do
        dt = DateTime.new!(~D[2026-01-01], Time.new!(0, 0, rem(i - 1, 60), 0), "Etc/UTC")
        insert_msg!(ch, nick, "msg #{i}", inserted_at: dt)
      end

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view |> element("[data-testid=menu-log-viewer]") |> render_click()
      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      assert render(view) =~ "Page 1 of 2"

      view |> element("[data-testid=log-next-btn]") |> render_click()
      assert render(view) =~ "Page 2 of 2"

      view |> element("[data-testid=log-prev-btn]") |> render_click()
      assert render(view) =~ "Page 1 of 2"
    end
  end

  # ── US1: Guest Mode ────────────────────────────────────────

  describe "E2E: guest mode" do
    test "guest user sees session channels", %{conn: conn} do
      ch = "#e2egst-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "E2eGst#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("form.chat-input-form") |> render_submit(%{"input" => "/join #{ch}"})

      view |> element("[data-testid=menu-log-viewer]") |> render_click()

      html = render(view)
      assert html =~ ch
    end
  end

  # ── US2: Export ────────────────────────────────────────────

  describe "E2E: export" do
    test "export .txt button works with results", %{conn: conn} do
      ch = "#e2eexp-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "E2eExp#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "export me")

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view |> element("[data-testid=menu-log-viewer]") |> render_click()
      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      # Export txt — should not crash
      view |> element("[data-testid=log-export-txt]") |> render_click()
      assert render(view) =~ "log-viewer-dialog"
    end

    test "export .html button works with results", %{conn: conn} do
      ch = "#e2eexh-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "E2eExH#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      insert_msg!(ch, nick, "export html")

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view |> element("[data-testid=menu-log-viewer]") |> render_click()
      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      view |> element("[data-testid=log-export-html]") |> render_click()
      assert render(view) =~ "log-viewer-dialog"
    end
  end

  # ── US3: Display Preferences ───────────────────────────────

  describe "E2E: display preferences" do
    test "toggle event type checkbox", %{conn: conn} do
      nick = "E2ePrf#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("[data-testid=menu-log-viewer]") |> render_click()

      view
      |> element("[data-testid=log-toggle-joins] input")
      |> render_click(%{"event_type" => "show_joins"})

      assert render(view) =~ "log-viewer-dialog"
    end

    test "change timestamp format", %{conn: conn} do
      nick = "E2eTs#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view |> element("[data-testid=menu-log-viewer]") |> render_click()

      view
      |> element("[data-testid=log-timestamp-format]")
      |> render_change(%{"format" => "hh_mm"})

      assert render(view) =~ "log-viewer-dialog"
    end
  end

  # ── US1: PM Search ─────────────────────────────────────────

  describe "E2E: PM search" do
    test "PM messages appear bidirectionally", %{conn: conn} do
      nick = "E2ePm#{System.unique_integer([:positive])}"
      peer = "E2ePeer#{System.unique_integer([:positive])}"

      NickServ.register(nick, "pass123")

      insert_pm!(nick, peer, "sent to peer")
      insert_pm!(peer, nick, "from peer")

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view |> element("[data-testid=menu-log-viewer]") |> render_click()

      view
      |> element("[data-testid=log-source-select]")
      |> render_change(%{"source" => "pm:#{peer}"})

      html = render(view)
      assert html =~ "sent to peer"
      assert html =~ "from peer"
    end
  end

  # ── US1: Date Filter ───────────────────────────────────────

  describe "E2E: date filter" do
    test "date range restricts results", %{conn: conn} do
      ch = "#e2edt-#{System.unique_integer([:positive])}"
      ensure_channel(ch)

      nick = "E2eDt#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      old_dt = DateTime.new!(~D[2026-01-01], ~T[12:00:00], "Etc/UTC")
      new_dt = DateTime.new!(~D[2026-02-10], ~T[12:00:00], "Etc/UTC")

      insert_msg!(ch, nick, "old msg", inserted_at: old_dt)
      insert_msg!(ch, nick, "new msg", inserted_at: new_dt)

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(100)

      view |> element("[data-testid=menu-log-viewer]") |> render_click()
      view |> element("[data-testid=log-source-select]") |> render_change(%{"source" => ch})

      view |> element("[data-testid=log-date-from]") |> render_change(%{"date" => "2026-02-01"})
      view |> element("[data-testid=log-refresh-btn]") |> render_click()

      html = render(view)
      assert html =~ "new msg"
      refute html =~ "old msg"
    end
  end
end
