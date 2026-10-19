defmodule RetroHexChat.Chat.SendOptions do
  @moduledoc """
  The options a written message is sent with, read the same way on both ways in.

  A line reaches the database through `Chat.Service` (private conversations)
  or through the channel's own process (`Channels.Server`). Both accept the
  same keyword list — `:content_format`, `:attachment_ids`, `:before_broadcast`
  — and each used to read it with a private copy of the same helpers, which is
  how an option comes to work in a channel and silently do nothing in a
  conversation.
  """

  alias RetroHexChat.Chat.Content

  @doc "The format the message is written in, `\"irc\"` unless the options say otherwise."
  @spec content_format(keyword()) :: String.t()
  def content_format(opts), do: opts |> Keyword.get(:content_format, "irc") |> normalize_format()

  @doc "A format as the database stores it; an unknown one is left for validation to refuse."
  @spec normalize_format(String.t() | atom()) :: String.t() | atom()
  def normalize_format(format) do
    case Content.normalize_format(format) do
      {:ok, normalized} -> Atom.to_string(normalized)
      :error -> format
    end
  end

  @doc "The attachments the message carries, without blanks."
  @spec attachment_ids(keyword()) :: [integer()]
  def attachment_ids(opts) do
    opts
    |> Keyword.get(:attachment_ids, [])
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Run the caller's `:before_broadcast` hook with the id the message was written
  under, after it is stored and before anybody is told about it.

  This is the window a card needs: whatever the line announces records the
  line's id here, so every reader who decorates the line as it arrives finds
  the card already attached. The hook's return value is ignored.
  """
  @spec before_broadcast(keyword(), integer()) :: :ok
  def before_broadcast(opts, message_id) do
    case Keyword.get(opts, :before_broadcast) do
      fun when is_function(fun, 1) -> _ignored = fun.(message_id)
      _none -> :ok
    end

    :ok
  end
end
