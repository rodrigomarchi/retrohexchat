defmodule RetroHexChatWeb.Components.UI.GroupCall.LayoutControls do
  @moduledoc """
  Layout and view controls for the group-call conference window.

  The component is intentionally stateless: ChatLive owns the selected mode and
  the WebRTC hook applies the resulting layout to mounted media elements.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :call, :map, default: nil
  attr :on_layout_mode, :any, default: "group_call_layout_mode"
  attr :on_toggle_sidebar, :any, default: "group_call_toggle_sidebar"
  attr :on_cycle_self_view, :any, default: "group_call_cycle_self_view"
  attr :on_clear_focus, :any, default: "group_call_clear_focus"

  @spec layout_controls(map()) :: Phoenix.LiveView.Rendered.t()
  def layout_controls(assigns) do
    ~H"""
    <div
      class="flex shrink-0 items-center gap-px"
      role="toolbar"
      aria-label={dgettext("group_call", "Conference layout controls")}
      data-testid="group-call-layout-controls"
    >
      <.layout_button
        mode={:auto}
        current={layout_mode(@call)}
        event={@on_layout_mode}
        label={dgettext("group_call", "Auto layout")}
        testid="group-call-layout-auto"
      >
        <Icons.icon_layout_maximize class="h-3.5 w-3.5" />
      </.layout_button>

      <.layout_button
        mode={:grid}
        current={layout_mode(@call)}
        event={@on_layout_mode}
        label={dgettext("group_call", "Grid layout")}
        testid="group-call-layout-grid"
      >
        <Icons.icon_layout_side_by_side class="h-3.5 w-3.5" />
      </.layout_button>

      <.layout_button
        mode={:focus}
        current={layout_mode(@call)}
        event={@on_layout_mode}
        label={dgettext("group_call", "Focus layout")}
        testid="group-call-layout-focus"
      >
        <Icons.icon_layout_focus class="h-3.5 w-3.5" />
      </.layout_button>

      <.layout_button
        mode={:speaker}
        current={layout_mode(@call)}
        event={@on_layout_mode}
        label={dgettext("group_call", "Speaker layout")}
        testid="group-call-layout-speaker"
      >
        <Icons.icon_microphone class="h-3.5 w-3.5" />
      </.layout_button>

      <button
        type="button"
        phx-click={@on_toggle_sidebar}
        class={control_button_class(sidebar_open?(@call))}
        aria-label={dgettext("group_call", "Toggle participants panel")}
        title={dgettext("group_call", "Toggle participants panel")}
        aria-pressed={to_string(sidebar_open?(@call))}
        data-testid="group-call-layout-sidebar"
      >
        <Icons.icon_tab_nicklist class="h-3.5 w-3.5" />
      </button>

      <button
        type="button"
        phx-click={@on_cycle_self_view}
        class={control_button_class(self_view(@call) != :hidden)}
        aria-label={self_view_title(@call)}
        title={self_view_title(@call)}
        data-self-view={self_view(@call)}
        data-testid="group-call-self-view-toggle"
      >
        <Icons.icon_pip class="h-3.5 w-3.5" />
      </button>

      <button
        :if={focused_participant_id(@call)}
        type="button"
        phx-click={@on_clear_focus}
        class={control_button_class(false)}
        aria-label={dgettext("group_call", "Clear focused participant")}
        title={dgettext("group_call", "Clear focused participant")}
        data-testid="group-call-clear-focus"
      >
        <Icons.icon_close class="h-3.5 w-3.5" />
      </button>
    </div>
    """
  end

  attr :mode, :atom, required: true
  attr :current, :atom, required: true
  attr :event, :any, required: true
  attr :label, :string, required: true
  attr :testid, :string, required: true
  slot :inner_block, required: true

  defp layout_button(assigns) do
    assigns = assign(assigns, :selected, assigns.mode == assigns.current)

    ~H"""
    <button
      type="button"
      phx-click={@event}
      phx-value-mode={@mode}
      class={control_button_class(@selected)}
      aria-label={@label}
      title={@label}
      aria-pressed={to_string(@selected)}
      data-layout-mode={@mode}
      data-testid={@testid}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp control_button_class(selected?) do
    classes([
      "flex h-6 w-7 items-center justify-center bg-surface shadow-retro-raised",
      "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
      selected? && "bg-muted shadow-retro-sunken"
    ])
  end

  defp layout_mode(%{layout: %{mode: mode}})
       when mode in [:auto, :grid, :focus, :sidebar, :speaker],
       do: mode

  defp layout_mode(_call), do: :auto

  defp sidebar_open?(%{layout: %{sidebar_open: false}}), do: false
  defp sidebar_open?(_call), do: true

  defp self_view(%{layout: %{self_view: mode}}) when mode in [:tile, :pip, :hidden], do: mode
  defp self_view(_call), do: :tile

  defp focused_participant_id(%{layout: %{focused_participant_id: id}}), do: id
  defp focused_participant_id(_call), do: nil

  defp self_view_title(%{layout: %{self_view: :tile}}),
    do: dgettext("group_call", "Move self view to picture-in-picture")

  defp self_view_title(%{layout: %{self_view: :pip}}),
    do: dgettext("group_call", "Hide self view")

  defp self_view_title(%{layout: %{self_view: :hidden}}),
    do: dgettext("group_call", "Show self view in grid")

  defp self_view_title(_call), do: dgettext("group_call", "Change self view")
end
