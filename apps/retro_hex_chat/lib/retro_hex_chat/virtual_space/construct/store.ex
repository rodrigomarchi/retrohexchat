defmodule RetroHexChat.VirtualSpace.Construct.Store do
  @moduledoc """
  Where a Construct's layout outlives its runtime.

  Read once, by the caller that starts the room, and written by the caller of
  each edit after the runtime has accepted it. The runtime never touches this
  module, for the same reason it never touches `VirtualSpace.Queries`: a world
  stepping avatars is no place for a query.
  """

  import Ecto.Query

  alias RetroHexChat.Repo
  alias RetroHexChat.VirtualSpace.Schema.Construct

  @type layout :: %{items: [map()], floor: String.t() | nil, revision: non_neg_integer()}

  @doc "The stored layout of a Construct; an empty room when nothing was built."
  @spec load(String.t()) :: layout()
  def load(space_id) when is_binary(space_id) do
    case Repo.get_by(Construct, space_id: space_id) do
      %Construct{items: items, floor: floor, revision: revision} ->
        %{items: items, floor: floor, revision: revision}

      nil ->
        %{items: [], floor: nil, revision: 0}
    end
  end

  @doc """
  Store a layout, unless a newer one is already stored.

  Two edits answered by the runtime in order can still reach the database out
  of order — each is written by the process of the person who made it — so the
  row only ever moves forward in `revision`.
  """
  @spec save(
          String.t(),
          %{
            required(:items) => [map()],
            required(:floor) => String.t() | nil,
            optional(atom()) => term()
          },
          non_neg_integer(),
          String.t() | nil
        ) ::
          :ok | {:error, Ecto.Changeset.t()}
  def save(space_id, %{items: items, floor: floor}, revision, nickname) do
    now = DateTime.utc_now()

    newer =
      from(c in Construct,
        where: c.revision < ^revision,
        update: [
          set: [
            items: ^items,
            floor: ^floor,
            revision: ^revision,
            updated_by_nick: ^nickname,
            updated_at: ^now
          ]
        ]
      )

    %Construct{}
    |> Construct.changeset(%{
      space_id: space_id,
      items: items,
      floor: floor,
      revision: revision,
      updated_by_nick: nickname
    })
    # A row already ahead makes the conditional update touch nothing, which Ecto
    # reports as stale; for this write that is the expected answer, not a fault.
    |> Repo.insert(on_conflict: newer, conflict_target: :space_id, allow_stale: true)
    |> case do
      {:ok, _construct} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end
end
