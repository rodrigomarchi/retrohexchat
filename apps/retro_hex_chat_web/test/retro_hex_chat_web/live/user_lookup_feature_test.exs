defmodule RetroHexChatWeb.UserLookupFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChat.Presence.WhowasCache

  alias RetroHexChatWeb.Components.UI.{
    ChatContextMenu,
    MenuBarApp,
    NicklistContextMenu
  }

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "lookup entry points" do
    test "nicklist and chat nick menus expose Last Seen immediately after Whois" do
      nicklist_actions =
        render_component(&NicklistContextMenu.nicklist_context_menu/1,
          visible: true,
          target_nick: "Alice",
          on_action: "nicklist_context_action"
        )
        |> Floki.parse_document!()
        |> menu_actions()

      chat_actions =
        render_component(&ChatContextMenu.chat_context_menu/1,
          visible: true,
          type: :nick,
          target_nick: "Alice",
          on_action: "chat_context_action"
        )
        |> Floki.parse_document!()
        |> menu_actions()

      assert "context_whowas" in nicklist_actions
      assert "ctx_chat_whowas" in chat_actions

      assert index_of(nicklist_actions, "context_whois") + 1 ==
               index_of(nicklist_actions, "context_whowas")

      assert index_of(chat_actions, "ctx_chat_whois") + 1 ==
               index_of(chat_actions, "ctx_chat_whowas")
    end

    test "Tools menu exposes the User Lookup dialog action" do
      document =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          is_admin: false,
          on_action: "toolbar_action"
        )
        |> Floki.parse_document!()

      sections = Floki.find(document, "nav > div")
      tools_section = Enum.at(sections, 3)

      assert "open_user_lookup" in menu_actions(tools_section)

      tools_html = Floki.raw_html(tools_section)
      assert tools_html =~ "User Lookup"
    end

    test "toolbar action opens the User Lookup dialog", %{conn: conn} do
      view = connect_user(conn, "LookupMenu#{uid()}")

      refute has_element?(view, "#user-lookup-dialog-show-trigger")

      render_click(view, "toolbar_action", %{"action" => "open_user_lookup"})

      assert has_element?(view, "#user-lookup-dialog-show-trigger")
      assert render(view) =~ "Enter nickname..."
    end
  end

  describe "lookup dialog command mapping" do
    test "dialog defaults Enter submit to Whois card", %{conn: conn} do
      target = "LookupWho#{uid()}"
      _target_view = connect_user(conn, target)
      view = connect_user(conn, "LookupFrom#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_user_lookup"})

      html =
        view
        |> element(~s(form[data-testid="user-lookup-form"]))
        |> render_submit(%{"nickname" => target})

      assert html =~ "Whois: #{target}"
      assert html =~ "Query (PM)"
      assert html =~ "Whowas"
      refute has_element?(view, "#user-lookup-dialog-show-trigger")
    end

    test "dialog Last Seen button shows whowas card", %{conn: conn} do
      target = "LookupWas#{uid()}"
      WhowasCache.record(target, ["#lobby"], "Gone for now")
      view = connect_user(conn, "LWasFrom#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_user_lookup"})

      view
      |> element(~s(form[data-testid="user-lookup-form"]))
      |> render_change(%{"nickname" => target})

      html =
        view
        |> element(~s([data-testid="user-lookup-whowas"]))
        |> render_click()

      assert html =~ "Last Seen: #{target}"
      assert html =~ "Channels"
      assert html =~ "#lobby"
      assert html =~ "Quit message"
      assert html =~ "Gone for now"
    end
  end

  describe "command result cards" do
    test "typed /whois opens a structured result card by default", %{conn: conn} do
      target = "CardWho#{uid()}"
      _target_view = connect_user(conn, target)
      view = connect_user(conn, "CardFrom#{uid()}")

      submit_command(view, "/whois #{target}")

      html = render(view)
      assert html =~ "Whois: #{target}"
      assert html =~ ~s(data-testid="lookup-result-card")
      assert html =~ "Online for"
      assert html =~ "Registered"
      refute html =~ "-----------------------------"
    end

    test "typed /whowas opens a structured result card by default", %{conn: conn} do
      target = "CardWas#{uid()}"
      WhowasCache.record(target, ["#lobby", "#elixir"], "Later!")
      view = connect_user(conn, "CWasFrom#{uid()}")

      submit_command(view, "/whowas #{target}")

      html = render(view)
      assert html =~ "Last Seen: #{target}"
      assert html =~ ~s(data-testid="lookup-result-card")
      assert html =~ "#lobby, #elixir"
      assert html =~ "Later!"
      refute html =~ "-----------------------------"
    end

    test "context Last Seen opens the whowas card", %{conn: conn} do
      target = "CtxWas#{uid()}"
      WhowasCache.record(target, ["#lobby"], "Context bye")
      view = connect_user(conn, "CtxFrom#{uid()}")

      html = render_click(view, "context_whowas", %{"nick" => target})

      assert html =~ "Last Seen: #{target}"
      assert html =~ "Context bye"
    end
  end

  describe "Feature 10 help documentation" do
    test "help topics describe user lookup UI and cross-reference commands" do
      feature = HelpTopics.get_topic("feature-user-lookup")
      whois = HelpTopics.get_topic("cmd-whois")
      whowas = HelpTopics.get_topic("cmd-whowas")
      context_menus = HelpTopics.get_topic("feature-context-menus")
      shortcuts = HelpTopics.get_topic("keyboard-shortcuts")

      assert feature != nil
      assert "user lookup" in feature.keywords
      assert "cmd-whois" in feature.see_also
      assert "cmd-whowas" in feature.see_also
      assert "result card" in whois.keywords
      assert "user lookup" in whowas.keywords
      assert "last seen" in context_menus.keywords
      assert "user lookup" in shortcuts.keywords
    end
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp submit_command(view, command) do
    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => command})

    Process.sleep(50)
  end

  defp menu_actions(document) do
    document
    |> Floki.find("[data-testid^=\"context-menu-item-\"]")
    |> Enum.map(fn item ->
      item
      |> Floki.attribute("data-testid")
      |> List.first()
      |> String.replace_prefix("context-menu-item-", "")
    end)
  end

  defp index_of(actions, action), do: Enum.find_index(actions, &(&1 == action))

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
