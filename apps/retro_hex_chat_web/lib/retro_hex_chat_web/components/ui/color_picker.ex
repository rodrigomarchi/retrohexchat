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
    {"White", "#ffffff"},
    {"Black", "#000000"},
    {"Navy", "#00007f"},
    {"Green", "#009300"},
    {"Red", "#ff0000"},
    {"Maroon", "#7f0000"},
    {"Purple", "#9c009c"},
    {"Orange", "#fc7f00"},
    {"Yellow", "#ffff00"},
    {"Lime", "#00fc00"},
    {"Teal", "#009393"},
    {"Cyan", "#00ffff"},
    {"Royal Blue", "#0000fc"},
    {"Magenta", "#ff00ff"},
    {"Gray", "#7f7f7f"},
    {"Silver", "#d2d2d2"}
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
          :for={{{{name, hex}, idx}} <- @colors}
          type="button"
          class={[
            "w-[18px] h-[18px] border cursor-pointer",
            if(@selected == idx,
              do: "border-black border-2",
              else: "border-gray-500"
            )
          ]}
          style={"background-color: #{hex};"}
          title={name}
          aria-label={"Color #{idx}: #{name}"}
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
  def irc_colors, do: @irc_colors
end
