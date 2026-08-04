defmodule RetroHexChatWeb.Components.UI.Help.HelpStatusBar do
  @moduledoc """
  Status bar for the help desktop's top bar.

  The help counterpart to `StatusBarApp`, composed from the same
  `window_status_bar`/`window_status_bar_field` primitives but surfacing
  help-relevant state: the current topic breadcrumb (category › title), the total
  topic count, and the clock (filled in client-side by `ClockHook`).
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  attr :selected_topic, :map, default: nil
  attr :topic_count, :integer, default: 0
  attr :class, :any, default: nil
  attr :rest, :global

  @spec help_status_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def help_status_bar(assigns) do
    ~H"""
    <%!-- Icons on a phone, labels from md up — the same reading `StatusBarApp`
          gives the chat. The breadcrumb goes too: the topic pane repeats it
          under the heading, and spelled out beside the rail it left the header
          with no room for anything else. No clock either; the desktop tray owns
          that, as it does on every other shell. --%>
    <.window_status_bar class={@class} data-testid="help-status-bar" {@rest}>
      <%!-- Current topic breadcrumb --%>
      <.window_status_bar_field
        grow
        class="flex items-center gap-retro-2 min-w-0"
        title={breadcrumb(@selected_topic)}
      >
        <Icons.icon_notepad class="h-3 w-3 shrink-0" />
        <span class="hidden truncate text-xs md:inline">{breadcrumb(@selected_topic)}</span>
      </.window_status_bar_field>

      <%!-- Topic count --%>
      <.window_status_bar_field
        class="flex items-center gap-retro-2 min-w-0"
        title={dgettext("help", "%{count} topics", count: @topic_count)}
      >
        <Icons.icon_btn_channel_list class="h-3 w-3 shrink-0" />
        <span class="hidden truncate text-xs tabular-nums md:inline">
          {dgettext("help", "%{count} topics", count: @topic_count)}
        </span>
      </.window_status_bar_field>
    </.window_status_bar>
    """
  end

  # ── Private helpers ───────────────────────────────────

  @spec breadcrumb(map() | nil) :: String.t()
  defp breadcrumb(nil), do: dgettext("help", "Help")
  defp breadcrumb(%{category: category, title: title}), do: "#{category} › #{title}"
  defp breadcrumb(_topic), do: dgettext("help", "Help")
end
