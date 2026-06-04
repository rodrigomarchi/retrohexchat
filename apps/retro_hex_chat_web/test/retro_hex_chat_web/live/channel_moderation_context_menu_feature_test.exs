defmodule RetroHexChatWeb.ChannelModerationContextMenuFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.Server
  alias RetroHexChatWeb.Components.UI.{ChatContextMenu, NicklistContextMenu}

  describe "status-aware moderation menu slots" do
    test "nicklist menu renders inverse op, inverse voice, and channel mute actions" do
      document =
        render_component(&NicklistContextMenu.nicklist_context_menu/1,
          visible: true,
          target_nick: "Target",
          viewer_is_op: true,
          is_target_op: true,
          is_target_voiced: true,
          is_target_muted: false,
          on_action: "nicklist_context_action"
        )
        |> Floki.parse_document!()

      actions = menu_actions(document)

      assert "context_devoice" in actions
      assert "context_deop" in actions
      assert "context_mute" in actions
      refute "context_voice" in actions
      refute "context_op" in actions
      refute "context_unmute" in actions

      html = Floki.raw_html(document)
      assert html =~ "Remove Voice (-v)"
      assert html =~ "Remove Op (-o)"
      assert html =~ "Mute (channel)"
    end

    test "chat nick menu renders grant op, grant voice, and channel unmute actions" do
      document =
        render_component(&ChatContextMenu.chat_context_menu/1,
          visible: true,
          type: :nick,
          target_nick: "Target",
          viewer_is_op: true,
          is_target_op: false,
          is_target_voiced: false,
          is_target_muted: true,
          on_action: "chat_context_action"
        )
        |> Floki.parse_document!()

      actions = menu_actions(document)

      assert "ctx_chat_voice" in actions
      assert "ctx_chat_op" in actions
      assert "ctx_chat_unmute" in actions
      refute "ctx_chat_devoice" in actions
      refute "ctx_chat_deop" in actions
      refute "ctx_chat_mute" in actions

      html = Floki.raw_html(document)
      assert html =~ "Give Voice (+v)"
      assert html =~ "Give Op (+o)"
      assert html =~ "Unmute (channel)"
    end
  end

  describe "LiveView moderation context menu wiring" do
    test "nicklist menu derives role and mute labels from channel state", %{conn: conn} do
      channel = "#mod-menu-#{uid()}"
      op = "ModOp#{uid()}"
      target = "ModTarget#{uid()}"

      view = connect_user(conn, op)
      join_channel(view, channel)
      target_view = connect_user(conn, target)
      join_channel(target_view, channel)

      :ok = Server.set_mode(channel, op, "+v", [target])
      :ok = Server.channel_mute(channel, op, target)

      view
      |> render_click("nick_right_click", %{"nick" => target, "x" => 100, "y" => 200})

      html = render(view)

      assert html =~ "context-menu-item-context_devoice"
      assert html =~ "Remove Voice (-v)"
      assert html =~ "context-menu-item-context_op"
      assert html =~ "Give Op (+o)"
      assert html =~ "context-menu-item-context_unmute"
      assert html =~ "Unmute (channel)"
    end

    test "context actions devoice, deop, mute with duration, and unmute users", %{conn: conn} do
      channel = "#mod-act-#{uid()}"
      op = "ModAct#{uid()}"
      target = "ModTarget#{uid()}"

      view = connect_user(conn, op)
      join_channel(view, channel)
      target_view = connect_user(conn, target)
      join_channel(target_view, channel)

      :ok = Server.set_mode(channel, op, "+v", [target])
      render_click(view, "context_devoice", %{"nick" => target})
      assert role_for(channel, target) == :regular

      :ok = Server.set_mode(channel, op, "+o", [target])
      render_click(view, "ctx_chat_deop", %{"nick" => target})
      assert role_for(channel, target) == :regular

      html = render_click(view, "context_mute", %{"nick" => target})
      assert html =~ "Mute user: #{target}"
      assert html =~ "blank = permanent"

      view
      |> element("form[phx-submit=mute_duration_submit]")
      |> render_submit(%{"nick" => target, "duration" => "30s"})

      assert channel_muted?(channel, target)

      render_click(view, "ctx_chat_unmute", %{"nick" => target})
      refute channel_muted?(channel, target)
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

  defp role_for(channel, nick) do
    {:ok, state} = Server.get_state(channel)

    Enum.find_value(state.members, fn
      {^nick, role} -> role
      _ -> nil
    end)
  end

  defp channel_muted?(channel, nick) do
    {:ok, state} = Server.get_state(channel)
    nick in state.channel_mutes
  end
end
