defmodule RetroHexChatWeb.ShowcaseLive.GameCardsPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

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

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Game Cards</h2>

      <.showcase_card
        title="Arcade Grid"
        description="Responsive grid of selectable game cards with icons and descriptions."
      >
        <.window>
          <.window_title_bar title="Arcade — Troll" controls={[:close]} />
          <.window_body>
            <p class="text-sm font-bold mb-1">Retro Arcade</p>
            <p class="text-xs text-muted-foreground mb-3">
              Classic games running in your browser via WebAssembly
            </p>
            <p class="text-sm font-bold mb-2">Choose a game:</p>
            <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-2">
              <button
                :for={
                  {name, desc, icon} <- [
                    {"DOOM", "Episode 1 — The Original", :doom},
                    {"Freedoom Phase 1", "36 levels of open-source doom", :freedoom1},
                    {"Freedoom Phase 2", "32 levels — Doom II compatible", :freedoom2},
                    {"FreeDM", "Deathmatch arena — open source", :freedm},
                    {"Chex Quest", "The cereal box classic", :chex},
                    {"HacX", "Cyberpunk total conversion", :hacx},
                    {"REKKR", "Viking-themed standalone", :rekkr},
                    {"LibreQuake", "Open-source Quake replacement", :librequake},
                    {"Quake II", "Unit 1 — The Demo", :quake2},
                    {"Wolfenstein 3D", "Episode 1 — Shareware Classic", :wolfenstein},
                    {"Beneath a Steel Sky", "Cyberpunk point & click", :bass},
                    {"Dreamweb", "Dark cyberpunk adventure (1994)", :dreamweb}
                  ]
                }
                type="button"
                phx-click="select-game"
                phx-value-game={name}
                class={[
                  "shadow-retro-field bg-white p-2 text-center cursor-pointer",
                  "hover:bg-hover-bg active:shadow-retro-sunken",
                  @selected == name && "shadow-retro-sunken bg-highlight-bg"
                ]}
              >
                <div class="w-[32px] h-[32px] mx-auto mb-1">
                  <.game_icon name={icon} />
                </div>
                <p class="text-xs font-bold truncate">{name}</p>
                <p class="text-[10px] text-muted-foreground truncate">{desc}</p>
              </button>
            </div>
            <div class="mt-3">
              <button class="shadow-retro-raised bg-surface px-4 py-1 text-sm active:shadow-retro-sunken">
                Leave
              </button>
            </div>
          </.window_body>
        </.window>
        <.code_example>
          &lt;button
          phx-click="select-game"
          phx-value-game=&#123;name&#125;
          class="shadow-retro-field bg-white p-2 text-center
          hover:bg-hover-bg active:shadow-retro-sunken"
          &gt;
          &lt;div class="w-[32px] h-[32px] mx-auto"&gt;icon&lt;/div&gt;
          &lt;p class="text-xs font-bold"&gt;DOOM&lt;/p&gt;
          &lt;p class="text-[10px]"&gt;Episode 1&lt;/p&gt;
          &lt;/button&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Selected State"
        description="Click a game above to see the selected state change."
      >
        <p class="text-sm">
          Currently selected: <span class="font-bold">{@selected || "none"}</span>
        </p>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
