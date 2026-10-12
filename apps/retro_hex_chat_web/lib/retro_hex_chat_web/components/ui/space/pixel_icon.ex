defmodule RetroHexChatWeb.Components.UI.Space.PixelIcon do
  @moduledoc """
  The Virtual Space's icons: pixel art drawn in the space's own wood-and-gold
  style, for the controls of a space and nothing else.

  The rest of the interface draws its icons as SVG through `RetroHexChatWeb.Icons`;
  a space is a pixel-art world, and its controls are drawn the way the world is.
  The art is a PixelLab generation packed into `/images/space/ui/icons.webp` by
  `virtual.space/tools/author_ui.py`, which also writes one `.space-icon--<name>`
  rule per icon (`features/space-ui-kit.generated.css`). Each icon renders 1:1 —
  one art pixel per CSS pixel — at the size it was drawn, so it takes no size.

  Decorative: the control it sits in carries the accessible name.
  """
  use RetroHexChatWeb.Component

  @names ~w(ok cancel send fullscreen_enter fullscreen_exit use attack turn remove space
            pad_up pad_down pad_left pad_right loading
            win_minimize win_maximize win_restore win_close)a

  attr :name, :atom, required: true, values: @names
  attr :class, :any, default: nil
  attr :rest, :global

  @spec pixel_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def pixel_icon(assigns) do
    ~H"""
    <span class={classes(["space-icon", icon_class(@name), @class])} aria-hidden="true" {@rest}>
    </span>
    """
  end

  @doc "Every icon the kit draws."
  @spec names() :: [atom()]
  def names, do: @names

  # One literal class per icon, so the CSS lint sees every rule in use.
  defp icon_class(:ok), do: "space-icon--ok"
  defp icon_class(:cancel), do: "space-icon--cancel"
  defp icon_class(:send), do: "space-icon--send"
  defp icon_class(:fullscreen_enter), do: "space-icon--fullscreen-enter"
  defp icon_class(:fullscreen_exit), do: "space-icon--fullscreen-exit"
  defp icon_class(:use), do: "space-icon--use"
  defp icon_class(:attack), do: "space-icon--attack"
  defp icon_class(:turn), do: "space-icon--turn"
  defp icon_class(:remove), do: "space-icon--remove"
  defp icon_class(:space), do: "space-icon--space"
  defp icon_class(:pad_up), do: "space-icon--pad-up"
  defp icon_class(:pad_down), do: "space-icon--pad-down"
  defp icon_class(:pad_left), do: "space-icon--pad-left"
  defp icon_class(:pad_right), do: "space-icon--pad-right"
  defp icon_class(:loading), do: "space-icon--loading"
  defp icon_class(:win_minimize), do: "space-icon--win-minimize"
  defp icon_class(:win_maximize), do: "space-icon--win-maximize"
  defp icon_class(:win_restore), do: "space-icon--win-restore"
  defp icon_class(:win_close), do: "space-icon--win-close"
end
