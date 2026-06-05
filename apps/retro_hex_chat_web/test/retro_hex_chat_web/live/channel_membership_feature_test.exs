defmodule RetroHexChatWeb.ChannelMembershipFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.Components.UI.{ChannelList, NicklistContextMenu}

  describe "send-invite entry point" do
    test "nicklist op menu renders Invite to Channel before Kick" do
      document =
        render_component(&NicklistContextMenu.nicklist_context_menu/1,
          visible: true,
          target_nick: "Guest",
          viewer_is_op: true,
          is_target_self: false,
          on_action: "nicklist_context_action"
        )
        |> Floki.parse_document!()

      actions = menu_actions(document)

      assert "context_invite_to_channel" in actions

      assert Enum.find_index(actions, &(&1 == "context_invite_to_channel")) <
               Enum.find_index(actions, &(&1 == "context_kick"))

      html = Floki.raw_html(document)
      assert html =~ "Invite to Channel..."
    end

    test "nicklist invite entry is hidden for non-ops and self targets" do
      non_op_html =
        render_component(&NicklistContextMenu.nicklist_context_menu/1,
          visible: true,
          target_nick: "Guest",
          viewer_is_op: false,
          is_target_self: false,
          on_action: "nicklist_context_action"
        )

      self_html =
        render_component(&NicklistContextMenu.nicklist_context_menu/1,
          visible: true,
          target_nick: "OpUser",
          viewer_is_op: true,
          is_target_self: true,
          on_action: "nicklist_context_action"
        )

      refute non_op_html =~ "context_invite_to_channel"
      refute self_html =~ "context_invite_to_channel"
    end

    test "context menu opens a channel picker and sends an invite", %{conn: conn} do
      suffix = uid()
      channel = "#cm-invite-#{suffix}"
      op = "CMOp#{suffix}"
      target = "CMGuest#{suffix}"

      op_view = connect_user(conn, op)
      join_channel(op_view, channel)
      target_view = connect_user(conn, target)

      on_exit(fn -> cleanup_channel(channel) end)

      :ok = Server.set_mode(channel, op, "+i", [])

      op_view
      |> render_click("nick_right_click", %{"nick" => target, "x" => 100, "y" => 200})

      html = render_click(op_view, "context_invite_to_channel", %{"nick" => target})

      assert html =~ "Invite to Channel"
      assert html =~ "Inviting: #{target}"
      assert html =~ channel

      html =
        op_view
        |> element("form[phx-submit=invite_channel_picker_submit]")
        |> render_submit(%{"target" => target, "channel" => channel})

      assert html =~ "* Inviting #{target} to #{channel}"
      refute has_element?(op_view, "#invite-channel-picker-dialog-show-trigger")

      assert invite_exception?(channel, target)
      render(target_view)
    end
  end

  describe "knock entry point" do
    test "Channel List marks invite-only rows and swaps Join for Request Access" do
      html =
        render_component(&ChannelList.channel_list/1,
          id: "channel-list-dialog",
          show: true,
          channels: [
            %{name: "#open", user_count: 3, topic: "Public", invite_only?: false, joined?: false},
            %{
              name: "#private",
              user_count: 2,
              topic: "Members only",
              invite_only?: true,
              joined?: false
            }
          ],
          selected_channel: "#private",
          on_search: "channel_list_filter",
          on_select: "channel_list_select",
          on_join: "channel_list_join",
          on_knock: "channel_list_knock",
          on_close: "close_channel_list"
        )

      assert html =~ "data-testid=\"channel-list-invite-only-#private\""
      assert html =~ "+i"
      assert html =~ "Request Access..."
      assert html =~ "channel-list-knock"
      refute html =~ "data-testid=\"channel-list-join\""
    end

    test "Channel List keeps Join for invite-only channels already joined" do
      html =
        render_component(&ChannelList.channel_list/1,
          id: "channel-list-dialog",
          show: true,
          channels: [
            %{
              name: "#private",
              user_count: 2,
              topic: "Members only",
              invite_only?: true,
              joined?: true
            }
          ],
          selected_channel: "#private",
          on_search: "channel_list_filter",
          on_select: "channel_list_select",
          on_join: "channel_list_join",
          on_knock: "channel_list_knock",
          on_close: "close_channel_list"
        )

      assert html =~ "Join"
      assert html =~ "channel-list-join"
      refute html =~ "Request Access..."
    end

    test "Channel List opens knock dialog and submits optional message", %{conn: conn} do
      suffix = uid()
      channel = "#cm-knock-#{suffix}"
      owner = "CMOwner#{suffix}"
      guest = "CMGuest#{suffix}"

      owner_view = connect_user(conn, owner)
      join_channel(owner_view, channel)
      on_exit(fn -> cleanup_channel(channel) end)
      :ok = Server.set_mode(channel, owner, "+i", [])

      guest_view = connect_user(conn, guest)

      render_click(guest_view, "channel_list")
      html = render_click(guest_view, "channel_list_select", %{"channel" => channel})

      assert html =~ "channel-list-invite-only-#{channel}"
      assert html =~ "Request Access..."

      html = render_click(guest_view, "channel_list_knock", %{"channel" => channel})

      assert html =~ "Request Channel Access"
      assert html =~ "Channel: #{channel}"
      refute has_element?(guest_view, "#channel-list-dialog-show-trigger")

      html =
        guest_view
        |> element("form[phx-submit=knock_request_submit]")
        |> render_submit(%{"channel" => channel, "message" => "Please let me in"})

      assert html =~ "Knock sent to #{channel}"
      refute has_element?(guest_view, "#knock-request-dialog-show-trigger")
    end

    test "Knock dialog disables submit when message exceeds 200 characters", %{conn: conn} do
      suffix = uid()
      channel = "#cm-knock-len-#{suffix}"
      owner = "CMLenOp#{suffix}"
      guest = "CMLenG#{suffix}"

      owner_view = connect_user(conn, owner)
      join_channel(owner_view, channel)
      on_exit(fn -> cleanup_channel(channel) end)
      :ok = Server.set_mode(channel, owner, "+i", [])

      guest_view = connect_user(conn, guest)
      render_click(guest_view, "channel_list")
      render_click(guest_view, "channel_list_knock", %{"channel" => channel})

      html =
        render_change(guest_view, "knock_request_change", %{
          "channel" => channel,
          "message" => String.duplicate("x", 201)
        })

      assert html =~ "201 / 200"

      document = Floki.parse_document!(html)
      assert Floki.find(document, "[data-testid=\"knock-request-submit\"][disabled]") != []
    end
  end

  describe "help documentation" do
    test "membership topics include send-invite and request-access discovery terms" do
      invite = HelpTopics.get_topic("cmd-invite")
      knock = HelpTopics.get_topic("cmd-knock")
      channel_list = HelpTopics.get_topic("cmd-list")

      assert "invite to channel" in invite.keywords
      assert "nicklist menu" in invite.keywords
      assert "request access" in knock.keywords
      assert "channel list" in knock.keywords
      assert "request access" in channel_list.keywords
      assert "+i" in channel_list.keywords
    end
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp join_channel(view, channel) do
    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => "/join #{channel}"})
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

  defp invite_exception?(channel, target) do
    {:ok, state} = Server.get_state(channel)
    target in state.invite_exceptions
  end

  defp cleanup_channel(name) do
    case RetroHexChat.Channels.Registry.lookup(name) do
      {:ok, pid} -> GenServer.stop(pid)
      _ -> :ok
    end
  end
end
