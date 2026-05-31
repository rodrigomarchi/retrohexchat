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
    {:ok, assign(socket, page_title: gettext("Status Bar App"), active_page: "status-bar-app")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Status Bar App")}</h2>

      <.showcase_card
        title={gettext("Channel Mode")}
        description="Status bar showing a channel tab with user count and normal lag."
      >
        <.status_bar_app
          nickname="alice"
          channel="#lobby"
          user_count={42}
          tab_type={:channel}
          lag_ms={85}
          lag_status={:normal}
        />
        <.code_example>
          &lt;.status_bar_app
          nickname="alice"
          channel="#lobby"
          user_count=&#123;42&#125;
          tab_type=&#123;:channel&#125;
          lag_ms=&#123;85&#125;
          lag_status=&#123;:normal&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("PM Mode")}
        description="Status bar showing a private message tab (no user count)."
      >
        <.status_bar_app
          nickname="alice"
          channel="bob"
          tab_type={:pm}
          lag_ms={120}
          lag_status={:normal}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Warning Lag")}
        description="Lag is elevated — displayed in warning colour."
      >
        <.status_bar_app
          nickname="charlie"
          channel="#retro"
          user_count={7}
          tab_type={:channel}
          lag_ms={420}
          lag_status={:warning}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Critical Lag")}
        description="Lag is dangerously high — displayed in error colour."
      >
        <.status_bar_app
          nickname="dave"
          channel="#elixir"
          user_count={15}
          tab_type={:channel}
          lag_ms={2100}
          lag_status={:critical}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Timeout")}
        description="Server not responding — lag shown as '?' in error colour."
      >
        <.status_bar_app
          nickname="eve"
          channel="#help"
          user_count={3}
          tab_type={:channel}
          lag_ms={nil}
          lag_status={:timeout}
        />
      </.showcase_card>

      <.showcase_card
        title={gettext("Muted")}
        description="Notifications muted — mute icon displayed in the last zone."
      >
        <.status_bar_app
          nickname="frank"
          channel="#announcements"
          user_count={200}
          tab_type={:channel}
          lag_ms={55}
          lag_status={:normal}
          muted={true}
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
