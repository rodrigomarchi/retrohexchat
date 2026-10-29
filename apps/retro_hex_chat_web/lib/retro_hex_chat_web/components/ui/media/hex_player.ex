defmodule RetroHexChatWeb.Components.UI.HexPlayer do
  @moduledoc """
  The player of a sound or a video, built from the same kit as Hex Radio
  (`hex-device.css`): graphite metal, an amber display with the title, the
  time and the position, and teal keys. One look for everything the platform
  plays, so no tile falls back to the browser's own controls.

    * a sound — a file or a voice message — draws a small spectrum beside its
      position, real when the file shares its samples with the page
    * a video plays on a screen above the display, and has a key to fill the
      screen

  Everything moves in the browser (`lib/hex_player/`, through `HexPlayerHook`):
  the element is the hook's from the first render on (`phx-update="ignore"`),
  so a patch of the line around it — a reaction, an edit — never stops it or
  rewinds it. Its `id` must be unique on the page: the same message can be
  drawn in the conversation and in its thread at once.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :kind, :atom, values: [:audio, :video], required: true
  attr :src, :string, required: true
  attr :title, :string, required: true
  attr :length_ms, :integer, default: nil, doc: "the length, when the server knows it"
  attr :testid, :string, default: nil, doc: "the media element's test id"
  attr :length_testid, :string, default: nil, doc: "the length's test id"
  slot :inner_block, doc: "a line under the keys: what the file is and where it opens"

  @spec hex_player(map()) :: Phoenix.LiveView.Rendered.t()
  def hex_player(assigns) do
    ~H"""
    <div
      id={@id}
      class={["hex-device hex-player", "hex-player--#{@kind}"]}
      phx-hook="HexPlayerHook"
      phx-update="ignore"
      data-player-state="stopped"
      data-player-length={@length_ms}
      data-testid="hex-player"
    >
      <div :if={@kind == :video} class="hex-player__screen">
        <video
          src={@src}
          preload="metadata"
          playsinline
          data-player-media
          data-testid={@testid}
        ></video>
      </div>
      <audio
        :if={@kind == :audio}
        src={@src}
        preload="metadata"
        crossorigin="anonymous"
        data-player-media
        data-testid={@testid}
      ></audio>
      <div class="hex-device__lcd hex-player__lcd">
        <div class="hex-player__head">
          <span class="hex-player__glyph" aria-hidden="true"></span>
          <span class="hex-player__title">{@title}</span>
          <span class="hex-player__time" data-testid="hex-player-time">
            <span data-player-field="elapsed">0:00</span>/<span
              data-player-field="length"
              data-testid={@length_testid}
            >{length_text(@length_ms)}</span>
          </span>
        </div>
        <div class="hex-player__track">
          <canvas
            :if={@kind == :audio}
            class="hex-player__scope"
            data-player-scope
            aria-hidden="true"
          ></canvas>
          <input
            type="range"
            min="0"
            max="1000"
            value="0"
            class="hex-device__slider hex-player__seek"
            aria-label={dgettext("ui", "Position")}
            data-player-seek
            data-testid="hex-player-seek"
          />
        </div>
      </div>
      <div class="hex-player__keys">
        <button
          type="button"
          class="hex-device__key hex-player__key hex-player__key--play"
          aria-label={dpgettext("ui", "radio", "Play")}
          title={dpgettext("ui", "radio", "Play")}
          data-player-command="play"
          data-testid="hex-player-play"
        >
          <Icons.icon_radio_play class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="hex-device__key hex-player__key hex-player__key--pause"
          aria-label={dgettext("ui", "Pause")}
          title={dgettext("ui", "Pause")}
          data-player-command="pause"
          data-testid="hex-player-pause"
        >
          <Icons.icon_radio_pause class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="hex-device__key hex-player__key"
          aria-label={dgettext("ui", "Stop")}
          title={dgettext("ui", "Stop")}
          data-player-command="stop"
          data-testid="hex-player-stop"
        >
          <Icons.icon_radio_stop class="h-4 w-4" />
        </button>
        <span class="hex-player__spacer"></span>
        <button
          type="button"
          class="hex-device__key hex-device__key--icon hex-player__key"
          aria-pressed="false"
          aria-label={dgettext("ui", "Mute")}
          title={dgettext("ui", "Mute")}
          data-player-command="mute"
          data-testid="hex-player-mute"
        >
          <Icons.icon_radio_volume class="h-4 w-4" />
        </button>
        <button
          :if={@kind == :video}
          type="button"
          class="hex-device__key hex-player__key"
          aria-label={dgettext("ui", "Full screen")}
          title={dgettext("ui", "Full screen")}
          data-player-command="fullscreen"
          data-testid="hex-player-fullscreen"
        >
          <Icons.icon_fullscreen_enter class="h-4 w-4" />
        </button>
      </div>
      <div :if={@inner_block != []} class="hex-player__foot">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp length_text(ms) when is_integer(ms) and ms > 0, do: Format.clock_ms(ms)
  defp length_text(_unknown), do: "--:--"
end
