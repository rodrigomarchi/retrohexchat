defmodule RetroHexChat.VirtualSpace.Speech do
  @moduledoc """
  A line said inside a space.

  A space has no conversation of its own: what is said in it is said in the
  conversation it belongs to — the channel, or the private chat between its two
  people. The line is sent the way the chat sends one, so it lands in the
  conversation's history and everyone in the space sees it as a bubble over the
  speaker, because the space already turns that conversation's messages into
  bubbles.

  `/me` is the one command understood here; every other command belongs to the
  chat, where its replies have somewhere to be shown.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Admin.GlobalMutes
  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Chat.Service
  alias RetroHexChat.VirtualSpace.DirectMessageSpace

  @typedoc "The conversation a space belongs to."
  @type conversation :: {:channel, String.t()} | {:direct_message, [String.t()]}

  @spec say(conversation(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def say(conversation, nickname, text) when is_binary(text) do
    with {:ok, type, content} <- parse(String.trim(text)),
         :ok <- not_muted(nickname) do
      deliver(conversation, nickname, content, type)
    end
  end

  defp parse(""), do: {:error, dgettext("chat", "Type something to say first.")}

  defp parse("/me " <> action) do
    case String.trim(action) do
      "" -> {:error, dgettext("chat", "Type something to say first.")}
      action -> {:ok, "action", action}
    end
  end

  defp parse("/" <> _command),
    do: {:error, dgettext("chat", "Only /me works in a space. Other commands go in the chat.")}

  defp parse(text), do: {:ok, "message", text}

  defp not_muted(nickname) do
    if GlobalMutes.muted?(nickname),
      do: {:error, dgettext("chat", "You are muted by an administrator")},
      else: :ok
  end

  defp deliver({:channel, channel_name}, nickname, content, type) do
    case ChannelServer.send_message(channel_name, nickname, content, type) do
      {:ok, _id} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp deliver({:direct_message, participants}, nickname, content, type) do
    case Enum.reject(participants, &same_person?(&1, nickname)) do
      [peer] ->
        case Service.send_private_message(nickname, peer, content, type) do
          {:ok, _pm} -> :ok
          {:error, reason} -> {:error, reason}
        end

      _not_a_member ->
        {:error, dgettext("chat", "This private space belongs to two other people.")}
    end
  end

  defp same_person?(participant, nickname),
    do:
      DirectMessageSpace.normalize_nickname(participant) ==
        DirectMessageSpace.normalize_nickname(nickname)
end
