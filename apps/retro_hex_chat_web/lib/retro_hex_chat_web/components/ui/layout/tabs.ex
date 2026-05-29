defmodule RetroHexChatWeb.Components.UI.Tabs do
  @moduledoc """
  Win98-style tabs component for the showcase design system.
  Visually matches the platform's retro dialog tabs.
  """
  use RetroHexChatWeb.Component

  attr :id, :string, required: true, doc: "id for root tabs tag"
  attr :default, :string, default: nil, doc: "default tab value"
  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def tabs(assigns) do
    assigns = assign(assigns, :builder, %{default: assigns.default, id: assigns.id})

    ~H"""
    <div class={@class} id={@id} {@rest} phx-mounted={show_tab(@id, @default)}>
      {render_slot(@inner_block, @builder)}
    </div>
    """
  end

  @doc """
  Tab bar container — holds tab triggers in a flex row.
  Bottom border acts as the separator that active tabs "break through".
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def tabs_list(assigns) do
    ~H"""
    <div
      class={
        classes([
          "relative flex items-end gap-0 px-retro-4 pt-retro-6 bg-surface border-b border-border",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Individual tab trigger — Win98-style with mandatory icon and real borders.
  Active tab: border-bottom matches surface color, visually merging with panel.
  Inactive tab: slightly shorter, gray background.
  """
  attr :builder, :map, required: true, doc: "builder instance of tabs"
  attr :value, :string, required: true, doc: "target value of tab content"
  attr :class, :string, default: nil
  slot :icon, required: true, doc: "16×16 icon for the tab"
  slot :inner_block, required: true
  attr :rest, :global

  def tabs_trigger(assigns) do
    {external_click, rest} = pop_phx_click(assigns.rest)

    assigns =
      assigns
      |> assign(:rest, rest)
      |> assign(:click, tab_click(assigns.builder.id, assigns.value, external_click))

    ~H"""
    <button
      class={
        classes([
          "tabs-trigger",
          "relative inline-flex items-center gap-retro-4",
          "border border-border border-b-border",
          "px-retro-10 py-retro-2 mr-[1px]",
          "text-xs whitespace-nowrap",
          "bg-gray-300 text-foreground",
          "top-[1px]",
          "data-[state=active]:bg-surface data-[state=active]:border-b-surface data-[state=active]:font-bold data-[state=active]:z-10 data-[state=active]:top-0 data-[state=active]:pt-retro-4",
          "focus-visible:outline focus-visible:outline-2 focus-visible:outline-black",
          "disabled:pointer-events-none disabled:opacity-50",
          @class
        ])
      }
      data-target={@value}
      {@rest}
      phx-click={@click}
    >
      <span class="w-[16px] h-[16px] shrink-0 inline-flex items-center justify-center">
        {render_slot(@icon)}
      </span>
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Tab content panel — Win98-style with 3D window border, connects to active tab above.
  """
  attr :value, :string, required: true, doc: "unique for tab content"

  attr :builder, :map,
    default: nil,
    doc: "builder from parent tabs (used to set initial visibility)"

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def tabs_content(assigns) do
    default = assigns[:builder] && assigns.builder[:default]
    initially_hidden = default != nil && assigns.value != default

    assigns = assign(assigns, :initially_hidden, initially_hidden)

    ~H"""
    <div
      class={
        classes([
          "tabs-content",
          "border border-border bg-surface p-retro-8",
          "border-t-0",
          "focus-visible:outline focus-visible:outline-2 focus-visible:outline-black",
          @initially_hidden && "hidden",
          @class
        ])
      }
      value={@value}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # Set selected tab to active
  # show appropriate tab content (uses hidden class instead of inline style
  # so initial server-rendered state survives LiveView re-renders)
  defp show_tab(root, value) do
    %JS{}
    |> JS.set_attribute({"data-state", ""}, to: "##{root} .tabs-trigger[data-state=active]")
    |> JS.set_attribute({"data-state", "active"},
      to: "##{root} .tabs-trigger[data-target=#{value}]"
    )
    |> JS.add_class("hidden", to: "##{root} .tabs-content:not([value=#{value}])")
    |> JS.remove_class("hidden", to: "##{root} .tabs-content[value=#{value}]")
  end

  defp pop_phx_click(rest) do
    Enum.reduce_while([:"phx-click", "phx-click", :phx_click], {nil, rest}, fn key,
                                                                               {_click, acc} ->
      case Map.pop(acc, key) do
        {nil, updated} -> {:cont, {nil, updated}}
        {click, updated} -> {:halt, {click, updated}}
      end
    end)
  end

  defp tab_click(root, value, nil), do: show_tab(root, value)

  defp tab_click(root, value, event) when is_binary(event) do
    root
    |> show_tab(value)
    |> JS.push(event)
  end

  defp tab_click(root, value, %JS{} = event) do
    root
    |> show_tab(value)
    |> JS.concat(event)
  end
end
