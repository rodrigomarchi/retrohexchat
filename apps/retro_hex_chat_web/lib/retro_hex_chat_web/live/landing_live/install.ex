defmodule RetroHexChatWeb.LandingLive.Install do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :install,
       canonical_path: "/install",
       page_title: dgettext("landing", "Install Retro Hex Chat — Three steps to your own server"),
       page_description:
         dgettext(
           "landing",
           "Clone, setup, and run your own Retro Hex Chat server in three simple steps. System requirements and getting started guide."
         )
     )}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page}>
      <section class="m-4" aria-labelledby="install-heading">
        <.landing_page_intro
          heading_id="install-heading"
          title={dgettext("landing", "Install Retro Hex Chat")}
          description={
            dgettext(
              "landing",
              "Set up your own Retro Hex Chat server from source. Clone the repository, run the setup task, start Phoenix, and keep control of your community data."
            )
          }
          status={dgettext("landing", "Installation guide")}
        >
          <:icon><Icons.icon_terminal class="w-4 h-4" /></:icon>
        </.landing_page_intro>

        <div class="grid md:grid-cols-2 gap-4">
          <%!-- ══════════════ STEPS ══════════════ --%>
          <.window>
            <.window_title_bar
              title={dgettext("landing", "C:\\SETUP\\install_server.exe")}
              controls={[:close]}
            >
              <:icon><Icons.icon_terminal class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h2 class="text-sm font-bold mb-3">
                {dgettext("landing", "Want your own server? Three steps.")}
              </h2>

              <div class="space-y-3">
                <fieldset class="border-2 border-gray-400 p-3">
                  <legend class="text-sm font-bold px-1">
                    <Icons.icon_git class="w-4 h-4 inline" /> {dgettext(
                      "landing",
                      "Step 1 — Clone"
                    )}
                  </legend>
                  <.step_clone />
                </fieldset>

                <fieldset class="border-2 border-gray-400 p-3">
                  <legend class="text-sm font-bold px-1">
                    <Icons.icon_wrench class="w-4 h-4 inline" /> {dgettext(
                      "landing",
                      "Step 2 — Setup"
                    )}
                  </legend>
                  <.step_setup />
                </fieldset>

                <fieldset class="border-2 border-gray-400 p-3">
                  <legend class="text-sm font-bold px-1">
                    <Icons.icon_terminal class="w-4 h-4 inline" /> {dgettext(
                      "landing",
                      "Step 3 — Run"
                    )}
                  </legend>
                  <.step_run />
                </fieldset>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                {dgettext("landing", "Installation complete")}
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ REQUIREMENTS ══════════════ --%>
          <.window>
            <.window_title_bar title={dgettext("landing", "System Requirements")} controls={[:close]}>
              <:icon><Icons.icon_server class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <div class="space-y-2">
                <div class="shadow-retro-field bg-white p-3 text-sm">
                  <strong>
                    <Icons.icon_elixir class="w-4 h-4 inline" /> {dgettext("landing", "Elixir")}
                  </strong>
                  {dgettext("landing", "— Version 1.17+")}
                </div>
                <div class="shadow-retro-field bg-white p-3 text-sm">
                  <strong>
                    <Icons.icon_postgres class="w-4 h-4 inline" /> {dgettext("landing", "PostgreSQL")}
                  </strong>
                  {dgettext("landing", "— Version 16+")}
                </div>
                <div class="shadow-retro-field bg-white p-3 text-sm">
                  <strong>
                    <Icons.icon_code class="w-4 h-4 inline" /> {dgettext("landing", "Node.js")}
                  </strong>
                  {dgettext("landing", "— Version 20+")}
                </div>
              </div>
              <p class="text-sm mt-3">
                {dgettext("landing", "A $5/month VPS handles it just fine.")}
              </p>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> {dgettext(
                  "landing",
                  "Ready to install"
                )}
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>
        </div>
      </section>
    </.landing_layout>
    """
  end
end
