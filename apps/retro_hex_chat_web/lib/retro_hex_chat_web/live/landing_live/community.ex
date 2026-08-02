defmodule RetroHexChatWeb.LandingLive.Community do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :community,
       windows: [
         %{id: "intro", label: dgettext("landing", "Community"), icon: :icon_community},
         %{id: "open-source", label: dgettext("landing", "Open Source"), icon: :icon_code},
         %{
           id: "support-the-project",
           label: dgettext("landing", "Support the Project"),
           icon: :icon_star
         },
         %{id: "tech-stack", label: dgettext("landing", "Tech Stack"), icon: :icon_server}
       ],
       canonical_path: "/community",
       page_title: dgettext("landing", "Open Source & Community — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Retro Hex Chat is MIT-licensed open source software. Contribute, star, share, or sponsor the project on GitHub."
         )
     )}
  end
end
