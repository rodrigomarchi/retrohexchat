defmodule RetroHexChat.Chat.Authorship do
  @moduledoc """
  Who wrote a message, whichever kind of conversation it was written in.

  The two message tables name their writer differently — a channel message has
  an `author_nickname`, a private message a `sender_nickname` — and every rule
  that cares who wrote something had to translate before it could ask. The
  translation was performed three times, twice in the domain and once in the web
  layer, and each site had to know which kind of message it was holding in order
  to rename a field.

  Asking here instead means a rule about authorship is written once and holds
  for both. Anything that states neither name has no author rather than a
  missing one, so a rule comparing against a nickname refuses instead of
  matching by accident.
  """

  @doc """
  The nickname of whoever wrote this message, or `nil` if it states no author.

  Accepts the schema structs and the plain maps the web layer carries, which is
  what lets one rule serve a persisted row and a broadcast payload alike.
  """
  @spec author(term()) :: String.t() | nil
  def author(%{author_nickname: nickname}) when is_binary(nickname), do: nickname
  def author(%{sender_nickname: nickname}) when is_binary(nickname), do: nickname
  def author(%{author: nickname}) when is_binary(nickname), do: nickname
  def author(%{sender: nickname}) when is_binary(nickname), do: nickname
  def author(_message), do: nil

  @doc """
  Whether the given nickname wrote this message.

  A message with no author is written by nobody, so this is false rather than a
  comparison against `nil`.
  """
  @spec written_by?(term(), String.t()) :: boolean()
  def written_by?(message, nickname) when is_binary(nickname) do
    author(message) == nickname
  end

  def written_by?(_message, _nickname), do: false
end
