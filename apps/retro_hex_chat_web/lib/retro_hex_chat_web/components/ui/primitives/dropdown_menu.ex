defmodule RetroHexChatWeb.Components.UI.DropdownMenu do
  @moduledoc """
  A Win98 menu that drops from a trigger: a `Popover` whose panel is a list of
  menu rows.

  The rows are buttons (`dropdown_menu_item/1`) — so they must not contain
  another control — and a keyboard reaches them (the arrow keys move between
  them) and `phx-click` works on them; give an action `Popover.close_after/1` so the menu
  closes once it has been chosen. A destructive row says so with
  `tone="danger"` — in a menu the danger is in the word and its colour, never
  in a second red button beside the others.

  ## Example

      <.dropdown_menu label="Moderation" trigger_class={tool_button_class(variant: "flat")}>
        <:trigger>Moderation</:trigger>
        <.dropdown_menu_item phx-click={close_after("lock")}>
          <:icon><Icons.icon_lock /></:icon>
          Lock conference
        </.dropdown_menu_item>
      </.dropdown_menu>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Popover

  alias RetroHexChatWeb.Icons

  attr :label, :string, required: true
  attr :trigger_class, :any, default: nil
  attr :trigger_testid, :string, default: nil
  attr :placement, :string, default: "below-end"
  attr :panel_class, :any, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(open)

  slot :trigger, required: true
  slot :inner_block, required: true

  @spec dropdown_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def dropdown_menu(assigns) do
    ~H"""
    <.popover
      label={@label}
      trigger_class={@trigger_class}
      trigger_testid={@trigger_testid}
      trigger_attrs={["aria-haspopup": "menu"]}
      placement={@placement}
      panel_role="menu"
      panel_class={
        classes([
          "flex min-w-[12rem] flex-col border border-border bg-surface p-[2px] shadow-retro-raised",
          @panel_class
        ])
      }
      class={@class}
      {@rest}
    >
      <:trigger>{render_slot(@trigger)}</:trigger>
      {render_slot(@inner_block)}
    </.popover>
    """
  end

  @doc "Renders a dropdown menu item with mandatory icon and optional shortcut."
  attr :disabled, :boolean, default: false
  attr :tone, :string, values: ~w(default danger), default: "default"

  attr :checked, :boolean,
    default: nil,
    doc: "makes the row a checkable item: ticked while true, the same words either way"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :icon, required: true, doc: "16×16 icon SVG — mandatory for visual consistency"
  slot :inner_block, required: true
  slot :shortcut

  @spec dropdown_menu_item(map()) :: Phoenix.LiveView.Rendered.t()
  def dropdown_menu_item(assigns) do
    ~H"""
    <button
      type="button"
      role={if is_nil(@checked), do: "menuitem", else: "menuitemcheckbox"}
      aria-checked={!is_nil(@checked) && to_string(@checked)}
      disabled={@disabled}
      class={
        classes([
          "flex w-full items-center gap-1.5 px-3 py-1 text-left text-xs whitespace-nowrap cursor-pointer select-none",
          if(@disabled, do: "text-disabled cursor-default", else: "menu-row"),
          @tone == "danger" && "font-bold text-destructive",
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
      <Icons.icon_checkmark :if={@checked} class="ml-4 h-3 w-3 shrink-0" />
    </button>
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
end
