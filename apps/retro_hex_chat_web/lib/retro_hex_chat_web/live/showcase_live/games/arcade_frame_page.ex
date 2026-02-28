defmodule RetroHexChatWeb.ShowcaseLive.Games.ArcadeFramePage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ArcadeFrame
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Arcade Frame", active_page: "arcade-frame")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Arcade Frame</h2>

      <.showcase_card
        title="Default"
        description="Arcade game iframe container with game name, player nickname, and Leave Game button."
      >
        <.arcade_frame
          game_name="Space Invaders"
          game_url="/arcade/space-invaders"
          nickname="alice"
          on_close="leave_game"
        />
        <.code_example>
          &lt;.arcade_frame
          game_name="Space Invaders"
          game_url="/arcade/space-invaders"
          nickname="alice"
          on_close="leave_game"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Different Game"
        description="Same component with a different game and player."
      >
        <.arcade_frame
          game_name="Pong"
          game_url="/arcade/pong"
          nickname="bob"
          on_close="leave_game"
        />
      </.showcase_card>

      <.showcase_card
        title="Long Game Name"
        description="Title bar truncates long game names gracefully."
      >
        <.arcade_frame
          game_name="The Ultimate Retro Championship Edition 2000"
          game_url="/arcade/championship"
          nickname="carol"
          on_close="leave_game"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
