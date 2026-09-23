defmodule RetroHexChat.Notifications.Candidates do
  @moduledoc """
  Who a line of channel text could possibly be about.

  Everything else in the chat answers "who is in this channel" by asking the
  channel, and that answer is right for everything else: presence, moderation,
  the member list. It is useless here, because the whole point of a push is to
  reach somebody who is **not** there — and a person who is not there was
  removed from the membership when their last screen closed.

  So the text is the only evidence left of who a message was meant for, and
  this module turns it into a short, bounded list of shapes that could be a
  nickname. It does not know whether any of them is a person; that is a query's
  job. It only makes sure the query is asked about at most a handful of names,
  and never about the words inside a link.
  """

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Chat.Content
  alias RetroHexChat.Chat.Highlight

  # Everything a nickname may contain. Splitting on its complement is what turns
  # "hey @Bob," into "hey" and "Bob" without inventing a second nickname grammar
  # beside the validator's.
  @separators ~r/[^a-zA-Z0-9\[\]\\^_`{|}\-]+/

  # The one place the writer says out loud who they meant. Read first, so that a
  # long line does not spend the whole budget on the words in front of it.
  @addressed ~r/@([a-zA-Z\[\]\\^_{|}][a-zA-Z0-9\[\]\\^_`{|}\-]*)/

  # A ceiling, not an expectation. One line naming eight people is already a
  # crowd; a line naming forty is either a paste or an attack, and either way it
  # must not turn into forty lookups.
  @max_tokens 8

  # One letter is a word in too many languages to be worth a lookup, and a
  # nickname that short is not how anyone is addressed.
  @min_length 2

  @doc """
  The nicknames `content` could be addressing, in the order they were written.

  Case is preserved because it is what the notification will show, and a
  nickname repeated in three casings is still one person.
  """
  @spec nick_tokens(String.t(), Content.format_input()) :: [String.t()]
  def nick_tokens(content, content_format \\ :irc)

  def nick_tokens("", _content_format), do: []

  def nick_tokens(content, content_format) when is_binary(content) do
    plain = content |> visible_text(content_format) |> Highlight.mask_urls()

    (addressed(plain) ++ String.split(plain, @separators, trim: true))
    |> Enum.filter(&candidate?/1)
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.take(@max_tokens)
  end

  @spec addressed(String.t()) :: [String.t()]
  defp addressed(plain) do
    @addressed |> Regex.scan(plain) |> Enum.map(&List.last/1)
  end

  @spec visible_text(String.t(), Content.format_input()) :: String.t()
  defp visible_text(content, content_format) do
    case Content.normalize_format(content_format) do
      {:ok, normalized} -> Content.plain_text(content, normalized)
      :error -> Content.plain_text(content, :irc)
    end
  end

  @spec candidate?(String.t()) :: boolean()
  defp candidate?(token) do
    String.length(token) >= @min_length and NicknameValidator.valid?(token)
  end
end
