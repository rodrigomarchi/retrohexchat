defmodule RetroHexChat.Chat.Search do
  @moduledoc """
  Searching history, and the one saved search the product asks on its own.

  The history search counts matches and highlights the ones already on screen;
  it has no result list because it does not need one.

  `list_mentions/3` does, and it is a list rather than a table on purpose.
  Storing mentions would mean deciding, at the moment every message is written,
  whether it mentions each of the people who might read it — which means
  loading everybody's highlight words on the hot path of every line. The
  question is asked rarely, by one person, about themselves, and the answer is
  already in the messages.
  """

  import Ecto.Query

  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Page
  alias RetroHexChat.Repo

  @spec count_matches(String.t(), String.t(), keyword()) :: non_neg_integer()
  def count_matches(channel_name, query, opts \\ []) do
    Message
    |> where([m], m.channel_name == ^channel_name)
    |> apply_content_filter(query, opts)
    |> apply_nick_filter(opts)
    |> apply_mention_filter(opts)
    |> Repo.aggregate(:count)
  end

  @default_limit 50

  # What a person writes and what a person does. Everything else on the list —
  # system, service, error, notice — is the room narrating itself, and it names
  # people constantly.
  @mentionable_types ~w(message action)

  @doc """
  The messages in `channels` that name `nick`, newest first.

  Your own lines never count: writing your own nickname is not somebody
  reaching for you. Neither does a deleted line, nor anything the room said
  about itself.
  """
  @spec list_mentions(String.t(), [String.t()], keyword()) :: Page.t()
  def list_mentions(nick, channels, opts \\ [])

  def list_mentions(_nick, [], _opts), do: %Page{}

  def list_mentions(nick, channels, opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    pattern = "%#{sanitize(nick)}%"

    Message
    |> where([m], m.channel_name in ^channels)
    |> where([m], m.type in @mentionable_types)
    |> where([m], is_nil(m.deleted_at))
    |> where([m], fragment("lower(?)", m.author_nickname) != ^String.downcase(nick))
    |> where([m], ilike(fragment("coalesce(?, ?)", m.plain_content, m.content), ^pattern))
    |> maybe_before(Keyword.get(opts, :cursor))
    |> order_by(desc: :id)
    |> limit(^Page.limit_with_lookahead(limit))
    |> Repo.all()
    |> Page.new(limit, & &1.id)
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
        where(queryable, [m], fragment("coalesce(?, ?) ~ ?", m.plain_content, m.content, ^query))

      {true, false} ->
        where(queryable, [m], fragment("coalesce(?, ?) ~* ?", m.plain_content, m.content, ^query))

      {false, true} ->
        pattern = "%#{sanitize(query)}%"

        where(
          queryable,
          [m],
          like(fragment("coalesce(?, ?)", m.plain_content, m.content), ^pattern)
        )

      {false, false} ->
        pattern = "%#{sanitize(query)}%"

        where(
          queryable,
          [m],
          ilike(fragment("coalesce(?, ?)", m.plain_content, m.content), ^pattern)
        )
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

        where(
          queryable,
          [m],
          ilike(fragment("coalesce(?, ?)", m.plain_content, m.content), ^pattern)
        )
    end
  end

  defp maybe_before(queryable, nil), do: queryable
  defp maybe_before(queryable, cursor), do: where(queryable, [m], m.id < ^cursor)

  defp sanitize(query) do
    query
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
