defmodule RetroHexChatWeb.Components.UI.GroupCall.LayoutControls do
  @moduledoc """
  Layout and view controls for the group-call conference window.

  The component is intentionally stateless: ChatLive owns the selected mode and
  the WebRTC hook applies the resulting layout to mounted media elements.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.MediaSession.CommandBar
  import RetroHexChatWeb.Components.UI.MediaSession.IconButton

  alias RetroHexChatWeb.Icons.CallControls

  attr :call, :map, default: nil
  attr :on_layout_mode, :any, default: "group_call_layout_mode"
  attr :on_cycle_self_view, :any, default: "group_call_cycle_self_view"
  attr :on_clear_focus, :any, default: "group_call_clear_focus"
  attr :orientation, :string, values: ~w(horizontal vertical), default: "horizontal"
  attr :class, :any, default: nil

  @spec layout_controls(map()) :: Phoenix.LiveView.Rendered.t()
  def layout_controls(assigns) do
    ~H"""
    <.media_session_command_bar
      class={layout_controls_class(@orientation, @class)}
      aria_label={dgettext("group_call", "Conference layout controls")}
      data-orientation={@orientation}
      testid="group-call-layout-controls"
    >
      <.layout_button
        mode={:auto}
        current={layout_mode(@call)}
        event={@on_layout_mode}
        label={dgettext("group_call", "Auto layout")}
        testid="group-call-layout-auto"
      >
        <CallControls.icon_call_layout_auto class="h-4 w-4" />
      </.layout_button>

      <.layout_button
        mode={:grid}
        current={layout_mode(@call)}
        event={@on_layout_mode}
        label={dgettext("group_call", "Grid layout")}
        testid="group-call-layout-grid"
      >
        <CallControls.icon_call_layout_split class="h-4 w-4" />
      </.layout_button>

      <.layout_button
        mode={:focus}
        current={layout_mode(@call)}
        event={@on_layout_mode}
        label={dgettext("group_call", "Focus layout")}
        testid="group-call-layout-focus"
      >
        <CallControls.icon_call_layout_focus class="h-4 w-4" />
      </.layout_button>

      <.layout_button
        mode={:speaker}
        current={layout_mode(@call)}
        event={@on_layout_mode}
        label={dgettext("group_call", "Speaker layout")}
        testid="group-call-layout-speaker"
      >
        <CallControls.icon_call_layout_speaker class="h-4 w-4" />
      </.layout_button>

      <.media_session_icon_button
        label={self_view_title(@call)}
        active={self_view(@call) != :hidden}
        pressed={self_view(@call) != :hidden}
        phx-click={@on_cycle_self_view}
        data-self-view={self_view(@call)}
        data-testid="group-call-self-view-toggle"
      >
        <CallControls.icon_call_self_view class="h-4 w-4" />
      </.media_session_icon_button>

      <.media_session_icon_button
        :if={focused_participant_id(@call)}
        label={dgettext("group_call", "Clear focused participant")}
        phx-click={@on_clear_focus}
        data-testid="group-call-clear-focus"
      >
        <CallControls.icon_call_close class="h-4 w-4" />
      </.media_session_icon_button>
    </.media_session_command_bar>
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
    <.media_session_icon_button
      label={@label}
      active={@selected}
      pressed={@selected}
      phx-click={@event}
      phx-value-mode={@mode}
      data-layout-mode={@mode}
      data-testid={@testid}
    >
      {render_slot(@inner_block)}
    </.media_session_icon_button>
    """
  end

  defp layout_controls_class("vertical", extra) do
    classes([
      "flex shrink-0 flex-row flex-wrap gap-1 lg:flex-col",
      extra
    ])
  end

  defp layout_controls_class(_horizontal, extra) do
    classes([
      "flex shrink-0 flex-wrap items-center gap-1",
      extra
    ])
  end

  defp layout_mode(%{layout: %{mode: mode}})
       when mode in [:auto, :grid, :focus, :sidebar, :speaker],
       do: mode

  defp layout_mode(_call), do: :auto

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
