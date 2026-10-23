defmodule RetroHexChatWeb.Components.UI.MediaSession.CallQuality do
  @moduledoc """
  How a call's connection is doing, in the words and pictures every call
  draws it with.

  A P2P session and a group call measure the same thing and grade it on the
  same scale — excellent, good, fair, poor, and reconnecting while the link is
  being rebuilt — so the grade, its name and its bars are decided here once.
  Where each is drawn stays with its window: over the remote video in a P2P
  session, in a participant's tile in a group call.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @type level :: :excellent | :good | :fair | :poor | :reconnecting | :unknown

  @doc "The grade a payload carries — an atom, the browser's string, or a map with `:level`."
  @spec level(term()) :: level()
  def level(%{level: level}), do: level(level)
  def level(level) when level in [:excellent, :good, :fair, :poor, :reconnecting], do: level

  def level(level) when is_binary(level) do
    case level do
      "excellent" -> :excellent
      "good" -> :good
      "fair" -> :fair
      "poor" -> :poor
      "reconnecting" -> :reconnecting
      _other -> :unknown
    end
  end

  def level(_level), do: :unknown

  @doc "The grade's name."
  @spec label(level()) :: String.t()
  def label(:excellent), do: dgettext("group_call", "Excellent")
  def label(:good), do: dgettext("group_call", "Good")
  def label(:fair), do: dgettext("group_call", "Fair")
  def label(:poor), do: dgettext("group_call", "Poor")
  def label(:reconnecting), do: dgettext("group_call", "Reconnecting")
  def label(:unknown), do: dgettext("group_call", "Unknown")

  attr :level, :atom, required: true
  attr :class, :any, default: "h-4 w-4"

  @doc "The grade's picture: bars for a measured link, a clock while it is rebuilt."
  @spec quality_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def quality_icon(assigns) do
    ~H"""
    <Icons.icon_quality_high :if={@level in [:excellent, :good]} class={@class} />
    <Icons.icon_quality_medium :if={@level == :fair} class={@class} />
    <Icons.icon_quality_low :if={@level == :poor} class={@class} />
    <Icons.icon_btn_timers :if={@level == :reconnecting} class={@class} />
    """
  end
end
