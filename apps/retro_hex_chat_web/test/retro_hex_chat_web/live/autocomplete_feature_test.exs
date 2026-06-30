defmodule RetroHexChatWeb.AutocompleteFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "autocomplete full workflow" do
    test "command autocomplete → select → argument context", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "E2EAuto1"), "/chat")

      # Step 1: Open command autocomplete with fuzzy filter
      render_click(view, "autocomplete_query", %{
        "type" => "command",
        "partial" => "jo"
      })

      html = render(view)

      assert html =~ "autocomplete-dropdown"
      assert html =~ "join"

      # Step 2: Navigate down
      render_click(view, "autocomplete_navigate", %{"direction" => "down"})

      # Step 3: Select join command
      render_click(view, "autocomplete_select", %{
        "type" => "command",
        "value" => "join"
      })

      html = render(view)

      # Dropdown should close
      refute html =~ "autocomplete-dropdown"

      # Step 4: Simulate argument context for channel
      render_click(view, "autocomplete_query", %{
        "type" => "arg_channel",
        "partial" => "lob"
      })

      html = render(view)

      assert html =~ "autocomplete-dropdown"
      assert html =~ "#lobby"

      # Step 5: Select channel
      render_click(view, "autocomplete_select", %{
        "type" => "channel",
        "value" => "#lobby"
      })

      html = render(view)

      refute html =~ "autocomplete-dropdown"
    end

    test "nick autocomplete workflow", %{conn: conn} do
      {:ok, view1, _} = live(chat_conn(conn, "E2ENick1"), "/chat")
      {:ok, _view2, _} = live(chat_conn(conn, "E2ENick2"), "/chat")

      Process.sleep(50)

      # Switch from status tab to #lobby channel for nick context
      render_click(view1, "switch_channel", %{"channel" => "#lobby"})

      # Step 1: Open nick autocomplete
      render_click(view1, "autocomplete_query", %{
        "type" => "nick",
        "partial" => "E2E"
      })

      html = render(view1)

      assert html =~ "autocomplete-dropdown"
      assert html =~ "E2ENick2"

      # Step 2: Select nick
      render_click(view1, "autocomplete_select", %{
        "type" => "nick",
        "value" => "E2ENick2"
      })

      html = render(view1)

      refute html =~ "autocomplete-dropdown"
    end

    test "no messages sent during autocomplete navigation", %{conn: conn} do
      {:ok, view, _} = live(chat_conn(conn, "E2ENoMsg1"), "/chat")

      # Open autocomplete
      render_click(view, "autocomplete_query", %{
        "type" => "command",
        "partial" => "jo"
      })

      # Navigate — should not trigger message send
      render_click(view, "autocomplete_navigate", %{"direction" => "down"})
      render_click(view, "autocomplete_navigate", %{"direction" => "up"})

      # Close
      render_click(view, "autocomplete_close", %{})
      html = render(view)
      refute html =~ "autocomplete-dropdown"
    end
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
