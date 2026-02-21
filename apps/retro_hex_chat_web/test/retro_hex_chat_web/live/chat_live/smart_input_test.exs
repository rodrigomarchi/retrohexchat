defmodule RetroHexChatWeb.ChatLive.SmartInputTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ── textarea rendering ────────────────────────────────────

  describe "textarea rendering" do
    test "renders a textarea element with correct attributes", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "TextareaUser"), "/chat")

      assert html =~ ~s(id="chat-input")
      assert html =~ ~s(name="input")
      assert html =~ ~s(maxlength="1000")
      assert html =~ ~s(autocomplete="off")
      assert html =~ "<textarea"
      # The main chat input should be a textarea, not an input
      refute html =~ ~s(id="chat-input" type="text")
    end

    test "textarea has rows=1 for single-line default", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "RowsUser"), "/chat")

      assert html =~ ~s(rows="1")
    end

    test "textarea preserves AutocompleteHook", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "HookUser"), "/chat")

      assert html =~ ~s(phx-hook="AutocompleteHook")
    end
  end

  # ── form submission ────────────────────────────────────────

  describe "form submission with textarea" do
    test "submitting form with text sends message", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "SendUser"), "/chat")

      # Switch from status tab to #lobby to send a channel message
      view |> render_click("switch_channel", %{"channel" => "#lobby"})
      view |> element("form.chat-input-form") |> render_submit(%{"input" => "Hello world"})

      Process.sleep(50)
      html = render(view)
      assert html =~ "Hello world"
    end

    test "submitting empty textarea is a no-op", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "EmptyTxt"), "/chat")

      html =
        view |> element("form.chat-input-form") |> render_submit(%{"input" => ""})

      assert html =~ "chat-input-form"
    end

    test "command input still works via form submit", %{conn: conn} do
      ensure_channel("#smartjoin")
      {:ok, view, _html} = live(chat_conn(conn, "CmdUser"), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #smartjoin"})

      html = render(view)
      assert html =~ "#smartjoin"
    end
  end

  # ── contextual placeholder ────────────────────────────────

  describe "contextual placeholder" do
    test "shows channel-specific placeholder when in a channel", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PlaceChan"), "/chat")

      # Switch from status tab to #lobby channel
      view |> render_click("switch_channel", %{"channel" => "#lobby"})

      html = render(view)
      assert html =~ "Message to #lobby"
      assert html =~ "/ for commands"
    end

    test "shows Status placeholder when on status tab", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PlaceStatus"), "/chat")

      # Switch to status tab (lobby is active on mount)
      view |> render_click("switch_to_status")

      html = render(view)
      assert html =~ "Type a command"
      assert html =~ "/ for list"
    end

    test "shows PM placeholder when in a PM", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "PlacePM"), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/query PMTarget"})

      html = render(view)
      assert html =~ "Message to PMTarget"
      assert html =~ "/ for commands"
    end

    test "placeholder updates on channel switch", %{conn: conn} do
      ensure_channel("#placeholder_ch")
      {:ok, view, _html} = live(chat_conn(conn, "PlaceSwitch"), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/join #placeholder_ch"})

      html = render(view)
      assert html =~ "Message to #placeholder_ch"

      view |> render_click("switch_to_status")

      html = render(view)
      assert html =~ "Type a command"
    end
  end

  # ── textarea expansion ────────────────────────────────────

  describe "textarea expansion" do
    test "textarea renders with rows=1 for single-line default", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "ExpandUser"), "/chat")

      assert html =~ ~s(rows="1")
      assert html =~ "<textarea"
    end

    test "textarea has correct CSS class for expansion", %{conn: conn} do
      {:ok, _view, html} = live(chat_conn(conn, "CSSExpand"), "/chat")

      # The textarea should be inside chat-input-form, which is inside chat-input-area
      assert html =~ "chat-input-area"
      assert html =~ "chat-input-form"
    end
  end

  # ── helpers ────────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
