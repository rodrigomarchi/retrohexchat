defmodule RetroHexChat.Chat.Search do
  @moduledoc "Full-text search for chat messages."

  import Ecto.Query

  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Repo

  @default_limit 50

  @spec search_messages(String.t(), String.t(), keyword()) :: [Message.t()]
  def search_messages(channel_name, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    pattern = "%#{sanitize(query)}%"

    Message
    |> where([m], m.channel_name == ^channel_name)
    |> where([m], ilike(m.content, ^pattern))
    |> order_by([m], desc: m.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @spec count_matches(String.t(), String.t()) :: non_neg_integer()
  def count_matches(channel_name, query) do
    pattern = "%#{sanitize(query)}%"

    Message
    |> where([m], m.channel_name == ^channel_name)
    |> where([m], ilike(m.content, ^pattern))
    |> Repo.aggregate(:count)
  end

  defp sanitize(query) do
    query
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
