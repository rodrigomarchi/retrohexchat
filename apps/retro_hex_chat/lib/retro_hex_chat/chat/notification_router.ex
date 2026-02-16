defmodule RetroHexChat.Chat.NotificationRouter do
  @moduledoc """
  Pure routing logic for the notification system.

  Given an event type, channel, and notification preferences, determines whether
  a notification should fire and what type it is. Zero Phoenix dependencies.

  Returns:
  - `{:notify, type}` — notification should fire with the given type
  - `:dnd_silent` — DND mode active; badges update but no audible/visual notification
  - `:skip` — no notification should fire
  """

  alias RetroHexChat.Chat.NotificationPreferences

  @type event_type :: :mention | :pm | :channel_message | :join | :leave
  @type result :: {:notify, event_type()} | :dnd_silent | :skip

  @spec should_notify?(
          event_type(),
          String.t() | nil,
          NotificationPreferences.t(),
          String.t() | nil
        ) ::
          result()
  def should_notify?(event_type, channel, prefs, active_channel) do
    cond do
      active_channel_match?(event_type, channel, active_channel) ->
        :skip

      prefs.dnd_enabled ->
        :dnd_silent

      channel_muted?(channel, prefs) ->
        :skip

      channel_mentions_only?(event_type, channel, prefs) ->
        :skip

      not trigger_enabled?(event_type, prefs) ->
        :skip

      true ->
        {:notify, notification_type(event_type)}
    end
  end

  @spec notification_type(event_type()) :: event_type()
  def notification_type(event_type), do: event_type

  @spec creates_center_entry?(event_type()) :: boolean()
  def creates_center_entry?(type) when type in [:mention, :pm, :channel_message], do: true
  def creates_center_entry?(_type), do: false

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp active_channel_match?(:pm, _channel, _active_channel), do: false

  defp active_channel_match?(_event_type, channel, active_channel) do
    channel != nil and channel == active_channel
  end

  defp channel_muted?(nil, _prefs), do: false

  defp channel_muted?(channel, prefs) do
    NotificationPreferences.get_channel_level(prefs, channel) == :mute
  end

  defp channel_mentions_only?(:mention, _channel, _prefs), do: false
  defp channel_mentions_only?(:pm, _channel, _prefs), do: false

  defp channel_mentions_only?(event_type, channel, prefs)
       when event_type in [:channel_message, :join, :leave] do
    channel != nil and
      NotificationPreferences.get_channel_level(prefs, channel) == :mentions_only
  end

  defp channel_mentions_only?(_event_type, _channel, _prefs), do: false

  defp trigger_enabled?(:mention, prefs), do: prefs.trigger_mentions
  defp trigger_enabled?(:pm, prefs), do: prefs.trigger_pms
  defp trigger_enabled?(:channel_message, prefs), do: prefs.trigger_channel_messages
  defp trigger_enabled?(:join, prefs), do: prefs.trigger_joins_leaves
  defp trigger_enabled?(:leave, prefs), do: prefs.trigger_joins_leaves
end
