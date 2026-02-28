defmodule RetroHexChatWeb.Components.UI.DropdownMenu do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias Phoenix.LiveView.JS

  @doc """
  Render dropdown menu


  ## Examples:

      <.dropdown_menu>
        <.dropdown_menu_trigger>
          <.button variant="outline">Open</.button>
        </.dropdown_menu_trigger>

        <.dropdown_menu_content>
          <.dropdown_menu_label>Account</.dropdown_menu_label>
          <.dropdown_menu_separator />

          <.dropdown_menu_group>
            <.dropdown_menu_item>
              Profile
              <.dropdown_menu_shortcut>⌘P</.dropdown_menu_shortcut>
            </.dropdown_menu_item>
            <.dropdown_menu_item>
              Billing
              <.dropdown_menu_shortcut>⌘B</.dropdown_menu_shortcut>
            </.dropdown_menu_item>
            <.dropdown_menu_item>
              Settings
              <.dropdown_menu_shortcut>⌘S</.dropdown_menu_shortcut>
            </.dropdown_menu_item>
          </.dropdown_menu_group>
        </.dropdown_menu_content>
      </.dropdown_menu>
  """

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def dropdown_menu(assigns) do
    ~H"""
    <div class={classes(["relative group inline-block", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :string, default: nil
  attr :as_tag, :any, default: "div"
  slot :inner_block, required: true

  attr :rest, :global

  def dropdown_menu_trigger(assigns) do
    ~H"""
    <.dynamic
      tag={@as_tag}
      class={classes(["dropdown-menu-trigger peer", @class])}
      data-state="closed"
      {@rest}
      phx-click={toggle()}
      phx-click-away={hide()}
    >
      {render_slot(@inner_block)}
    </.dynamic>
    """
  end

  attr :class, :string, default: nil
  attr :side, :string, values: ["top", "right", "bottom", "left"], default: "bottom"
  attr :align, :string, values: ["start", "center", "end"], default: "start"
  slot :inner_block, required: true
  attr :rest, :global

  def dropdown_menu_content(assigns) do
    assigns =
      assign(assigns, :variant_class, side_variant(assigns.side, assigns.align))

    ~H"""
    <div
      class={[
        "z-50 animate-in peer-data-[state=closed]:fade-out-0 peer-data-[state=open]:fade-in-0 peer-data-[state=closed]:zoom-out-95 peer-data-[state=open]:zoom-in-95 peer-data-[side=bottom]:slide-in-from-top-2 peer-data-[side=left]:slide-in-from-right-2 peer-data-[side=right]:slide-in-from-left-2 peer-data-[side=top]:slide-in-from-bottom-2",
        "absolute peer-data-[state=closed]:hidden",
        @variant_class,
        @class
      ]}
      {@rest}
    >
      <div class="">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc "Renders a dropdown menu item with mandatory icon and optional shortcut."
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global
  slot :icon, required: true, doc: "16×16 icon SVG — mandatory for visual consistency"
  slot :inner_block, required: true
  slot :shortcut

  @spec dropdown_menu_item(map()) :: Phoenix.LiveView.Rendered.t()
  def dropdown_menu_item(assigns) do
    ~H"""
    <div
      role="menuitem"
      class={
        classes([
          "flex items-center gap-1.5 px-3 py-1 text-sm whitespace-nowrap cursor-pointer select-none",
          if(@disabled,
            do: "text-disabled cursor-default",
            else: "hover:bg-primary hover:text-white"
          ),
          @class
        ])
      }
      {@rest}
    >
      <span class="w-[16px] h-[16px] flex-shrink-0 inline-flex items-center justify-center">
        {render_slot(@icon)}
      </span>
      <span class="flex-1">{render_slot(@inner_block)}</span>
      <span :if={@shortcut != []} class="ml-4 text-xs opacity-60">
        {render_slot(@shortcut)}
      </span>
    </div>
    """
  end

  @doc "Renders a label for a group of dropdown menu items."
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec dropdown_menu_label(map()) :: Phoenix.LiveView.Rendered.t()
  def dropdown_menu_label(assigns) do
    ~H"""
    <div
      class={classes(["px-3 py-1 text-xs font-bold select-none", @class])}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a horizontal separator line in a dropdown menu."
  attr :class, :string, default: nil

  @spec dropdown_menu_separator(map()) :: Phoenix.LiveView.Rendered.t()
  def dropdown_menu_separator(assigns) do
    ~H"""
    <div role="separator" class={classes(["border-t border-separator my-[2px]", @class])} />
    """
  end

  @doc "Renders a group of dropdown menu items."
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec dropdown_menu_group(map()) :: Phoenix.LiveView.Rendered.t()
  def dropdown_menu_group(assigns) do
    ~H"""
    <div role="group" class={classes([@class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a keyboard shortcut hint inside a dropdown menu item."
  attr(:class, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  @spec dropdown_menu_shortcut(map()) :: Phoenix.LiveView.Rendered.t()
  def dropdown_menu_shortcut(assigns) do
    ~H"""
    <span
      class={
        classes([
          "ml-auto text-xs tracking-widest opacity-60",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp toggle(js \\ %JS{}) do
    JS.toggle_attribute(js, {"data-state", "open", "closed"})
  end

  defp hide(js \\ %JS{}) do
    JS.set_attribute(js, {"data-state", "closed"})
  end
end
