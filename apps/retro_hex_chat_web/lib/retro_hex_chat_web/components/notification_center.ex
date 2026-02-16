defmodule RetroHexChatWeb.Components.NotificationCenter do
  @moduledoc """
  Notification center dropdown panel.
  Shows recent notifications in reverse chronological order.
  Anchored below the bell icon in the toolbar.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :entries, :list, default: []
  attr :count, :integer, default: 0

  @spec notification_center(map()) :: Phoenix.LiveView.Rendered.t()
  def notification_center(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="window notification-center"
      data-testid="notification-center"
    >
      <div class="title-bar">
        <div class="title-bar-text">Notifications</div>
        <div class="title-bar-controls">
          <button type="button" aria-label="Close" phx-click="toggle_notification_center"></button>
        </div>
      </div>
      <div class="window-body notification-center-body">
        <div
          :if={@entries == []}
          class="notification-center-empty"
          data-testid="notification-center-empty"
        >
          No notifications
        </div>
        <div
          :for={entry <- @entries}
          class="notification-center-entry"
          phx-click="click_notification"
          phx-value-id={entry.id}
          data-testid={"notification-entry-#{entry.id}"}
        >
          <span class="notification-center-time">{relative_time(entry.timestamp)}</span>
          <span class="notification-center-text">
            <strong>{entry.sender}</strong>
            <span :if={entry.channel}> in {entry.channel}</span>: {truncate(entry.content, 80)}
          </span>
        </div>
        <div :if={@entries != []} class="notification-center-actions">
          <button
            type="button"
            phx-click="mark_all_notifications_read"
            data-testid="mark-all-read"
          >
            Mark all as read
          </button>
        </div>
      </div>
    </div>
    """
  end

  @spec relative_time(String.t()) :: String.t()
  defp relative_time(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} ->
        diff = DateTime.diff(DateTime.utc_now(), dt, :second)

        cond do
          diff < 60 -> "just now"
          diff < 3600 -> "#{div(diff, 60)} min ago"
          diff < 86_400 -> "#{div(diff, 3600)} hr ago"
          true -> "#{div(diff, 86_400)} d ago"
        end

      _ ->
        ""
    end
  end

  defp relative_time(_), do: ""

  @spec truncate(String.t(), non_neg_integer()) :: String.t()
  defp truncate(text, max) when byte_size(text) > max do
    String.slice(text, 0, max) <> "..."
  end

  defp truncate(text, _max), do: text
end
