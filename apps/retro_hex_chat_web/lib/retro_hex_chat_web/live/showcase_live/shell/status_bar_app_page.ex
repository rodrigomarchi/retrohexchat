defmodule RetroHexChatWeb.ShowcaseLive.Shell.StatusBarAppPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.StatusBarApp
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Status Bar App"),
       active_page: "status-bar-app"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Status Bar App")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Normal Lag")}
        description="Session state only — who you are and what you are reading belong to the window title bar."
      >
        <.status_bar_app lag_ms={85} lag_status={:normal} />
        <.code_example>
          &lt;.status_bar_app lag_ms=&#123;85&#125; lag_status=&#123;:normal&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Online Buddies")}
        description="Notify-list badge — shown only when someone on the list is online."
      >
        <.status_bar_app
          lag_ms={120}
          lag_status={:normal}
          online_buddy_count={3}
          on_notify_toggle="toggle_notify_list"
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Warning Lag")}
        description="Lag is elevated — displayed in warning colour."
      >
        <.status_bar_app lag_ms={420} lag_status={:warning} />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Critical Lag")}
        description="Lag is dangerously high — displayed in error colour."
      >
        <.status_bar_app lag_ms={2100} lag_status={:critical} />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Timeout")}
        description="Server not responding — lag shown as '?' in error colour."
      >
        <.status_bar_app lag_ms={nil} lag_status={:timeout} />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Muted")}
        description="Notifications muted — mute icon displayed in the last zone."
      >
        <.status_bar_app lag_ms={55} lag_status={:normal} muted={true} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
