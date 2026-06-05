defmodule RetroHexChatWeb.ChanServChannelCentralFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChat.Services.{ChanServ, NickServ, Queries}
  alias RetroHexChatWeb.Components.UI.ChannelCentralDialog

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "Registration tab entry point" do
    test "Channel Central component appends Registration after Invite Exceptions" do
      html =
        render_component(&ChannelCentralDialog.channel_central_dialog/1,
          id: "channel-central-dialog",
          show: true,
          channel_name: "#lobby",
          on_tab: "channel_central_tab"
        )

      assert html =~ ~s(phx-value-tab="registration")
      assert html =~ "Registration"
      assert html =~ "Invite Exc."
      assert String.contains?(html, "Invite Exc.") and String.contains?(html, "Registration")
    end
  end

  describe "Channel Central registration flow" do
    test "identified channel operator registers and drops a channel", %{conn: conn} do
      nick = "CsUiF#{uid()}"
      channel = "#csui-#{uid()}"
      view = connect_identified_user(conn, nick)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      html = render_click(view, "channel_central_tab", %{"tab" => "registration"})
      assert html =~ "Not registered"
      assert html =~ "Register Channel"

      html = render_click(view, "cc_cs_register", %{"channel" => channel})
      assert html =~ "Registered"
      assert html =~ "Founder"
      assert html =~ nick
      assert html =~ "Drop Registration"
      assert {:ok, info} = ChanServ.info(channel)
      assert info.founder == nick

      html = render_click(view, "cc_cs_drop_request", %{"channel" => channel})
      assert html =~ "Are you sure you want to drop #{channel}?"

      html = render_click(view, "cc_cs_drop", %{"channel" => channel})
      assert html =~ "Not registered"
      assert {:error, _msg} = ChanServ.info(channel)
    end

    test "unidentified operator sees disabled write controls", %{conn: conn} do
      nick = "CsUiG#{uid()}"
      channel = "#csuig-#{uid()}"
      view = connect_user(conn, nick)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      html = render_click(view, "channel_central_tab", %{"tab" => "registration"})

      assert html =~ "Not registered"
      assert html =~ "You must be identified with NickServ to use ChanServ."
      assert html =~ ~s(data-testid="cc-cs-register-disabled")
    end
  end

  describe "Channel Central access lists" do
    test "founder adds, selects, and removes AOP entries inline", %{conn: conn} do
      founder = "CsUiA#{uid()}"
      target = "CsT#{uid()}"
      channel = "#csaop-#{uid()}"
      view = connect_identified_user(conn, founder)
      register_nick(target)

      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})
      render_click(view, "channel_central_tab", %{"tab" => "registration"})
      render_click(view, "cc_cs_register", %{"channel" => channel})

      html = render_click(view, "cc_cs_access_tab", %{"level" => "aop"})
      assert html =~ "AOP"
      assert html =~ "No AOP entries"

      html =
        view
        |> element(~s(form[data-testid="cc-cs-access-form"]))
        |> render_submit(%{"level" => "aop", "nickname" => target})

      assert html =~ target
      assert html =~ founder
      assert Queries.find_access(channel, target).level == "aop"

      render_click(view, "cc_cs_access_select", %{"nick" => target})
      html = render_click(view, "cc_cs_access_remove", %{"level" => "aop"})

      refute html =~ ~s(data-testid="cc-cs-access-row-#{target}")
      refute Queries.find_access(channel, target)
    end

    test "SOP can edit AOP but not SOP", %{conn: conn} do
      founder = "CsFd#{uid()}"
      sop = "CsSop#{uid()}"
      aop_target = "CsA#{uid()}"
      channel = "#cssop-#{uid()}"
      register_nick(founder)
      register_nick(sop)
      register_nick(aop_target)
      {:ok, _} = ChanServ.register(channel, founder)
      {:ok, _} = ChanServ.manage_access(channel, :add, "sop", sop, founder)
      ensure_channel(channel)
      {:ok, _state} = Server.join(channel, founder)
      {:ok, _state} = Server.join(channel, sop)

      view = connect_identified_user(conn, sop)
      submit_command(view, "/join #{channel}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "open_channel_central", %{"cc_channel" => channel})

      html = render_click(view, "channel_central_tab", %{"tab" => "registration"})
      assert html =~ "SOP"
      assert html =~ "You do not have permission to manage this list."

      html = render_click(view, "cc_cs_access_tab", %{"level" => "aop"})
      assert html =~ ~s(data-testid="cc-cs-access-form")

      html =
        view
        |> element(~s(form[data-testid="cc-cs-access-form"]))
        |> render_submit(%{"level" => "aop", "nickname" => aop_target})

      assert html =~ aop_target
      assert Queries.find_access(channel, aop_target).level == "aop"
    end
  end

  describe "Feature 11 help documentation" do
    test "help topics describe ChanServ registration and access UI" do
      chanserv = HelpTopics.get_topic("chanserv")
      register = HelpTopics.get_topic("chanserv-register")
      access = HelpTopics.get_topic("chanserv-access")
      ui = HelpTopics.get_topic("chanserv-ui")
      channel_central = HelpTopics.get_topic("feature-channel-central")

      assert register != nil
      assert access != nil
      assert ui != nil
      assert "cs register" in register.keywords
      assert "sop" in access.keywords
      assert "registration tab" in ui.keywords
      assert "chanserv-ui" in chanserv.see_also
      assert "chanserv-ui" in channel_central.see_also
    end
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp connect_identified_user(conn, nick) do
    register_nick(nick)
    {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")
    view
  end

  defp register_nick(nick) do
    case NickServ.register(nick, "pass123") do
      {:ok, _message} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp submit_command(view, command) do
    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => command})
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
