defmodule RetroHexChat.Admin.AuditLogs do
  @moduledoc """
  Context for the append-only admin audit log.
  Fire-and-forget: failures are logged but never crash callers.
  """

  import Ecto.Query

  require Logger

  alias RetroHexChat.Admin.AuditLog
  alias RetroHexChat.Page
  alias RetroHexChat.Repo

  @spec log(String.t(), String.t(), {String.t(), String.t()} | nil, map()) :: :ok
  def log(actor, action, target \\ nil, details \\ %{}) do
    {target_type, target_id} =
      case target do
        {type, id} -> {type, id}
        nil -> {nil, nil}
      end

    attrs = %{
      actor: actor,
      action: action,
      target_type: target_type,
      target_id: target_id,
      details: details
    }

    case %AuditLog{} |> AuditLog.changeset(attrs) |> Repo.insert() do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("AuditLogs.log failed: #{inspect(reason)}")
    end

    :ok
  rescue
    e ->
      Logger.warning("AuditLogs.log crashed: #{inspect(e)}")
      :ok
  end

  @doc """
  One page of the audit log, newest first.

  Ordered by id rather than `inserted_at`: the log is append-only, so id order is
  the same chronology and gives a cursor that cannot tie or drift.

  Accepts `:last` as a synonym for `:limit`, which is what the `/admin log`
  flag has always been called.
  """
  @spec list(keyword()) :: Page.t()
  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit) || Keyword.get(opts, :last, 50)
    cursor = Keyword.get(opts, :cursor)

    AuditLog
    |> maybe_filter_actor(Keyword.get(opts, :actor))
    |> maybe_filter_action(Keyword.get(opts, :action))
    |> then(&if cursor, do: where(&1, [l], l.id < ^cursor), else: &1)
    |> order_by([l], desc: l.id)
    |> limit(^Page.limit_with_lookahead(limit))
    |> Repo.all()
    |> Page.new(limit, & &1.id)
  end

  defp maybe_filter_actor(query, nil), do: query
  defp maybe_filter_actor(query, actor), do: where(query, [l], l.actor == ^actor)

  defp maybe_filter_action(query, nil), do: query
  defp maybe_filter_action(query, action), do: where(query, [l], l.action == ^action)
end
