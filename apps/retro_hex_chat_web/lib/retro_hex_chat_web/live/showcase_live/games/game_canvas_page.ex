defmodule RetroHexChatWeb.ShowcaseLive.Games.GameCanvasPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.GameCanvas
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Game Canvas", active_page: "game-canvas")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Game Canvas</h2>

      <.showcase_card
        title="As Host"
        description="The session creator sees '(host)' next to their own nickname."
      >
        <.game_canvas
          game_id="game-abc123"
          game_name="Tic-Tac-Toe"
          nickname="alice"
          peer_nick="bob"
          is_host={true}
        />
        <.code_example>
          &lt;.game_canvas
          game_id="game-abc123"
          game_name="Tic-Tac-Toe"
          nickname="alice"
          peer_nick="bob"
          is_host=&#123;true&#125;
          on_end_game="end_game"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="As Guest"
        description="The peer who joined the session — '(host)' appears next to the peer's nick."
      >
        <.game_canvas
          game_id="game-xyz789"
          game_name="Checkers"
          nickname="carol"
          peer_nick="dave"
          is_host={false}
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
