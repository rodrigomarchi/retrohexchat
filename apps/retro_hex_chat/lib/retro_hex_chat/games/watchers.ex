defmodule RetroHexChat.Games.Watchers do
  @moduledoc """
  How many people are watching a match.

  Each page open on a match (`/watch/<token>`) counts once, by presence: a tab
  that closes, crashes or loses its connection stops counting without telling
  anybody. Nothing about who is watching is kept or shown — only how many, and
  only while the page is open.
  """

  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Topics

  @doc "The calling process watches the match of `session_token`, until it exits."
  @spec watch(String.t()) :: :ok
  def watch(session_token) do
    key = Integer.to_string(System.unique_integer([:positive]))
    {:ok, _ref} = Tracker.track(self(), Topics.lobby_watchers(session_token), key, %{})
    :ok
  end

  @doc "How many pages are watching the match of `session_token` now."
  @spec count(String.t()) :: non_neg_integer()
  def count(session_token),
    do: session_token |> Topics.lobby_watchers() |> Tracker.list() |> map_size()
end
