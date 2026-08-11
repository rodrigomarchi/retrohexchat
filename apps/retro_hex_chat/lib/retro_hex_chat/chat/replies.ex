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
  """

  alias RetroHexChat.Chat.Authorship
  alias RetroHexChat.Chat.Content
  alias RetroHexChat.Chat.Queries

  @type kind :: :message | :pm

  @doc "The reply columns for a message answering `parent_id`, or `:not_found`."
  @spec attrs(kind(), integer() | nil) :: {:ok, map()} | :not_found
  def attrs(kind, parent_id) do
    case parent(kind, parent_id) do
      nil ->
        :not_found

      parent ->
        {:ok,
         %{
           reply_to_id: parent.id,
           reply_to_author: Authorship.author(parent),
           reply_to_preview: Content.reply_preview(parent)
         }}
    end
  end

  defp parent(:message, parent_id), do: Queries.get_message(parent_id)
  defp parent(:pm, parent_id), do: Queries.get_private_message(parent_id)
end
