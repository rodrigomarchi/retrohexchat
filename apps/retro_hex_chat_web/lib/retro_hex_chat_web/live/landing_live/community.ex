defmodule RetroHexChatWeb.LandingLive.Community do
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
       active_page: :community,
       page_title: dgettext("landing", "Open Source & Community — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Retro Hex Chat is MIT-licensed open source software. Contribute, star, share, or sponsor the project on GitHub."
         )
     )}
  end
end
