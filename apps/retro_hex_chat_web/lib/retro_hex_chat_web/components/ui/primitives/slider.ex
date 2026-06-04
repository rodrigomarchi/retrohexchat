defmodule RetroHexChatWeb.Components.UI.Slider do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Render Slider range input

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
    <div
      class={classes(["retro-slider relative w-full", @class])}
      style={"--retro-slider-val: #{(@value - @min)/(@max - @min) * 100}"}
    >
      <span class={["relative flex w-full touch-none select-none items-center"]}>
        <span
          data-orientation="horizontal"
          class="relative h-2 w-full grow overflow-hidden shadow-retro-sunken bg-surface"
        >
          <span
            data-orientation="horizontal"
            class="absolute left-0 h-full bg-primary w-[calc(var(--retro-slider-val)*1%)]"
          >
          </span>
        </span>
        <span class="absolute left-[calc(var(--retro-slider-val)*1%)] -translate-x-1/2">
          <span
            role="slider"
            aria-valuemin={@min}
            aria-valuemax={@max}
            aria-orientation="horizontal"
            data-orientation="horizontal"
            tabindex="0"
            class="block h-5 w-5 shadow-retro-raised bg-surface focus-visible:outline focus-visible:outline-2 focus-visible:outline-black disabled:pointer-events-none disabled:opacity-50"
          >
          </span>
        </span>
      </span>
      <input
        type="range"
        class="absolute top-0 -left-2 z-1 w-[calc(100%+20px)] appearance-none cursor-pointer opacity-0"
        phx-update="ignore"
        oninput={"this.parentNode.style.setProperty('--retro-slider-val', (this.value - #{@min})/#{@max - @min}*100); return true;"}
        {%{min: @min, max: @max, value: @value, step: @step, id: @id, name: @name}}
        {@rest}
      />
    </div>
    """
  end
end
