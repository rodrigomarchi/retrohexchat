defmodule RetroHexChatWeb.Components.UI.SidebarRail do
  @moduledoc """
  The 36px rail a collapsed chat sidebar shrinks to: a toggle that folds the
  sidebar in or out, and a column of buttons, each an icon with an optional
  count and unread badge. The conversations list rides it on the left, the
  user list on the right.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChatWeb.Icons

  @doc "The rail: its fold toggle, then its items."
  attr :side, :string, values: ~w(left right), required: true
  attr :label, :string, required: true, doc: "the rail's accessible name"
  attr :testid, :string, required: true
  attr :expanded, :boolean, default: true
  attr :collapse_label, :string, required: true
  attr :expand_label, :string, required: true
  attr :on_toggle, :any, required: true
  slot :inner_block, required: true

  @spec sidebar_rail(map()) :: Phoenix.LiveView.Rendered.t()
  def sidebar_rail(assigns) do
    ~H"""
    <nav
      class={"chat-sidebar-rail chat-sidebar-rail--#{@side}"}
      aria-label={@label}
      data-testid={@testid}
    >
      <.tool_button
        label={if @expanded, do: @collapse_label, else: @expand_label}
        variant="flat"
        size="xs"
        active={@expanded}
        class="chat-sidebar-rail__button"
        phx-click={@on_toggle}
        aria-expanded={to_string(@expanded)}
        data-testid={"#{@testid}-toggle"}
      >
        <.fold_chevron points={fold_direction(@side, @expanded)} />
      </.tool_button>
      {render_slot(@inner_block)}
    </nav>
    """
  end

  @doc """
  One button on the rail: its icon, then its count and unread badge when it
  has them. On a folded rail a click unfolds the sidebar.
  """
  attr :label, :string, required: true
  attr :count, :integer, default: nil
  attr :badge, :any, default: nil, doc: "the unread badge's text, or nil for none"
  attr :active, :boolean, default: false
  attr :expanded, :boolean, default: true
  attr :on_toggle, :any, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true, doc: "the icon"

  @spec rail_item(map()) :: Phoenix.LiveView.Rendered.t()
  def rail_item(assigns) do
    ~H"""
    <.tool_button
      label={item_title(@label, @count)}
      variant="flat"
      size="xs"
      active={@active}
      class={["chat-sidebar-rail__button", @class]}
      phx-click={if @expanded, do: nil, else: @on_toggle}
    >
      {render_slot(@inner_block)}
      <span :if={is_integer(@count)} class="chat-sidebar-rail__count">{@count}</span>
      <span :if={@badge} class="chat-sidebar-rail__badge">
        {@badge}
      </span>
    </.tool_button>
    """
  end

  # Folding moves the sidebar toward its own edge.
  defp fold_direction("left", expanded), do: if(expanded, do: :left, else: :right)
  defp fold_direction("right", expanded), do: if(expanded, do: :right, else: :left)

  attr :points, :atom, required: true

  defp fold_chevron(%{points: :left} = assigns) do
    ~H"""
    <Icons.icon_chevron_left class="h-4 w-4" />
    """
  end

  defp fold_chevron(%{points: :right} = assigns) do
    ~H"""
    <Icons.icon_chevron_right class="h-4 w-4" />
    """
  end

  defp item_title(label, count) when is_integer(count), do: "#{label}: #{count}"
  defp item_title(label, _count), do: label
end
