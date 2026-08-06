defmodule RetroHexChat.Chat.LinkPreview.Result do
  @moduledoc """
  Durable link preview fetch result.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @statuses ~w(pending ready failed)

  schema "link_previews" do
    field :url, :string
    field :url_hash, :string
    field :status, :string, default: "pending"
    field :title, :string
    field :metadata, :map, default: %{}
    field :error_reason, :string
    field :error_detail, :map, default: %{}
    field :attempts, :integer, default: 0
    field :last_attempted_at, :utc_datetime_usec
    field :fetched_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(result, attrs) do
    result
    |> cast(attrs, [
      :url,
      :url_hash,
      :status,
      :title,
      :metadata,
      :error_reason,
      :error_detail,
      :attempts,
      :last_attempted_at,
      :fetched_at,
      :expires_at
    ])
    |> validate_required([
      :url,
      :url_hash,
      :status,
      :metadata,
      :error_detail,
      :attempts,
      :expires_at
    ])
    |> validate_length(:url_hash, is: 64)
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_required_for_status()
    |> unique_constraint(:url_hash)
    |> check_constraint(:status, name: :link_previews_status_check)
    |> check_constraint(:attempts, name: :link_previews_attempts_non_negative)
  end

  defp validate_required_for_status(changeset) do
    case get_field(changeset, :status) do
      "ready" -> validate_required(changeset, [:title, :fetched_at])
      "failed" -> validate_required(changeset, [:error_reason, :fetched_at])
      _status -> changeset
    end
  end
end
