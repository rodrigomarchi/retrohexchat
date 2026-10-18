defmodule RetroHexChatWeb.Components.UI.IconWell do
  @moduledoc """
  The pressed-in square a panel's picture sits in: the game in a match card,
  the terminal in a trusted device, the camera on a notice.

  Three sizes, matched to what is drawn in them — `sm` (32 px) holds a 16–20 px
  icon beside one line of title, `md` (40 px) a 24 px icon beside two, `lg`
  (48 px) the headline picture of a card.

  ## Usage

      <.icon_well size="md"><Icons.icon_joystick class="h-6 w-6" /></.icon_well>
  """
  use RetroHexChatWeb.Component

  attr :size, :string, values: ~w(sm md lg), default: "sm"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders an icon in a sunken square."
  @spec icon_well(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_well(assigns) do
    ~H"""
    <span
      class={
        classes([
          "inline-flex shrink-0 items-center justify-center bg-surface shadow-retro-sunken",
          size_class(@size),
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp size_class("lg"), do: "h-12 w-12"
  defp size_class("md"), do: "h-10 w-10"
  defp size_class(_sm), do: "h-8 w-8"
end
