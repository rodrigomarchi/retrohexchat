defmodule RetroHexChatWeb.Components.UI.ChatAppHeader do
  @moduledoc """
  Design-system chrome for the chat shell header.

  Composes `app_header`, `menu_bar_app`, and `status_bar_app` into the single
  header row (logo + menu bar + right-aligned status bar) and owns the layout
  markup — including the `ml-auto` that pushes the status bar to the right edge.

  The header says nothing about identity or the active conversation: the chat
  window's title bar names both (see `ChatLive.ChatTitle`), and the account
  windows are reached from the File menu, the Start menu and the toolbar.

  Pure presentation: it takes only primitives and semantic event names (no
  `Session`, no domain calls), so the raw layout utility lives here in
  `components/ui/` rather than in the lint-scanned `chat_live/components/` glue.
  The chat-layer `ChatShell` derives those primitives from the session and
  delegates to this component.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.StatusBarApp
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]

  attr :lag_ms, :any, default: nil
  attr :lag_status, :atom, default: :normal, values: [:normal, :warning, :critical, :timeout]
  attr :online_buddy_count, :integer, default: 0
  attr :muted, :boolean, default: false
  attr :timezone, :string, default: "Etc/UTC"
  attr :is_admin, :boolean, default: false
  attr :arcade_available, :boolean, default: false, doc: "Enables the Games/Arcade menu item"
  attr :group_call, :map, default: nil, doc: "Active group call display map for the status bar"
  attr :p2p, :map, default: nil, doc: "Active P2P session display map for the status bar"
  attr :p2p_turn_available, :boolean, default: false
  attr :on_group_call_click, :any, default: "group_call_statusbar_click"
  attr :on_group_call_stop, :any, default: "group_call_statusbar_stop"
  attr :on_p2p_click, :any, default: "p2p_statusbar_click"
  attr :on_p2p_stop, :any, default: "p2p_statusbar_stop"

  attr :mobile_viewport, :any,
    default: nil,
    doc: "Narrow screen? `nil` until the client reports; only `false` trims the mobile drawer"

  attr :on_logo_action, :any, default: "about-dialog", doc: "Modal id opened by the logo"
  attr :on_toolbar_action, :any, default: "toolbar_action"
  attr :on_notify_toggle, :any, default: "toggle_notify_list"
  attr :on_mute_toggle, :any, default: "toggle_mute"

  @spec chat_app_header(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_app_header(assigns) do
    ~H"""
    <.app_header on_logo_click={show_modal(@on_logo_action)}>
      <:panels>
        <.menu_bar_app
          id="menubar"
          phx-hook="MenuBarHook"
          connected={true}
          is_admin={@is_admin}
          arcade_available={@arcade_available}
          p2p_active={@p2p != nil}
          p2p_turn_available={@p2p_turn_available}
          language_return_to="/chat"
          mobile_viewport={@mobile_viewport}
          on_action={@on_toolbar_action}
        />
        <%!-- The desktop tray owns the clock, the lag and the mute toggle, the
              way Win98 kept the volume and the connection lights down beside
              the clock rather than up in a menu bar. What stays here is what
              the tray has no room to say: an active call or P2P session, and
              the buddies online. --%>
        <.status_bar_app
          class="ml-auto"
          show_clock={false}
          show_lag={false}
          show_mute={false}
          lag_ms={@lag_ms}
          lag_status={@lag_status}
          online_buddy_count={@online_buddy_count}
          on_notify_toggle={@on_notify_toggle}
          muted={@muted}
          timezone={@timezone}
          on_mute_toggle={@on_mute_toggle}
          group_call={@group_call}
          on_group_call_click={@on_group_call_click}
          on_group_call_stop={@on_group_call_stop}
          p2p={@p2p}
          on_p2p_click={@on_p2p_click}
          on_p2p_stop={@on_p2p_stop}
        />
      </:panels>
    </.app_header>
    """
  end
end
