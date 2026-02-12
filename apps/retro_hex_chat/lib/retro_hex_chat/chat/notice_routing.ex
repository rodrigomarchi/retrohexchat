defmodule RetroHexChat.Chat.NoticeRouting do
  @moduledoc """
  Domain module for managing notice routing preferences.

  Provides in-memory CRUD operations on the routing preference map
  and persistence functions (save/2, load/1) for registered users.
  """

  alias RetroHexChat.Chat.Schemas.NoticeRoutingSetting
  alias RetroHexChat.Repo

  @valid_routings [:active, :status, :sender]

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{routing: :active}
  end

  @spec get_routing(map()) :: :active | :status | :sender
  def get_routing(%{routing: routing}), do: routing

  @spec set_routing(map(), atom()) :: map() | {:error, :invalid_routing}
  def set_routing(settings, routing) when routing in @valid_routings do
    %{settings | routing: routing}
  end

  def set_routing(_settings, _routing), do: {:error, :invalid_routing}

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, settings) do
    routing_string = Atom.to_string(settings.routing)

    case Repo.get(NoticeRoutingSetting, owner) do
      nil ->
        %NoticeRoutingSetting{}
        |> NoticeRoutingSetting.changeset(%{
          owner_nickname: owner,
          routing: routing_string
        })
        |> Repo.insert()

      existing ->
        existing
        |> NoticeRoutingSetting.changeset(%{routing: routing_string})
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    case Repo.get(NoticeRoutingSetting, owner) do
      nil ->
        {:error, :not_found}

      db_entry ->
        routing = String.to_existing_atom(db_entry.routing)
        {:ok, %{routing: routing}}
    end
  end
end
