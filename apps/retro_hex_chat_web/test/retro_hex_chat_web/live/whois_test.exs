defmodule RetroHexChatWeb.WhoisTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  describe "/whois command output" do
    test "shows whois header and footer lines", %{conn: conn} do
      nick = "WhoQ#{System.unique_integer([:positive])}"
      target = "WhoT#{System.unique_integer([:positive])}"

      {:ok, _target_view, _html} = live(chat_conn(conn, target), "/chat")
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{target}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Whois: #{target}"
      assert html =~ "-----------------------------"
    end

    test "shows online time in whois", %{conn: conn} do
      nick = "WhoQ2#{System.unique_integer([:positive])}"
      target = "WhoT2#{System.unique_integer([:positive])}"

      {:ok, _target_view, _html} = live(chat_conn(conn, target), "/chat")
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{target}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Online for:"
    end

    test "shows idle time in whois", %{conn: conn} do
      nick = "WhoQ3#{System.unique_integer([:positive])}"
      target = "WhoT3#{System.unique_integer([:positive])}"

      {:ok, _target_view, _html} = live(chat_conn(conn, target), "/chat")
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{target}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Idle for:"
    end

    test "shows registration status in whois", %{conn: conn} do
      nick = "WhoQ4#{System.unique_integer([:positive])}"
      target = "WhoT4#{System.unique_integer([:positive])}"

      {:ok, _target_view, _html} = live(chat_conn(conn, target), "/chat")
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{target}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Registered: No"
    end

    test "shows shared channels in whois", %{conn: conn} do
      nick = "WhoQ5#{System.unique_integer([:positive])}"
      target = "WhoT5#{System.unique_integer([:positive])}"

      {:ok, _target_view, _html} = live(chat_conn(conn, target), "/chat")
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{target}"})

      Process.sleep(50)
      html = render(view)

      # Both are in #lobby
      assert html =~ "Shared channels:"
      assert html =~ "#lobby"
    end

    test "self-whois works", %{conn: conn} do
      nick = "WhoSelf#{System.unique_integer([:positive])}"

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{nick}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Whois: #{nick}"
      assert html =~ "Online for:"
    end

    test "whois for non-existent user shows not online message", %{conn: conn} do
      nick = "WhoQ6#{System.unique_integer([:positive])}"

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois OfflineUser12345"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "OfflineUser12345 is not online"
    end

    test "double-click on nicklist triggers PM (nicklist_dblclick)", %{conn: conn} do
      nick = "DblClk#{System.unique_integer([:positive])}"

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Double-click opens PM query window via nicklist_dblclick event
      render_click(view, "nicklist_dblclick", %{"nick" => nick})

      html = render(view)

      # Double-click on nicklist now opens a PM — check for switch_pm link
      assert html =~ "switch_pm"
    end
  end
end
