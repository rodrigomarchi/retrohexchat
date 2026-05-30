defmodule RetroHexChatWeb.Components.UI.Select do
  @moduledoc """
  Implement of select components from https://ui.shadcn.com/docs/components/select

  ## Examples:

      <form>
         <.select default="banana" id="fruit-select">
            <.select_trigger class="w-[180px]">
              <.select_value placeholder=".select a fruit"/>
            </.select_trigger>
            <.select_content>
              <.select_group>
                <.select_label>Fruits</.select_label>
                <.select_item name="fruit" value="apple">Apple</.select_item>
                <.select_item name="fruit" value="banana">Banana</.select_item>
                <.select_item name="fruit" value="blueberry">Blueberry</.select_item>
                <.select_separator />
                <.select_item  name="fruit" disabled value="grapes">Grapes</.select_item>
                <.select_item  name="fruit" value="pineapple">Pineapple</.select_item>
              </.select_group>
        </.select_content>
          </.select>

        <.button type="submit">Submit</.button>
      </form>
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc """
  Ready to use select component with all required parts.
  """

  attr :id, :string, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: nil, doc: "The value of the select"
  attr :"default-value", :any, default: nil, doc: "The default value of the select"

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :label, :string,
    default: nil,
    doc: "The display label of the select value. If not provided, the value will be used."

  attr :placeholder, :string, default: nil, doc: "The placeholder text when no value is selected."

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def select(assigns) do
    assigns = prepare_assign(assigns)

    assigns =
      assign(assigns, :builder, %{
        id: assigns.id,
        name: assigns.name,
        value: assigns.value,
        label: assigns.label,
        placeholder: assigns.placeholder
      })

    ~H"""
    <div
      id={@id}
      class={classes(["relative group", @class])}
      data-state="closed"
      {@rest}
      x-hide-select={hide_select(@id)}
      x-show-select={show_select(@id)}
      x-toggle-select={toggle_select(@id)}
      phx-click-away={JS.exec("x-hide-select")}
    >
      {render_slot(@inner_block, @builder)}
    </div>
    """
  end

  attr :builder, :map, required: true, doc: "The builder of the select component"
  attr :class, :string, default: nil
  attr :rest, :global

  def select_trigger(assigns) do
    ~H"""
    <button
      type="button"
      class={
        classes([
          "flex h-10 w-full items-center justify-between border-none shadow-retro-field bg-white px-3 py-2 text-sm placeholder:text-muted-foreground focus:outline focus:outline-2 focus:outline-black disabled:cursor-not-allowed disabled:opacity-50 [&>span]:line-clamp-1",
          @class
        ])
      }
      phx-click={toggle_select(@builder.id)}
      {@rest}
    >
      <span
        class="select-value pointer-events-none before:content-[attr(data-content)]"
        data-content={@builder.label || @builder.value || @builder.placeholder}
      >
      </span>
      <Icons.icon_chevron_down class="h-4 w-4 opacity-50" />
    </button>
    """
  end

  attr :builder, :map, required: true, doc: "The builder of the select component"

  attr :class, :string, default: nil
  attr :side, :string, values: ~w(top bottom), default: "bottom"
  slot :inner_block, required: true

  attr :rest, :global

  def select_content(assigns) do
    position_class =
      case assigns.side do
        "top" -> "bottom-full mb-1"
        "bottom" -> "top-full mt-1"
      end

    assigns =
      assigns
      |> assign(:position_class, position_class)
      |> assign(:id, assigns.builder.id <> "-content")

    ~H"""
    <.focus_wrap
      id={@id}
      data-side={@side}
      class={
        classes([
          "select-content absolute hidden",
          "z-50 left-0 w-full max-h-96 overflow-hidden border-none shadow-retro-window bg-surface p-[3px]",
          @position_class,
          @class
        ])
      }
      {@rest}
    >
      <div class="shadow-retro-field bg-white p-[2px]">
        {render_slot(@inner_block)}
      </div>
    </.focus_wrap>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def select_group(assigns) do
    ~H"""
    <div role="group" class={classes([@class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def select_label(assigns) do
    ~H"""
    <div class={classes(["px-3 py-1 text-xs font-bold select-none", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :builder, :map, required: true, doc: "The builder of the select component"

  attr :value, :string, required: true
  attr :label, :string, default: nil
  attr :on_select, :any, default: nil
  attr :on_select_value, :map, default: %{}
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  slot :inner_block, required: true

  attr :rest, :global

  def select_item(assigns) do
    assigns = assign(assigns, :label, assigns.label || assigns.value)
    assigns = assign(assigns, :input_id, option_input_id(assigns.builder.id, assigns.value))

    ~H"""
    <label
      role="option"
      class={
        classes([
          "group/item",
          "relative flex w-full cursor-default select-none items-center py-1 pl-6 pr-2 text-sm outline-none hover:bg-primary hover:text-white data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
          @class
        ])
      }
      {%{"data-disabled": @disabled}}
      phx-click={select_item_push(@builder.id, @on_select, @on_select_value)}
      {@rest}
    >
      <input
        id={@input_id}
        type="radio"
        class="peer w-0 opacity-0"
        name={@builder.name}
        value={@value}
        checked={@builder.value == @value}
        disabled={@disabled}
        phx-click={JS.exec("x-hide-select", to: "##{@builder.id}")}
        phx-key="Escape"
        phx-keydown={JS.exec("x-hide-select", to: "##{@builder.id}")}
      />
      <span class="hidden peer-checked:inline-flex absolute left-1 w-4 h-4 items-center justify-center">
        <Icons.icon_check_thin class="h-3.5 w-3.5" />
      </span>
      <span class="z-0">{@label}</span>
    </label>
    """
  end

  def select_separator(assigns) do
    ~H"""
    <div role="separator" class={classes(["border-t border-separator my-[2px]"])} />
    """
  end

  defp hide_select(id) do
    %JS{}
    |> JS.pop_focus()
    |> JS.add_class("hidden",
      transition: "ease-out",
      to: "##{id}[data-state=open] .select-content",
      time: 150
    )
    |> JS.set_attribute({"data-state", "closed"}, to: "##{id}")
  end

  # show select and focus first selected item or first item if no selected item
  defp show_select(id) do
    %JS{}
    # show if closed
    |> JS.focus_first(to: "##{id}[data-state=closed] .select-content")
    |> JS.set_attribute({"data-state", "open"}, to: "##{id}")
    |> JS.focus_first(to: "##{id}[data-state=open] .select-content")
    |> JS.focus_first(to: "##{id}[data-state=open] .select-content label:has(input:checked)")
  end

  # show or hide select
  defp toggle_select(id) do
    %JS{}
    |> JS.add_class("hidden",
      transition: "ease-out",
      to: "##{id}[data-state=open] .select-content",
      time: 150
    )
    # show if closed
    |> JS.remove_class("hidden", to: "##{id}[data-state=closed] .select-content")
    |> JS.toggle_attribute({"data-state", "open", "closed"}, to: "##{id}")
    |> JS.focus_first(to: "##{id}[data-state=open] .select-content")
    |> JS.focus_first(to: "##{id}[data-state=open] .select-content label:has(input:checked)")
  end

  defp select_item_push(_root_id, nil, _on_select_value), do: nil

  defp select_item_push(root_id, on_select, on_select_value) do
    JS.push(on_select, value: on_select_value)
    |> JS.exec("x-hide-select", to: "##{root_id}")
  end

  defp option_input_id(root_id, value) do
    encoded_value =
      value
      |> to_string()
      |> Base.url_encode64(padding: false)

    "#{root_id}-option-#{encoded_value}"
  end
end
