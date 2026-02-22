defmodule RetroHexChat.Admin.AuditLogs do
  @moduledoc """
  Context for the append-only admin audit log.
  Fire-and-forget: failures are logged but never crash callers.
  """

  import Ecto.Query

  require Logger

  alias RetroHexChat.Admin.AuditLog
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

  @spec list(keyword()) :: [AuditLog.t()]
  def list(opts \\ []) do
    last = Keyword.get(opts, :last, 50)
    actor = Keyword.get(opts, :actor)
    action = Keyword.get(opts, :action)

    AuditLog
    |> maybe_filter_actor(actor)
    |> maybe_filter_action(action)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^last)
    |> Repo.all()
  end

  defp maybe_filter_actor(query, nil), do: query
  defp maybe_filter_actor(query, actor), do: where(query, [l], l.actor == ^actor)

  defp maybe_filter_action(query, nil), do: query
  defp maybe_filter_action(query, action), do: where(query, [l], l.action == ^action)
end
