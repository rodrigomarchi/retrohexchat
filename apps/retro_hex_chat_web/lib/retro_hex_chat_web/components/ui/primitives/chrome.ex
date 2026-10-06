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

  Plain strings and no dependencies: `Button`'s variant table reads them at
  compile time.
  """

  @spec raised() :: String.t()
  def raised, do: "bg-surface shadow-retro-raised active:shadow-retro-sunken"

  @spec flat() :: String.t()
  def flat,
    do: "bg-transparent shadow-none hover:shadow-retro-raised active:shadow-retro-sunken"

  @doc "The sunken look of a toggle that is on."
  @spec active() :: String.t()
  def active, do: "bg-hover-bg shadow-retro-sunken hover:shadow-retro-sunken"
end
