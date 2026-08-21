defmodule RetroHexChatWeb.LandingLive.LandingHelpers do
  @moduledoc """
  Landing LiveView adapter for shared UI components.

  The public page templates keep importing this module, but the visual chrome
  lives in `RetroHexChatWeb.Components.UI.Landing.LandingShell`.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.Desktop

  alias RetroHexChatWeb.ConnectForm
  alias RetroHexChatWeb.Icons

  @doc """
  The connect window every landing page carries, open on arrival.

  This is the same island the `/connect` desktop runs, so a reader signs in
  without leaving the page they landed on. Composing the window here rather than
  in `LandingShell` keeps `components/ui/` free of `live/` references, matching
  how the chat desktop mounts its own islands.

  It is also where the site's menus live. The window leads on every page — it is
  the one that does something rather than explains something — so its title bar
  is the one a Windows 98 desk hangs the menu strip under.
  """
  attr :trusted_device_id, :any, default: nil
  attr :active_page, :atom, required: true, doc: "marks the current page in Navigate"

  @spec landing_connect_window(map()) :: Phoenix.LiveView.Rendered.t()
  def landing_connect_window(assigns) do
    ~H"""
    <.desktop_window
      id="connect"
      title={dgettext("connect", "Connect to RetroHexChat")}
      width={560}
      min_width={360}
      resizable={false}
      default_centered
      body_class="p-4 overflow-y-auto"
      data-testid="landing-connect-window"
    >
      <:icon><Icons.icon_connect class="w-4 h-4" /></:icon>

      <:menu>
        <.landing_menu_bar active_page={@active_page} />
      </:menu>
      <%!-- The sign-in socket loads on first touch. If that chunk never
            arrives the form is inert, which reads as a dead page unless it
            says so — public_pages.js unhides this instead of failing quietly. --%>
      <.alert
        hidden
        variant="destructive"
        data-connect-boot-error
        data-testid="connect-boot-error"
      >
        <:icon><Icons.icon_warning /></:icon>
        <.alert_description>
          {dgettext(
            "landing",
            "Sign-in could not load. Check your connection and reload the page."
          )}
        </.alert_description>
      </.alert>
      <.live_component
        module={ConnectForm}
        id={ConnectForm.id()}
        trusted_device_id={@trusted_device_id}
        auto_login={true}
        csrf_token={Plug.CSRFProtection.get_csrf_token()}
        chat_session_path={~p"/chat/session"}
      />
    </.desktop_window>
    """
  end

  defdelegate landing_layout(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingShell
  defdelegate landing_menu_bar(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingShell
  defdelegate landing_page_intro(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingShell

  defdelegate readme_text(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate chat_mockup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate commands_mockup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups

  defdelegate channel_list_mockup(assigns),
    to: RetroHexChatWeb.Components.UI.Landing.LandingMockups

  defdelegate bot_mockup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate help_mockup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate step_clone(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate step_setup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate step_run(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
end
