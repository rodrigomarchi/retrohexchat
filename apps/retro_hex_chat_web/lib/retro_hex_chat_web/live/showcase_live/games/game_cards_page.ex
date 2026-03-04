defmodule RetroHexChatWeb.ShowcaseLive.Games.GameCardsPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Game Cards", active_page: "game-cards", selected: nil)}
  end

  @impl true
  def handle_event("select-game", %{"game" => game}, socket) do
    {:noreply, assign(socket, selected: game)}
  end

  attr :name, :atom, required: true

  defp game_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% :doom -> %>
        <Icons.icon_game_doom class="w-8 h-8" />
      <% :freedoom1 -> %>
        <Icons.icon_game_freedoom1 class="w-8 h-8" />
      <% :freedoom2 -> %>
        <Icons.icon_game_freedoom2 class="w-8 h-8" />
      <% :freedm -> %>
        <Icons.icon_game_freedm class="w-8 h-8" />
      <% :chex -> %>
        <Icons.icon_game_chex class="w-8 h-8" />
      <% :hacx -> %>
        <Icons.icon_game_hacx class="w-8 h-8" />
      <% :rekkr -> %>
        <Icons.icon_game_rekkr class="w-8 h-8" />
      <% :librequake -> %>
        <Icons.icon_game_librequake class="w-8 h-8" />
      <% :quake2 -> %>
        <Icons.icon_game_quake2 class="w-8 h-8" />
      <% :wolfenstein -> %>
        <Icons.icon_game_wolfenstein class="w-8 h-8" />
      <% :bass -> %>
        <Icons.icon_game_bass class="w-8 h-8" />
      <% :dreamweb -> %>
        <Icons.icon_game_dreamweb class="w-8 h-8" />
    <% end %>
    """
  end
end
