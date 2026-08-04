defmodule RetroHexChatWeb.ChatLive.Components.ChatShellTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Components.ChatShell

  @moduletag :unit

  defp header(session, overrides \\ %{}) do
    assigns =
      Map.merge(
        %{
          session: session,
          lag_ms: nil,
          lag_status: :normal,
          muted: false,
          timezone: "Etc/UTC"
        },
        overrides
      )

    render_component(&ChatShell.chat_shell_header/1, assigns)
  end

  test "renders the header chrome: logo, menubar hook, status bar" do
    html = header(Session.new("alice"))

    assert html =~ ~s(data-testid="app-header")
    assert html =~ ~s(id="menubar")
    assert html =~ ~s(phx-hook="MenuBarHook")
    assert html =~ ~s(data-testid="app-mobile-menu-trigger")
    assert html =~ ~s(data-testid="app-mobile-menu-category-file")
    assert html =~ ~s(data-testid="app-mobile-menu-category-tools")
    assert html =~ ~s(data-testid="app-mobile-menu-section-file")
    assert html =~ ~s(data-testid="app-mobile-menu-section-tools")
    assert html =~ ~s(app-menu-bar__desktop-menu)
    assert html =~ ~s(data-testid="status-bar-app")
  end

  test "the mobile rail carries every menu, each opening its own section" do
    html = header(Session.new("alice"))

    for section <- ~w(file edit view tools p2p games language help) do
      assert html =~ ~s(data-testid="app-mobile-menu-rail-#{section}")
      assert html =~ ~s(data-mobile-menu-open="#{section}")
      assert html =~ ~s(data-testid="app-mobile-menu-category-#{section}")
      assert html =~ ~s(data-testid="app-mobile-menu-section-#{section}")
    end
  end

  test "the header names neither the user nor the conversation — the title bar does" do
    session = %{Session.new("alice") | active_channel: "#lobby", active_pm: "bob"}
    html = header(session)

    refute html =~ "alice"
    refute html =~ "bob"
    refute html =~ "#lobby"
    refute html =~ ~s(data-testid="status-bar-account-widget")
  end

  test "derives the online buddy count from the session notify list" do
    notify = %{entries: [%{online: true}, %{online: false}, %{online: true}]}
    html = header(%{Session.new("alice") | notify_list: notify})

    assert html =~ ~s(data-testid="status-bar-notify-badge")
    assert html =~ ">2<"
  end

  test "hides the buddy badge when no buddy is online" do
    notify = %{entries: [%{online: false}]}
    html = header(%{Session.new("alice") | notify_list: notify})

    refute html =~ ~s(data-testid="status-bar-notify-badge")
  end

  test "renders active group call status bar controls" do
    html =
      header(Session.new("alice"), %{
        group_call: %{
          channel_name: "#lobby",
          status: :connected,
          participants: [%{id: 1}, %{id: 2}]
        }
      })

    assert html =~ ~s(data-testid="status-bar-group-call")
    assert html =~ ~s(data-testid="status-bar-group-call-stop")
    assert html =~ "Call: #lobby (2)"
  end

  test "renders rich P2P status bar facets without losing the base label" do
    html =
      header(Session.new("alice"), %{
        p2p_session: %{
          state: :connected,
          peer_nick: "trinity",
          call_summary: %{type: "video", duration: "00:01:02", quality_label: "Good"},
          file_summary: %{status: "sending", file_name: "report.pdf"},
          game_summary: %{active?: true},
          turn_only: true,
          turn_configured: true
        }
      })

    assert html =~ ~s(data-testid="status-bar-p2p")
    assert html =~ "P2P: trinity 00:01:02"
    assert html =~ ~s(data-testid="status-bar-p2p-facet-call")
    assert html =~ ~s(data-testid="status-bar-p2p-facet-file")
    assert html =~ ~s(data-testid="status-bar-p2p-facet-game")
    assert html =~ ~s(data-testid="status-bar-p2p-quality")
    assert html =~ ~s(data-testid="status-bar-p2p-relay")
  end
end
