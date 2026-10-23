defmodule RetroHexChatWeb.ChatLive.Helpers.PendingInvite do
  @moduledoc """
  An invitation to a channel waiting for an answer: it holds a timer that
  expires it, and the channel holds an invite exception for the invitee until
  then. Accepting, declining and expiring all end both.
  """

  require Logger

  alias RetroHexChat.Channels.Server

  @doc """
  Takes the pending invite to `channel` out of `pending`, cancelling its timer.
  Returns the remaining invites and the one taken out, or `nil` when there was
  none.
  """
  @spec cancel([map()], String.t()) :: {[map()], map() | nil}
  def cancel(pending, channel) do
    case Enum.split_with(pending, &(&1.channel == channel)) do
      {[existing], rest} ->
        Process.cancel_timer(existing.timer_ref)
        {rest, existing}

      {[], _} ->
        {pending, nil}
    end
  end

  @doc """
  Drops the invitee's invite exception. A channel that has already gone has
  nothing left to drop, so its exit is logged and ignored.
  """
  @spec remove_exception(String.t(), String.t()) :: :ok
  def remove_exception(channel, nickname) do
    Server.remove_invite_exception(channel, nickname, nickname)
    :ok
  rescue
    error ->
      Logger.debug("invite exception not removed from #{channel}: #{Exception.message(error)}")
      :ok
  catch
    :exit, reason ->
      Logger.debug("invite exception not removed from #{channel}: #{inspect(reason)}")
      :ok
  end
end
