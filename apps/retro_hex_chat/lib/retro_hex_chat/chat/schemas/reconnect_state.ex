defmodule RetroHexChat.Chat.Schemas.ReconnectState do
  @moduledoc """
  Ecto schema for persisted chat reconnect snapshots.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  # A snapshot belongs to a nickname on one browser, so both halves are the key.
  # The empty browser id is a browser like any other: it is what a browser with
  # no cookie sends.
  @primary_key false
  schema "reconnect_states" do
    field :owner_nickname, :string, primary_key: true
    field :browser_id, :string, primary_key: true, default: ""
    field :channels, {:array, :string}, default: []
    field :active_channel, :string
    field :active_pm, :string
    field :open_pm_tabs, {:array, :string}, default: []
    field :welcomed_channels, {:array, :string}, default: []
    field :read_markers, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(reconnect_state, attrs) do
    reconnect_state
    |> cast(attrs, [
      :owner_nickname,
      :browser_id,
      :channels,
      :active_channel,
      :active_pm,
      :open_pm_tabs,
      :welcomed_channels,
      :read_markers
    ])
    |> validate_required([
      :owner_nickname,
      :channels,
      :open_pm_tabs,
      :welcomed_channels,
      :read_markers
    ])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:browser_id, max: 64)
    # A snapshot belongs to a registered nickname, and the owner can stop being
    # one between deciding to save and saving — a drop, an expiry, a nickname
    # that was never registered at all. Without this the write raises and takes
    # the mount with it, which is a much worse outcome than a session that has
    # to greet somebody twice.
    |> foreign_key_constraint(:owner_nickname,
      name: :reconnect_states_owner_nickname_fkey
    )
  end
end
