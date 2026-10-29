defmodule RetroHexChatWeb.ShowcaseLive.Games.SoloLobbyPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.SoloLobby
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.GameCatalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Solo Lobby"),
       active_page: "solo-lobby",
       sample_preview: sample_preview()
     )}
  end

  # The preview is a real game's sheet, screenshot and all.
  defp sample_preview do
    {:ok, game} = GameCatalog.get_arcade("doom_shareware")
    game
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}
end
