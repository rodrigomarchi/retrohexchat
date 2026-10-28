defmodule RetroHexChatWeb.Components.UI.Chrome do
  @moduledoc """
  The bevel of a clickable control, in one place.

  Every button of the interface — the labelled `Button`, the square
  `ToolButton` — is drawn in one of two looks, and both read their classes
  from here so the two can never drift apart:

    * `raised/0` — the classic Win98 button, bevelled at rest and sunken while
      held down.
    * `flat/0` — the IE-style toolbar button: no chrome at rest, the bevel rises
      under the pointer and sinks while held down.
    * `pixel/0` and `pixel_secondary/0` — the Virtual Space's pixel-art
      buttons, wood and parchment. Their look lives in `features/space-ui.css`,
      inside a `.space-ui` page only.
    * `arcade/0` and `arcade_secondary/0` — the Retro Games' neon arcade buttons, inside an `.arcade-ui` stage only
      (`features/arcade-ui.css`).

  Plain strings and no dependencies: `Button`'s variant table reads them at
  compile time.
  """

  @spec raised() :: String.t()
  def raised, do: "bg-surface shadow-retro-raised active:shadow-retro-sunken"

  @spec flat() :: String.t()
  def flat,
    do: "bg-transparent shadow-none hover:shadow-retro-raised active:shadow-retro-sunken"

  @doc "The Virtual Space's wooden button (`.space-ui` only)."
  @spec pixel() :: String.t()
  def pixel, do: "space-pixel-button"

  @doc "The Virtual Space's parchment button, for the quieter choice (`.space-ui` only)."
  @spec pixel_secondary() :: String.t()
  def pixel_secondary, do: "space-pixel-button space-pixel-button--secondary"

  @doc "The Retro Games' neon arcade button, for the one thing to do (`.arcade-ui` only)."
  @spec arcade() :: String.t()
  def arcade, do: "arcade-button"

  @doc "The arcade's quieter button, for the other choices (`.arcade-ui` only)."
  @spec arcade_secondary() :: String.t()
  def arcade_secondary, do: "arcade-button arcade-button--secondary"

  @doc "The sunken look of a toggle that is on."
  @spec active() :: String.t()
  def active, do: "bg-hover-bg shadow-retro-sunken hover:shadow-retro-sunken"
end
