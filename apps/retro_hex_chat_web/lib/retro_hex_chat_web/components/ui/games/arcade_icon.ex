defmodule RetroHexChatWeb.Components.UI.Games.ArcadeIcon do
  @moduledoc """
  The Retro Games' stage's icons: neon pixel art in the arcade kit's palette,
  for the controls of a game's stage and nothing else.

  The rest of the interface draws its icons as SVG through `RetroHexChatWeb.Icons`;
  the stage is drawn in the arcade's pixel art, and its buttons carry its own
  icons, as the space's carry the space's (`Space.PixelIcon`). The art is a
  PixelLab generation packed into `/images/arcade/ui/icons.webp` by
  `virtual.space/tools/author_ui.py --kit arcade`, which also writes one
  `.arcade-icon--<name>` rule per icon (`features/arcade-ui-kit.generated.css`).
  Each icon renders 1:1, at the size it was drawn, so it takes no size.

  Decorative: the control it sits in carries the accessible name.
  """
  use RetroHexChatWeb.Component

  @names ~w(play again stop partner link fullscreen_enter fullscreen_exit pause)a

  attr :name, :atom, required: true, values: @names
  attr :class, :any, default: nil
  attr :rest, :global

  @spec arcade_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def arcade_icon(assigns) do
    ~H"""
    <span class={classes(["arcade-icon", icon_class(@name), @class])} aria-hidden="true" {@rest}></span>
    """
  end

  @doc "Every icon the kit draws."
  @spec names() :: [atom()]
  def names, do: @names

  # One literal class per icon, so the CSS lint sees every rule in use.
  defp icon_class(:play), do: "arcade-icon--play"
  defp icon_class(:again), do: "arcade-icon--again"
  defp icon_class(:stop), do: "arcade-icon--stop"
  defp icon_class(:partner), do: "arcade-icon--partner"
  defp icon_class(:link), do: "arcade-icon--link"
  defp icon_class(:fullscreen_enter), do: "arcade-icon--fullscreen-enter"
  defp icon_class(:fullscreen_exit), do: "arcade-icon--fullscreen-exit"
  defp icon_class(:pause), do: "arcade-icon--pause"
end
