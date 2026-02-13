defmodule RetroHexChat.Chat.DisplayPreferences do
  @moduledoc """
  In-memory runtime struct for log display configuration.
  Controls which event types are visible and how timestamps are formatted
  in the Log Viewer window.
  """

  @type timestamp_format :: :hh_mm | :hh_mm_ss | :dd_mm_hh_mm | :none

  @type t :: %__MODULE__{
          show_joins: boolean(),
          show_parts: boolean(),
          show_kicks: boolean(),
          show_mode_changes: boolean(),
          show_topic_changes: boolean(),
          timestamp_format: timestamp_format()
        }

  @valid_timestamp_formats [:hh_mm, :hh_mm_ss, :dd_mm_hh_mm, :none]

  @toggleable_fields [
    :show_joins,
    :show_parts,
    :show_kicks,
    :show_mode_changes,
    :show_topic_changes
  ]

  defstruct show_joins: true,
            show_parts: true,
            show_kicks: true,
            show_mode_changes: true,
            show_topic_changes: true,
            timestamp_format: :hh_mm_ss

  @doc """
  Creates a new DisplayPreferences with default values.
  All event types are visible and timestamp format is `:hh_mm_ss`.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Toggles a specific event type visibility.
  Accepts `:show_joins`, `:show_parts`, `:show_kicks`,
  `:show_mode_changes`, or `:show_topic_changes`.
  """
  @spec toggle_event(t(), atom()) :: t()
  def toggle_event(%__MODULE__{} = prefs, field) when field in @toggleable_fields do
    Map.update!(prefs, field, &(!&1))
  end

  @doc """
  Sets the timestamp display format.
  Accepts `:hh_mm`, `:hh_mm_ss`, or `:dd_mm_hh_mm`.
  """
  @spec set_timestamp_format(t(), timestamp_format()) :: t()
  def set_timestamp_format(%__MODULE__{} = prefs, format)
      when format in @valid_timestamp_formats do
    %{prefs | timestamp_format: format}
  end

  @doc """
  Returns a formatted timestamp string based on the selected format.

  - `:hh_mm` -> `"[HH:MM]"`
  - `:hh_mm_ss` -> `"[HH:MM:SS]"`
  - `:dd_mm_hh_mm` -> `"[DD/MM HH:MM]"`
  """
  @spec format_timestamp(t(), DateTime.t()) :: String.t()
  def format_timestamp(%__MODULE__{timestamp_format: :hh_mm}, %DateTime{} = dt) do
    "[#{pad(dt.hour)}:#{pad(dt.minute)}]"
  end

  def format_timestamp(%__MODULE__{timestamp_format: :hh_mm_ss}, %DateTime{} = dt) do
    "[#{pad(dt.hour)}:#{pad(dt.minute)}:#{pad(dt.second)}]"
  end

  def format_timestamp(%__MODULE__{timestamp_format: :dd_mm_hh_mm}, %DateTime{} = dt) do
    "[#{pad(dt.day)}/#{pad(dt.month)} #{pad(dt.hour)}:#{pad(dt.minute)}]"
  end

  def format_timestamp(%__MODULE__{timestamp_format: :none}, %DateTime{}), do: ""

  @doc """
  Returns true if the given message type should be displayed.

  - `"message"` and `"action"` are always visible.
  - `"system"` messages are checked against content patterns:
    - Content containing "joined" or "has joined" checks `show_joins`
    - Content containing "left", "has left", or "parted" checks `show_parts`
    - Content containing "kicked" or "was kicked" checks `show_kicks`
    - Content containing "sets mode" or "mode" checks `show_mode_changes`
    - Content containing "topic" or "changed the topic" checks `show_topic_changes`
    - Other system messages are always visible.
  """
  @spec visible_type?(t(), String.t(), String.t()) :: boolean()
  def visible_type?(prefs, type, content \\ "")

  def visible_type?(%__MODULE__{}, "message", _content), do: true
  def visible_type?(%__MODULE__{}, "action", _content), do: true

  def visible_type?(%__MODULE__{} = prefs, "system", content) do
    downcased = String.downcase(content)
    system_event_visible?(prefs, classify_system_content(downcased))
  end

  def visible_type?(%__MODULE__{}, _type, _content), do: true

  @spec classify_system_content(String.t()) :: atom()
  defp classify_system_content(content) do
    cond do
      join_content?(content) -> :join
      part_content?(content) -> :part
      kick_content?(content) -> :kick
      mode_content?(content) -> :mode
      topic_content?(content) -> :topic
      true -> :other
    end
  end

  @spec system_event_visible?(t(), atom()) :: boolean()
  defp system_event_visible?(%__MODULE__{show_joins: show}, :join), do: show
  defp system_event_visible?(%__MODULE__{show_parts: show}, :part), do: show
  defp system_event_visible?(%__MODULE__{show_kicks: show}, :kick), do: show
  defp system_event_visible?(%__MODULE__{show_mode_changes: show}, :mode), do: show
  defp system_event_visible?(%__MODULE__{show_topic_changes: show}, :topic), do: show
  defp system_event_visible?(%__MODULE__{}, :other), do: true

  # Content matchers

  defp join_content?(content) do
    String.contains?(content, "joined") or String.contains?(content, "has joined")
  end

  defp part_content?(content) do
    String.contains?(content, "left") or
      String.contains?(content, "has left") or
      String.contains?(content, "parted")
  end

  defp kick_content?(content) do
    String.contains?(content, "kicked") or String.contains?(content, "was kicked")
  end

  defp mode_content?(content) do
    String.contains?(content, "sets mode") or String.contains?(content, "mode")
  end

  defp topic_content?(content) do
    String.contains?(content, "topic") or String.contains?(content, "changed the topic")
  end

  defp pad(int) when int < 10, do: "0#{int}"
  defp pad(int), do: "#{int}"
end
