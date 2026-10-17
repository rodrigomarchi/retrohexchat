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
         Window.new("intro", dgettext("landing", "Install Retro Hex Chat"), :icon_terminal,
           width: 640,
           taskbar_label: dgettext("landing", "Install"),
           body: &page_intro/1,
           assigns: %{
             heading_id: "install-heading",
             description:
               dgettext(
                 "landing",
                 "Set up your own Retro Hex Chat server from source. Clone the repository, run the setup task, start Phoenix, and keep control of your community data."
               )
           },
           status: [dgettext("landing", "Installation guide")]
         ),
         Window.new(
           "c-setup-install-server-exe",
           dgettext("landing", "C:\\SETUP\\install_server.exe"),
           :icon_terminal,
           width: 560,
           taskbar_label: dgettext("landing", "Setup"),
           body: &c_setup_install_server_exe/1,
           status: [dgettext("landing", "Installation complete")]
         ),
         Window.new(
           "system-requirements",
           dgettext("landing", "System Requirements"),
           :icon_server,
           width: 560,
           taskbar_label: dgettext("landing", "Requirements"),
           body: &system_requirements/1,
           status: [{:check, dgettext("landing", "Ready to install")}]
         )
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

  embed_templates "install/*"
end
