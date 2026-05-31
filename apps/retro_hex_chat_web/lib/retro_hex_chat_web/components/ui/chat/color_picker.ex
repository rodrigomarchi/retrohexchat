defmodule RetroHexChatWeb.Components.UI.ColorPicker do
  @moduledoc """
  Win98-style IRC color picker for the showcase design system.

  Renders a 4x4 grid of the 16 standard IRC colors with selection
  indicator and retro sunken border.

  ## Usage

      <.color_picker id="fg-color" selected={3} on_select="pick-color" />
  """
  use RetroHexChatWeb.Component

  @irc_colors [
    {:white, "#ffffff"},
    {:black, "#000000"},
    {:navy, "#00007f"},
    {:green, "#009300"},
    {:red, "#ff0000"},
    {:maroon, "#7f0000"},
    {:purple, "#9c009c"},
    {:orange, "#fc7f00"},
    {:yellow, "#ffff00"},
    {:lime, "#00fc00"},
    {:teal, "#009393"},
    {:cyan, "#00ffff"},
    {:royal_blue, "#0000fc"},
    {:magenta, "#ff00ff"},
    {:gray, "#7f7f7f"},
    {:silver, "#d2d2d2"}
  ]

  @doc """
  Renders a 4x4 grid of IRC color swatches.
  """
  attr :id, :string, required: true
  attr :selected, :integer, default: nil

  attr :on_select, :any,
    default: nil,
    doc: "Color select callback (receives phx-value-index and phx-value-picker)"

  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block

  @spec color_picker(map()) :: Phoenix.LiveView.Rendered.t()
  def color_picker(assigns) do
    assigns = assign(assigns, :colors, Enum.with_index(@irc_colors))

    ~H"""
    <div
      id={@id}
      class={
        classes([
          "inline-block shadow-retro-field bg-white p-retro-4",
          @class
        ])
      }
      {@rest}
    >
      <div class="grid grid-cols-4 gap-[2px]">
        <button
          :for={{{color, hex}, idx} <- @colors}
          type="button"
          class={[
            "w-[18px] h-[18px] border cursor-pointer",
            if(@selected == idx,
              do: "border-black border-2",
              else: "border-gray-500"
            )
          ]}
          style={"background-color: #{hex};"}
          title={color_name(color)}
          aria-label={
            dgettext("chat", "Color %{index}: %{name}", index: idx, name: color_name(color))
          }
          phx-click={@on_select}
          phx-value-index={idx}
          phx-value-picker={@id}
        />
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Returns the list of IRC colors as {name, hex} tuples."
  @spec irc_colors() :: [{String.t(), String.t()}]
  def irc_colors do
    Enum.map(@irc_colors, fn {color, hex} -> {color_name(color), hex} end)
  end

  defp color_name(:white), do: dgettext("chat", "White")
  defp color_name(:black), do: dgettext("chat", "Black")
  defp color_name(:navy), do: dgettext("chat", "Navy")
  defp color_name(:green), do: dgettext("chat", "Green")
  defp color_name(:red), do: dgettext("chat", "Red")
  defp color_name(:maroon), do: dgettext("chat", "Maroon")
  defp color_name(:purple), do: dgettext("chat", "Purple")
  defp color_name(:orange), do: dgettext("chat", "Orange")
  defp color_name(:yellow), do: dgettext("chat", "Yellow")
  defp color_name(:lime), do: dgettext("chat", "Lime")
  defp color_name(:teal), do: dgettext("chat", "Teal")
  defp color_name(:cyan), do: dgettext("chat", "Cyan")
  defp color_name(:royal_blue), do: dgettext("chat", "Royal Blue")
  defp color_name(:magenta), do: dgettext("chat", "Magenta")
  defp color_name(:gray), do: dgettext("chat", "Gray")
  defp color_name(:silver), do: dgettext("chat", "Silver")
end
