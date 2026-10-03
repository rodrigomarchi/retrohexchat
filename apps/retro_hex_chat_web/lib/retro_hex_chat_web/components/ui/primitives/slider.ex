defmodule RetroHexChatWeb.Components.UI.Slider do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Renders a range input, drawn as the Win98 trackbar by the global
  `input[type="range"]` rules.

  ## Example


      <.slider class="w-[60%]" id="slider-single-default-slider" max={50} min={10} step={5} value={20}/>

  """
  attr :id, :string, required: true
  attr :class, :string, default: nil
  attr :name, :string, default: nil
  attr :value, :integer, default: 0, doc: ""
  attr :"default-value", :integer

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :min, :integer, default: 0
  attr :max, :integer, default: 100
  attr :step, :integer, default: 1
  attr :rest, :global

  @spec slider(map()) :: Phoenix.LiveView.Rendered.t()
  def slider(assigns) do
    assigns =
      prepare_assign(assigns)

    assigns =
      assigns
      |> Map.put(:value, normalize_integer(assigns[:value] || 0))
      |> Map.put(:min, normalize_integer(assigns[:min] || 0))
      |> Map.put(:max, normalize_integer(assigns[:max]))
      |> Map.put(:step, normalize_integer(assigns[:step]))

    ~H"""
    <input
      type="range"
      class={classes(["w-full", @class])}
      {%{min: @min, max: @max, value: @value, step: @step, id: @id, name: @name}}
      {@rest}
    />
    """
  end
end
