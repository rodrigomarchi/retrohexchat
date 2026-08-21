defmodule RetroHexChatWeb.Components.UI.Help.HelpStatusBar do
  @moduledoc """
  The help window's own status bar fields.

  The help counterpart to `StatusBarApp`'s zones: `window_status_bar_field`
  elements surfacing help state — the current topic breadcrumb (category ›
  title) and the total topic count. Fields only, no frame: the window draws that
  itself from `desktop_window/1`'s `:status` slot. No clock — the desktop tray
  owns it.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  attr :selected_topic, :map, default: nil
  attr :topic_count, :integer, default: 0

  @spec help_status_zones(map()) :: Phoenix.LiveView.Rendered.t()
  def help_status_zones(assigns) do
    ~H"""
    <%!-- Icons on a phone, labels from md up — the same reading `StatusBarApp`
          gives the chat. The breadcrumb is short for the same reason: the topic
          pane repeats it under the heading, and spelled out beside the menu
          rail it left no room for anything else. --%>
    <%!-- Current topic breadcrumb --%>
    <.window_status_bar_field
      grow
      class="flex items-center gap-retro-2 min-w-0"
      title={breadcrumb(@selected_topic)}
      data-testid="help-status-topic"
    >
      <Icons.icon_notepad class="h-3 w-3 shrink-0" />
      <span class="hidden truncate text-xs md:inline">{breadcrumb(@selected_topic)}</span>
    </.window_status_bar_field>

    <%!-- Topic count --%>
    <.window_status_bar_field
      class="flex items-center gap-retro-2 min-w-0"
      title={dgettext("help", "%{count} topics", count: @topic_count)}
      data-testid="help-status-count"
    >
      <Icons.icon_btn_channel_list class="h-3 w-3 shrink-0" />
      <span class="hidden truncate text-xs tabular-nums md:inline">
        {dgettext("help", "%{count} topics", count: @topic_count)}
      </span>
    </.window_status_bar_field>
    """
  end

  # ── Private helpers ───────────────────────────────────

  @spec breadcrumb(map() | nil) :: String.t()
  defp breadcrumb(nil), do: dgettext("help", "Help")
  defp breadcrumb(%{category: category, title: title}), do: "#{category} › #{title}"
  defp breadcrumb(_topic), do: dgettext("help", "Help")
end
