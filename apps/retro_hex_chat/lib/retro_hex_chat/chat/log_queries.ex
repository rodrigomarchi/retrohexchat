defmodule RetroHexChat.Chat.LogQueries do
  @moduledoc """
  Database query functions for the Log Viewer.
  Provides offset-based paginated search across messages and private messages.
  """

  import Ecto.Query

  alias RetroHexChat.Chat.LogFilter
  alias RetroHexChat.Chat.LogPage
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Chat.PrivateMessage
  alias RetroHexChat.Repo

  @spec search_channel_log(LogFilter.t()) :: LogPage.t()
  def search_channel_log(%LogFilter{} = filter) do
    base = channel_base_query(filter)
    total = base |> select([m], count(m.id)) |> Repo.one()

    entries =
      base
      |> order_by([m], asc: m.inserted_at, asc: m.id)
      |> offset(^((filter.page - 1) * filter.per_page))
      |> limit(^filter.per_page)
      |> Repo.all()

    LogPage.new(entries, total, filter)
  end

  @spec search_pm_log(String.t(), LogFilter.t()) :: LogPage.t()
  def search_pm_log(current_nick, %LogFilter{} = filter) do
    base = pm_base_query(current_nick, filter)
    total = base |> select([pm], count(pm.id)) |> Repo.one()

    entries =
      base
      |> order_by([pm], asc: pm.inserted_at, asc: pm.id)
      |> offset(^((filter.page - 1) * filter.per_page))
      |> limit(^filter.per_page)
      |> Repo.all()

    LogPage.new(entries, total, filter)
  end

  @spec count_channel_log(LogFilter.t()) :: non_neg_integer()
  def count_channel_log(%LogFilter{} = filter) do
    channel_base_query(filter)
    |> select([m], count(m.id))
    |> Repo.one()
  end

  @spec count_pm_log(String.t(), LogFilter.t()) :: non_neg_integer()
  def count_pm_log(current_nick, %LogFilter{} = filter) do
    pm_base_query(current_nick, filter)
    |> select([pm], count(pm.id))
    |> Repo.one()
  end

  @spec list_user_channels(String.t()) :: [String.t()]
  def list_user_channels(nickname) do
    Message
    |> where([m], m.author_nickname == ^nickname)
    |> select([m], m.channel_name)
    |> distinct(true)
    |> order_by([m], asc: m.channel_name)
    |> Repo.all()
  end

  @spec list_user_pm_partners(String.t()) :: [String.t()]
  def list_user_pm_partners(nickname) do
    sent =
      PrivateMessage
      |> where([pm], pm.sender_nickname == ^nickname)
      |> select([pm], pm.recipient_nickname)

    received =
      PrivateMessage
      |> where([pm], pm.recipient_nickname == ^nickname)
      |> select([pm], pm.sender_nickname)

    union_query = union(sent, ^received)

    from(u in subquery(union_query), select: u.recipient_nickname, distinct: true)
    |> order_by([u], asc: u.recipient_nickname)
    |> Repo.all()
  end

  # Private helpers

  defp channel_base_query(%LogFilter{} = filter) do
    Message
    |> maybe_channel_source(filter.source)
    |> maybe_date_from(filter.date_from)
    |> maybe_date_to(filter.date_to)
    |> maybe_nickname_filter(filter.nickname, :author_nickname)
    |> maybe_text_filter(filter.text)
  end

  defp pm_base_query(current_nick, %LogFilter{} = filter) do
    partner = filter.source

    query =
      if partner do
        nick_a = Enum.min([current_nick, partner])
        nick_b = Enum.max([current_nick, partner])

        PrivateMessage
        |> where(
          [pm],
          fragment("least(?, ?)", pm.sender_nickname, pm.recipient_nickname) == ^nick_a
        )
        |> where(
          [pm],
          fragment("greatest(?, ?)", pm.sender_nickname, pm.recipient_nickname) == ^nick_b
        )
      else
        PrivateMessage
        |> where(
          [pm],
          pm.sender_nickname == ^current_nick or pm.recipient_nickname == ^current_nick
        )
      end

    query
    |> maybe_date_from(filter.date_from)
    |> maybe_date_to(filter.date_to)
    |> maybe_text_filter(filter.text)
  end

  defp maybe_channel_source(query, nil), do: query

  defp maybe_channel_source(query, source) do
    where(query, [m], m.channel_name == ^source)
  end

  defp maybe_date_from(query, nil), do: query

  defp maybe_date_from(query, date) do
    datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    where(query, [m], m.inserted_at >= ^datetime)
  end

  defp maybe_date_to(query, nil), do: query

  defp maybe_date_to(query, date) do
    next_day = Date.add(date, 1)
    datetime = DateTime.new!(next_day, ~T[00:00:00], "Etc/UTC")
    where(query, [m], m.inserted_at < ^datetime)
  end

  defp maybe_nickname_filter(query, nil, _field), do: query

  defp maybe_nickname_filter(query, nickname, :author_nickname) do
    pattern = "%" <> LogFilter.escape_text(nickname) <> "%"
    where(query, [m], ilike(m.author_nickname, ^pattern))
  end

  defp maybe_text_filter(query, nil), do: query

  defp maybe_text_filter(query, text) do
    pattern = "%" <> LogFilter.escape_text(text) <> "%"
    where(query, [m], ilike(m.content, ^pattern))
  end
end
