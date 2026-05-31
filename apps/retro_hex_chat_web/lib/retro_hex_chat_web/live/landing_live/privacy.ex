defmodule RetroHexChatWeb.LandingLive.Privacy do
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
       active_page: :privacy,
       page_title: gettext("Privacy Comparison — Retro Hex Chat vs Discord, Slack & Telegram"),
       page_description:
         gettext(
           "Side-by-side privacy comparison: data ownership, call routing, message access, AI training, and source code transparency."
         )
     )}
  end
end
