defmodule RetroHexChat.Chat.Replies do
  @moduledoc """
  The quote a reply carries, read from the message it answers.

  A reply stores a copy of what it is answering — who wrote it and a short
  preview — so the row can be drawn without a second query, and so the quote
  survives its parent being edited or deleted (both rewrite the copy; see
  `Chat.Service`). Reading it is the same work in a channel and in a private
  conversation, and `Chat.Authorship` already answers the only question that
  differs.

  What to do when the parent is gone is **not** decided here, because the two
  callers genuinely disagree: sending a channel message drops the quote and
  sends anyway, while `Chat.Service` refuses. Returning `:not_found` puts that
  choice at the call site, where it is visible.

  ## A reply never has replies

  Answering a reply answers the conversation that reply belongs to, so the
  pointer and the quote both move up to the root — the message that answers
  nothing. That keeps `reply_to_id` readable as the thread it belongs to, which
  is what lets a thread be counted and listed without walking a chain, and it
  stops one line of disagreement from growing the two levels that make a forum.

  Lines written before this rule existed keep the parent they were given: they
  are still drawn with the quote they always had, and the thread they belong to
  simply does not claim them.
  """

  alias RetroHexChat.Chat.Authorship
  alias RetroHexChat.Chat.Content
  alias RetroHexChat.Chat.Queries

  @type kind :: :message | :pm

  @doc "The reply columns for a message answering `parent_id`, or `:not_found`."
  @spec attrs(kind(), integer() | nil) :: {:ok, map()} | :not_found
  def attrs(kind, parent_id) do
    with %{} = answered <- parent(kind, parent_id),
         %{} = root <- root(kind, answered) do
      {:ok,
       %{
         reply_to_id: root.id,
         reply_to_author: Authorship.author(root),
         reply_to_preview: Content.reply_preview(root)
       }}
    else
      nil -> :not_found
    end
  end

  @doc """
  The thread `message_id` belongs to: itself when it answers nothing.

  `nil` when there is no such message, which is the same answer `attrs/2` gives
  and for the same reason — the caller decides what a missing parent means.
  """
  @spec root_id(kind(), integer() | nil) :: integer() | nil
  def root_id(kind, message_id) do
    with %{} = message <- parent(kind, message_id),
         %{} = root <- root(kind, message) do
      root.id
    else
      nil -> nil
    end
  end

  defp root(_kind, %{reply_to_id: nil} = message), do: message
  defp root(kind, %{reply_to_id: id}), do: parent(kind, id)

  defp parent(:message, parent_id), do: Queries.get_message(parent_id)
  defp parent(:pm, parent_id), do: Queries.get_private_message(parent_id)
end
