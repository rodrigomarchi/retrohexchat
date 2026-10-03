defmodule RetroHexChatWeb.Components.UI.Input do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Displays a form input field or a component that looks like an input field.

  ## Examples

      <.input type="text" placeholder="Enter your name" />
      <.input type="email" placeholder="Enter your email" />
      <.input type="password" placeholder="Enter your password" />
  """
  attr :id, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(date datetime-local email file hidden month number password tel text time url week)

  attr :"default-value", :any

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  @spec input(map()) :: Phoenix.LiveView.Rendered.t()
  def input(assigns) do
    assigns = prepare_assign(assigns)

    rest =
      Map.merge(assigns.rest, Map.take(assigns, [:id, :name, :value, :type]))

    assigns = assign(assigns, :rest, rest)

    ~H"""
    <.updown :if={@type == "number"} disabled={@rest[:disabled]}>
      <.text_field class={@class} rest={@rest} />
    </.updown>
    <.text_field :if={@type != "number"} class={@class} rest={@rest} />
    """
  end

  attr :class, :any, default: nil
  attr :rest, :map, required: true

  defp text_field(assigns) do
    ~H"""
    <input
      class={
        classes([
          "flex h-10 w-full border-none shadow-retro-field bg-white px-3 py-2 text-sm file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground disabled:cursor-not-allowed",
          @class
        ])
      }
      {@rest}
    />
    """
  end

  @doc """
  Win98 up-down control: two small arrow buttons attached to the right edge of
  the number field it wraps. A press steps the field and fires `input` and
  `change`, so a `phx-change` form hears it as if the value had been typed;
  holding it repeats. The buttons are not tab stops — the arrow keys already
  step a focused number field.

  `<.input type="number">` wraps itself; a hand-written number input is wrapped
  explicitly:

      <.updown disabled={@locked}>
        <input type="number" name="limit" disabled={@locked} />
      </.updown>
  """
  attr :disabled, :any, default: false, doc: "disables both arrows; pass the field's own flag"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  @spec updown(map()) :: Phoenix.LiveView.Rendered.t()
  def updown(assigns) do
    ~H"""
    <span class={classes(["retro-updown", @class])} data-updown>
      {render_slot(@inner_block)}
      <span class="retro-updown__buttons" aria-hidden="true">
        <button
          type="button"
          tabindex="-1"
          class="retro-updown__button retro-updown__button--up"
          data-updown-step="up"
          disabled={@disabled not in [nil, false, "false"]}
        />
        <button
          type="button"
          tabindex="-1"
          class="retro-updown__button retro-updown__button--down"
          data-updown-step="down"
          disabled={@disabled not in [nil, false, "false"]}
        />
      </span>
    </span>
    """
  end
end
