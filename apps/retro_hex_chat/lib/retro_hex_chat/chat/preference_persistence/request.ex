defmodule RetroHexChat.Chat.PreferencePersistence.Request do
  @moduledoc """
  Latest pending durable preference/list snapshot for a registered user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @statuses ~w(pending processing applied failed)
  @preference_types ~w(
    notify_list
    contacts
    nick_colors
    highlight_words
    ignore_list
    perform_list
    autojoin_list
    input_history
    aliases
    custom_menus
    autorespond_rules
    flood_protection
    sound_settings
  )

  schema "preference_save_requests" do
    field :owner_nickname, :string
    field :preference_type, :string
    field :payload, :map, default: %{}
    field :payload_size_bytes, :integer, default: 0
    field :status, :string, default: "pending"
    field :revision, :integer, default: 1
    field :applied_revision, :integer, default: 0
    field :attempts, :integer, default: 0
    field :last_attempted_at, :utc_datetime_usec
    field :last_error, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :owner_nickname,
      :preference_type,
      :payload,
      :payload_size_bytes,
      :status,
      :revision,
      :applied_revision,
      :attempts,
      :last_attempted_at,
      :last_error
    ])
    |> validate_required([
      :owner_nickname,
      :preference_type,
      :payload,
      :payload_size_bytes,
      :status,
      :revision,
      :applied_revision,
      :attempts
    ])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_inclusion(:preference_type, @preference_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:payload_size_bytes, greater_than_or_equal_to: 0)
    |> validate_number(:revision, greater_than: 0)
    |> validate_number(:applied_revision, greater_than_or_equal_to: 0)
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
    |> validate_revision_order()
    |> unique_constraint([:owner_nickname, :preference_type])
    |> check_constraint(:status, name: :preference_save_requests_status_check)
    |> check_constraint(:payload_size_bytes,
      name: :preference_save_requests_payload_size_non_negative
    )
    |> check_constraint(:revision, name: :preference_save_requests_revision_positive)
    |> check_constraint(:applied_revision,
      name: :preference_save_requests_applied_revision_valid
    )
    |> check_constraint(:attempts, name: :preference_save_requests_attempts_non_negative)
  end

  defp validate_revision_order(changeset) do
    revision = get_field(changeset, :revision)
    applied_revision = get_field(changeset, :applied_revision)

    if is_integer(revision) and is_integer(applied_revision) and applied_revision > revision do
      add_error(changeset, :applied_revision, "must be less than or equal to revision")
    else
      changeset
    end
  end
end
