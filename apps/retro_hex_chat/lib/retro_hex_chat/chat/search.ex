defmodule RetroHexChat.Chat.Search do
  @moduledoc "Full-text search for chat messages."

  import Ecto.Query

  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Repo

  @default_limit 50

  @spec search_messages(String.t(), String.t(), keyword()) :: [Message.t()]
  def search_messages(channel_name, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    Message
    |> where([m], m.channel_name == ^channel_name)
    |> apply_content_filter(query, opts)
    |> apply_nick_filter(opts)
    |> apply_mention_filter(opts)
    |> order_by([m], desc: m.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @spec count_matches(String.t(), String.t(), keyword()) :: non_neg_integer()
  def count_matches(channel_name, query, opts \\ []) do
    Message
    |> where([m], m.channel_name == ^channel_name)
    |> apply_content_filter(query, opts)
    |> apply_nick_filter(opts)
    |> apply_mention_filter(opts)
    |> Repo.aggregate(:count)
  end

  @spec valid_regex?(String.t()) :: boolean()
  def valid_regex?(pattern) do
    case Regex.compile(pattern) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # -- Private helpers -------------------------------------------------------

  defp apply_content_filter(queryable, query, opts) do
    case {Keyword.get(opts, :regex, false), Keyword.get(opts, :case_sensitive, false)} do
      {true, true} ->
        where(queryable, [m], fragment("? ~ ?", m.content, ^query))

      {true, false} ->
        where(queryable, [m], fragment("? ~* ?", m.content, ^query))

      {false, true} ->
        pattern = "%#{sanitize(query)}%"
        where(queryable, [m], like(m.content, ^pattern))

      {false, false} ->
        pattern = "%#{sanitize(query)}%"
        where(queryable, [m], ilike(m.content, ^pattern))
    end
  end

  defp apply_nick_filter(queryable, opts) do
    case Keyword.get(opts, :nick_filter) do
      nil -> queryable
      nick -> where(queryable, [m], m.author_nickname == ^nick)
    end
  end

  defp apply_mention_filter(queryable, opts) do
    case Keyword.get(opts, :mention_nick) do
      nil ->
        queryable

      nick ->
        pattern = "%#{sanitize(nick)}%"
        where(queryable, [m], ilike(m.content, ^pattern))
    end
  end

  defp sanitize(query) do
    query
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
