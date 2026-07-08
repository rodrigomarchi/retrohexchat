defmodule RetroHexChatWeb.Components.UI.ChatAppHeader do
  @moduledoc """
  Design-system chrome for the chat shell header.

  Composes `app_header`, `menu_bar_app`, and `status_bar_app` into the single
  header row (logo + menu bar + right-aligned status bar) and owns the layout
  markup — including the `ml-auto` that pushes the status bar to the right edge.

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

  attr :nickname, :string, required: true
  attr :account_state, :atom, default: :guest, values: [:guest, :identified, :away]
  attr :away, :boolean, default: false
  attr :channel, :string, default: nil
  attr :user_count, :integer, default: 0
  attr :tab_type, :atom, default: :channel, values: [:channel, :pm]
  attr :lag_ms, :any, default: nil
  attr :lag_status, :atom, default: :normal, values: [:normal, :warning, :critical, :timeout]
  attr :online_buddy_count, :integer, default: 0
  attr :muted, :boolean, default: false
  attr :timezone, :string, default: "Etc/UTC"
  attr :is_admin, :boolean, default: false
  attr :p2p, :map, default: nil, doc: "Active P2P session display map for the status bar"
  attr :on_p2p_click, :any, default: "p2p_statusbar_click"
  attr :on_p2p_stop, :any, default: "p2p_statusbar_stop"

  attr :on_logo_action, :any, default: "about-dialog", doc: "Modal id opened by the logo"
  attr :on_toolbar_action, :any, default: "toolbar_action"
  attr :on_account_click, :any, default: "open_account_dialog"
  attr :on_away_toggle, :any, default: "toggle_account_away"
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
          on_action={@on_toolbar_action}
        />
        <%!-- The desktop tray owns the clock; the status bar drops its own. --%>
        <.status_bar_app
          class="ml-auto"
          show_clock={false}
          nickname={@nickname}
          account_state={@account_state}
          away={@away}
          on_account_click={@on_account_click}
          on_away_toggle={@on_away_toggle}
          channel={@channel}
          user_count={@user_count}
          tab_type={@tab_type}
          lag_ms={@lag_ms}
          lag_status={@lag_status}
          online_buddy_count={@online_buddy_count}
          on_notify_toggle={@on_notify_toggle}
          muted={@muted}
          timezone={@timezone}
          on_mute_toggle={@on_mute_toggle}
          p2p={@p2p}
          on_p2p_click={@on_p2p_click}
          on_p2p_stop={@on_p2p_stop}
        />
      </:panels>
    </.app_header>
    """
  end
end
