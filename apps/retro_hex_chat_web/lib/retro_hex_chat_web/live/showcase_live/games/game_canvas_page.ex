defmodule RetroHexChatWeb.ShowcaseLive.Games.GameCanvasPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.GameCanvas
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: dgettext("showcase", "Game Canvas"), active_page: "game-canvas")}
  end

  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Game Canvas")}</h2>

      <.showcase_card
        title={dgettext("showcase", "As Host")}
        description="The session creator sees '(host)' next to their own nickname."
      >
        <.game_canvas
          game_id="game-abc123"
          game_name="Tic-Tac-Toe"
          nickname="alice"
          peer_nick="bob"
          role={:creator}
          on_start_media="start_game_media"
          on_set_media_layout="set_game_media_layout"
        />
        <.code_example>
          &lt;.game_canvas
          game_id="game-abc123"
          game_name="Tic-Tac-Toe"
          nickname="alice"
          peer_nick="bob"
          role=&#123;:creator&#125;
          on_end_game="end_game"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "As Guest")}
        description="The peer who joined the session — '(host)' appears next to the peer's nick."
      >
        <.game_canvas
          game_id="game-xyz789"
          game_name="Checkers"
          nickname="carol"
          peer_nick="dave"
          role={:peer}
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Voice Active")}
        description="The compact in-game voice dock keeps the canvas primary while exposing call state."
      >
        <.game_canvas
          game_id="game-voice-001"
          game_name="Hex Pong"
          nickname="maya"
          peer_nick="niko"
          role={:creator}
          game_call={
            %{
              status: "audio_active",
              type: "audio",
              duration: "00:03:28",
              peer_muted: true,
              peer_camera_off: false,
              local_joined: true
            }
          }
          local_muted={false}
          local_camera_off={false}
          on_start_media="start_game_media"
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Video Side By Side")}
        description="The side-by-side layout gives both players equal presence during a match."
      >
        <.game_canvas
          game_id="game-video-001"
          game_name="Hex Pong"
          nickname="sara"
          peer_nick="tom"
          role={:peer}
          game_call={
            %{
              status: "video_active",
              type: "video",
              duration: "00:08:11",
              peer_muted: false,
              peer_camera_off: false,
              local_joined: true
            }
          }
          game_call_layout="side_by_side"
          local_muted={true}
          local_camera_off={false}
          on_set_media_layout="set_game_media_layout"
        />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Video Maximized")}
        description="The maximized layout prioritizes remote video while preserving the local preview and game controls."
      >
        <.game_canvas
          game_id="game-video-002"
          game_name="Checkers"
          nickname="ivy"
          peer_nick="zane"
          role={:creator}
          game_call={
            %{
              status: "video_active",
              type: "video",
              duration: "00:12:44",
              peer_muted: false,
              peer_camera_off: true,
              local_joined: false
            }
          }
          game_call_layout="maximized"
          local_muted={false}
          local_camera_off={true}
          media_error={dgettext("showcase", "Camera permission is required to join with video.")}
          on_start_media="start_game_media"
          on_set_media_layout="set_game_media_layout"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
