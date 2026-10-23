defmodule RetroHexChatWeb.ShowcaseLive.Shell.StatusBarAppPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.StatusBarApp
  import RetroHexChatWeb.Components.UI.Window, only: [window_status_bar: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Status Bar App"),
       active_page: "status-bar-app"
     )}
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Status Bar App")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Normal Lag")}
        description="Session state only — who you are and what you are reading belong to the window title bar."
      >
        <.window_status_bar data-testid="status-bar-app">
          <.status_bar_zones lag_ms={85} lag_status={:normal} />
        </.window_status_bar>
        <.code_example>
          &lt;.window_status_bar&gt;&lt;.status_bar_zones lag_ms=&#123;85&#125; lag_status=&#123;:normal&#125; /&gt;&lt;/.window_status_bar&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Online Buddies")}
        description="Notify-list badge — shown only when someone on the list is online."
      >
        <.window_status_bar data-testid="status-bar-app">
          <.status_bar_zones
            lag_ms={120}
            lag_status={:normal}
            online_buddy_count={3}
            on_notify_toggle="toggle_notify_list"
          />
        </.window_status_bar>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Warning Lag")}
        description="Lag is elevated — displayed in warning colour."
      >
        <.window_status_bar data-testid="status-bar-app">
          <.status_bar_zones lag_ms={420} lag_status={:warning} />
        </.window_status_bar>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Critical Lag")}
        description="Lag is dangerously high — displayed in error colour."
      >
        <.window_status_bar data-testid="status-bar-app">
          <.status_bar_zones lag_ms={2100} lag_status={:critical} />
        </.window_status_bar>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Timeout")}
        description="Server not responding — lag shown as '?' in error colour."
      >
        <.window_status_bar data-testid="status-bar-app">
          <.status_bar_zones lag_ms={nil} lag_status={:timeout} />
        </.window_status_bar>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Muted")}
        description="Notifications muted — mute icon displayed in the last zone."
      >
        <.window_status_bar data-testid="status-bar-app">
          <.status_bar_zones lag_ms={55} lag_status={:normal} muted={true} />
        </.window_status_bar>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
