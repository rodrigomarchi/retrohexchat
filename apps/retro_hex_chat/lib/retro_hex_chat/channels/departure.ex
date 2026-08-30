defmodule RetroHexChat.Channels.Departure do
  @moduledoc """
  Taking someone out of every channel they were in, because they are gone.

  This used to live inside the chat's LiveView, where it was the same thing as
  the tab closing. It is not the same thing any more — a conference in a tab of
  its own outlives the chat — so the act has a name of its own and a caller
  that is not always the chat.

  A channel whose process cannot be reached contributes nothing rather than
  raising: this is the last thing that happens to a session, and a channel that
  is not answering is a channel nobody is being parted from.
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Topics

  @reason_limit 200

  @doc "Untrack and part `nickname` from each of `channels`."
  @spec part_all(String.t(), [String.t()], String.t() | nil) :: :ok
  def part_all(nickname, channels, reason \\ nil)

  def part_all(nickname, channels, reason) when is_binary(nickname) and is_list(channels) do
    reason =
      (reason || dgettext("channels", "Connection lost"))
      |> String.slice(0, @reason_limit)

    Enum.each(channels, fn channel ->
      if is_binary(channel), do: part_one(channel, nickname, reason)
    end)
  end

  def part_all(_nickname, _channels, _reason), do: :ok

  defp part_one(channel, nickname, reason) do
    untrack(channel, nickname)
    Server.part(channel, nickname, reason)
    :ok
  rescue
    error ->
      Logger.warning("Failed to part #{channel} during cleanup: #{inspect(error)}")
      :ok
  end

  defp untrack(channel, nickname) do
    Tracker.untrack_user(Topics.channel(channel), nickname)
  rescue
    error ->
      Logger.warning("Tracker.untrack_user(#{channel}, #{nickname}): #{inspect(error)}")
      :ok
  end
end
