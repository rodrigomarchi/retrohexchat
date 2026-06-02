defmodule RetroHexChatWeb.LandingLive.Faq do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Accordion

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :faq,
       canonical_path: "/faq",
       page_title: dgettext("landing", "FAQ — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Frequently asked questions about Retro Hex Chat: P2P calls, server requirements, security, contributing, and more."
         )
     )}
  end
end
