defmodule RetroHexChat.ShareLinks.Schema.Link do
  @moduledoc """
  Ecto schema for `share_links` — one shareable address for one surface.

  A link names a room; it never grants access to one. Following it resolves to
  what the room is, and the surface then applies its own policy to whoever is
  asking. That is why nothing here is signed and nothing here is secret: the
  slug is opaque so it cannot be guessed, not so it cannot be read.

  `kind` decides which surface the slug resolves to and `target` carries what
  that surface needs to find its room. The pair is validated here so a resolver
  never has to handle a kind it has no clause for.

  A link outlives its room on purpose. `revoked_at` closes a link without
  closing what it points at, and `resolve_count` is the number that answers
  whether sharing a link actually brings anyone.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias RetroHexChat.ShareLinks.Slug

  @type t :: %__MODULE__{}

  @kinds ~w(call space p2p play)

  schema "share_links" do
    field :slug, :string
    field :kind, :string
    field :target, :map, default: %{}
    field :creator_id, :integer
    field :creator_nick, :string
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :revoked_by, :string
    field :resolve_count, :integer, default: 0
    field :last_resolved_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:slug, :kind, :target, :creator_id, :creator_nick, :expires_at])
    |> update_change(:target, &(&1 || %{}))
    |> validate_required([:slug, :kind, :creator_id, :creator_nick])
    |> validate_inclusion(:kind, @kinds)
    |> validate_length(:creator_nick, max: 16)
    |> validate_slug()
    |> unique_constraint(:slug)
  end

  @doc """
  Closes a link without touching what it points at.

  `revoked_by` is required alongside the timestamp: a revocation with no hand on
  it is an audit record that answers the wrong half of the question.
  """
  @spec revoke_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def revoke_changeset(link, attrs) do
    link
    |> cast(attrs, [:revoked_at, :revoked_by])
    |> validate_required([:revoked_at, :revoked_by])
    |> validate_length(:revoked_by, max: 16)
  end

  @spec kinds() :: [String.t()]
  def kinds, do: @kinds

  defp validate_slug(changeset) do
    validate_change(changeset, :slug, fn :slug, slug ->
      if Slug.valid?(slug), do: [], else: [slug: "is not a share slug"]
    end)
  end
end
