defmodule RetroHexChatWeb.Components.UI.System.SectionHeading do
  @moduledoc """
  The heading every section of the system windows opens with — its icon, its
  name, and room on the right for the section's own controls — and the
  refresh button those headings usually carry.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChatWeb.Icons

  attr :icon, :atom, required: true
  attr :label, :string, required: true
  slot :inner_block

  @spec system_section_heading(map()) :: Phoenix.LiveView.Rendered.t()
  def system_section_heading(assigns) do
    ~H"""
    <h3 class="mb-retro-4 flex min-w-0 items-center gap-1 text-xs font-bold">
      {apply(Icons, @icon, [%{class: "h-4 w-4 shrink-0"}])}
      <span class="min-w-0 flex-1 truncate">{@label}</span>
      {render_slot(@inner_block)}
    </h3>
    """
  end

  attr :target, :any, default: nil
  attr :on_refresh, :string, required: true
  attr :testid, :string, required: true

  @spec system_refresh_button(map()) :: Phoenix.LiveView.Rendered.t()
  def system_refresh_button(assigns) do
    ~H"""
    <.tool_button
      label={dgettext("dialogs", "Refresh")}
      variant="flat"
      size="sm"
      phx-click={@on_refresh}
      phx-target={@target}
      data-testid={@testid}
    >
      <Icons.icon_btn_refresh class="h-[14px] w-[14px]" />
    </.tool_button>
    """
  end
end
