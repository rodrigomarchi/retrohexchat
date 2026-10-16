defmodule RetroHexChatWeb.Site.Pages.Install do
  @moduledoc false
  use RetroHexChatWeb.Site.Page

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    {:ok,
     %{
       active_page: :install,
       windows: [
         %{id: "intro", label: dgettext("landing", "Install"), icon: :icon_terminal},
         %{
           id: "c-setup-install-server-exe",
           label: dgettext("landing", "Setup"),
           icon: :icon_terminal
         },
         %{
           id: "system-requirements",
           label: dgettext("landing", "Requirements"),
           icon: :icon_server
         }
       ],
       canonical_path: "/install",
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), "/"},
           {dgettext("landing", "Install"), "/install"}
         ])
       ],
       page_title: dgettext("landing", "Install Retro Hex Chat — Three steps to your own server"),
       page_description:
         dgettext(
           "landing",
           "Clone, setup, and run your own Retro Hex Chat server in three simple steps. System requirements and getting started guide."
         )
     }}
  end

  @impl RetroHexChatWeb.Site.Page
  def render(assigns) do
    ~H"""
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
        <.document_section
          id="c-setup-install-server-exe"
          width={560}
          title={dgettext("landing", "C:\\SETUP\\install_server.exe")}
        >
          <:icon><Icons.icon_terminal class="w-4 h-4" /></:icon>
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
          <:status>
            <.window_status_bar_field grow>
              {dgettext("landing", "Installation complete")}
            </.window_status_bar_field>
          </:status>
        </.document_section>

        <%!-- ══════════════ REQUIREMENTS ══════════════ --%>
        <.document_section
          id="system-requirements"
          width={560}
          title={dgettext("landing", "System Requirements")}
        >
          <:icon><Icons.icon_server class="w-4 h-4" /></:icon>
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
            <div class="shadow-retro-field bg-white p-3 text-sm">
              <strong>
                <Icons.icon_conference class="w-4 h-4 inline" /> {dgettext(
                  "landing",
                  "Conference media"
                )}
              </strong>
              {dgettext(
                "landing",
                "— Open the SFU UDP port range 50000–50100 for channel conferences"
              )}
            </div>
          </div>
          <p class="text-sm mt-3">
            {dgettext(
              "landing",
              "A $5/month VPS handles a small server; conferences need reachable UDP media ports."
            )}
          </p>
          <:status>
            <.window_status_bar_field grow>
              <Icons.icon_checkmark class="w-3 h-3 inline" /> {dgettext(
                "landing",
                "Ready to install"
              )}
            </.window_status_bar_field>
          </:status>
        </.document_section>
      </div>
    </section>
    """
  end
end
