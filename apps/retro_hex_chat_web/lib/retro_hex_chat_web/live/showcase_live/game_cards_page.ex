defmodule RetroHexChatWeb.ShowcaseLive.GameCardsPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Game Cards", active_page: "game-cards", selected: nil)}
  end

  @impl true
  def handle_event("select-game", %{"game" => game}, socket) do
    {:noreply, assign(socket, selected: game)}
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
                  {name, desc} <- [
                    {"DOOM", "Episode 1 — The Original"},
                    {"Freedoom Phase 1", "36 levels of open-source doom"},
                    {"Freedoom Phase 2", "32 levels — Doom II compatible"},
                    {"FreeDM", "Deathmatch arena — open source"},
                    {"Chex Quest", "The cereal box classic"},
                    {"HacX", "Cyberpunk total conversion"},
                    {"REKKR", "Viking-themed standalone"},
                    {"LibreQuake", "Open-source Quake replacement"},
                    {"Quake II", "Unit 1 — The Demo"},
                    {"Wolfenstein 3D", "Episode 1 — Shareware Classic"},
                    {"Beneath a Steel Sky", "Cyberpunk point & click"},
                    {"Dreamweb", "Dark cyberpunk adventure (1994)"}
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
                <div class="w-[32px] h-[32px] mx-auto mb-1 bg-gray-200 shadow-retro-field flex items-center justify-center">
                  <span class="text-xs font-mono text-gray-500">ico</span>
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
