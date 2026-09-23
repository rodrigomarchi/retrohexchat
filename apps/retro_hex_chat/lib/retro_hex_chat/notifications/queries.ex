defmodule RetroHexChat.Notifications.Queries do
  @moduledoc """
  The stored side of push notifications.

  Two jobs live here. One is bookkeeping: which browsers are subscribed, which
  of them have stopped answering, and when to stop trying. The other is the
  question asked on the hot path of every human channel message — *is there
  anybody this line should wake up?* — and that one is written as a single
  query on purpose. It runs far more often than it finds anything, so its cost
  when it finds nothing is the cost of the whole feature.
  """

  import Ecto.Query

  alias RetroHexChat.Chat.Schemas.ReconnectState
  alias RetroHexChat.Notifications.Schema.PushSubscription
  alias RetroHexChat.Repo

  # A push service that keeps answering with an error for this many attempts is
  # not coming back for this browser. Dropping the row is not data loss: the
  # page subscribes again the next time somebody opens it.
  @max_failures 5

  @doc "How many consecutive failures a subscription survives."
  @spec max_failures() :: pos_integer()
  def max_failures, do: @max_failures

  @doc """
  Remember a browser for `nickname`, replacing whatever was stored for the same
  endpoint.
  """
  @spec subscribe(String.t(), map()) :: {:ok, PushSubscription.t()} | {:error, Ecto.Changeset.t()}
  def subscribe(nickname, params) do
    attrs =
      params
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.put("owner_nickname", nickname)
      |> Map.put("failure_count", 0)

    %PushSubscription{}
    |> PushSubscription.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace, [:owner_nickname, :p256dh, :auth, :user_agent, :failure_count, :updated_at]},
      conflict_target: :endpoint,
      returning: true
    )
  end

  @doc "Forget one browser of `nickname`'s."
  @spec unsubscribe(String.t(), String.t()) :: :ok
  def unsubscribe(nickname, endpoint) do
    PushSubscription
    |> where([s], s.owner_nickname == ^nickname and s.endpoint == ^endpoint)
    |> Repo.delete_all()

    :ok
  end

  @doc "Every browser currently subscribed for `nickname`."
  @spec list_for(String.t()) :: [PushSubscription.t()]
  def list_for(nickname) do
    PushSubscription
    |> where([s], s.owner_nickname == ^nickname)
    |> order_by([s], asc: s.id)
    |> Repo.all()
  end

  @doc """
  The subscriptions a channel line should reach.

  `:tokens` are the shapes read off the text by
  `RetroHexChat.Notifications.Candidates`; `:except` is the author, who is never
  woken by their own message. A candidate qualifies when all three of these are
  true at once — the nickname is registered and subscribed, and the channel is
  one they were in when they last closed the chat.
  """
  @spec candidates_for_channel_message(String.t(), keyword()) :: [PushSubscription.t()]
  def candidates_for_channel_message(_channel_name, tokens: [], except: _except), do: []

  def candidates_for_channel_message(channel_name, opts) do
    tokens = opts |> Keyword.get(:tokens, []) |> Enum.map(&String.downcase/1) |> Enum.uniq()

    case tokens do
      [] ->
        []

      tokens ->
        except = opts |> Keyword.get(:except, "") |> String.downcase()

        # `exists` rather than a join: the question is whether the person had
        # this channel open on *some* browser, and they have one reconnect row
        # per browser. A join answers it once per row, which would hand the same
        # browser back twice and wake the same phone twice for one line.
        from(s in PushSubscription, as: :subscription)
        |> where([s], fragment("lower(?)", s.owner_nickname) in ^tokens)
        |> where([s], fragment("lower(?)", s.owner_nickname) != ^except)
        |> where(
          [s],
          exists(
            from(r in ReconnectState,
              where: r.owner_nickname == parent_as(:subscription).owner_nickname,
              where: fragment("? = ANY(?)", ^channel_name, r.channels),
              select: 1
            )
          )
        )
        |> order_by([s], asc: s.id)
        |> Repo.all()
    end
  end

  @doc "Note that a push went through, clearing whatever failures came before."
  @spec record_success(PushSubscription.t()) ::
          {:ok, PushSubscription.t()} | {:error, Ecto.Changeset.t()}
  def record_success(subscription) do
    subscription
    |> PushSubscription.changeset(%{failure_count: 0, last_success_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Note that a push failed, dropping the subscription once it has failed enough.
  """
  @spec record_failure(PushSubscription.t()) ::
          {:ok, PushSubscription.t() | :dropped} | {:error, Ecto.Changeset.t()}
  def record_failure(subscription) do
    count = subscription.failure_count + 1

    if count >= @max_failures do
      :ok = drop(subscription)
      {:ok, :dropped}
    else
      subscription
      |> PushSubscription.changeset(%{failure_count: count})
      |> Repo.update()
    end
  end

  @doc "Remove a subscription whose endpoint said it is gone for good."
  @spec drop(PushSubscription.t()) :: :ok
  def drop(subscription) do
    Repo.delete(subscription, stale_error_field: :id)
    :ok
  rescue
    Ecto.StaleEntryError -> :ok
  end
end
