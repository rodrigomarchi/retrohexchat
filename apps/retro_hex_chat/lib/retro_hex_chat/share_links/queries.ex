defmodule RetroHexChat.ShareLinks.Queries do
  @moduledoc """
  Database access for share links.

  Every read is by slug, which is the only thing the public route knows and the
  only indexed lookup this context needs.
  """

  import Ecto.Query

  alias RetroHexChat.Repo
  alias RetroHexChat.ShareLinks.Schema.Link

  @spec insert_link(map()) :: {:ok, Link.t()} | {:error, Ecto.Changeset.t()}
  def insert_link(attrs) do
    %Link{}
    |> Link.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_by_slug(String.t()) :: Link.t() | nil
  def get_by_slug(slug), do: Repo.get_by(Link, slug: slug)

  @doc """
  This person's still-open link to exactly this thing, if they already have one.

  The comparison on `target` is jsonb equality, which is what makes "the same
  room" a database question rather than a hopeful one: key order does not
  matter, and a target that differs by a single field is a different link.

  Newest first, because a race can leave two: two clicks arriving together both
  miss this read and both insert. That is worth an index only if it ever
  happens, and its cost is one spare row rather than the unbounded pile that
  minting-per-click produced.
  """
  @spec find_open(String.t(), map(), integer(), DateTime.t()) :: Link.t() | nil
  def find_open(kind, target, creator_id, now \\ DateTime.utc_now()) do
    Link
    |> where([l], l.kind == ^kind and l.creator_id == ^creator_id)
    |> where([l], l.target == ^target)
    |> where([l], is_nil(l.revoked_at))
    |> where([l], is_nil(l.expires_at) or l.expires_at > ^now)
    |> order_by([l], desc: l.inserted_at, desc: l.id)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Every link named by `slugs`, in one query.

  A screenful of chat can carry a dozen share links, and asking per message is
  how a conversation's render turns into a dozen round trips.
  """
  @spec list_by_slugs([String.t()]) :: [Link.t()]
  def list_by_slugs([]), do: []

  def list_by_slugs(slugs) do
    Link
    |> where([l], l.slug in ^slugs)
    |> Repo.all()
  end

  @spec revoke(Link.t(), String.t()) :: {:ok, Link.t()} | {:error, Ecto.Changeset.t()}
  def revoke(link, revoked_by) do
    link
    |> Link.revoke_changeset(%{revoked_at: DateTime.utc_now(), revoked_by: revoked_by})
    |> Repo.update()
  end

  @doc """
  Records that someone followed the link.

  An `update_all` rather than a read-modify-write: two people opening the same
  link at once would otherwise each write the count they read, and one of the
  two visits would vanish. Nothing waits on the result.
  """
  @spec record_resolution(String.t()) :: :ok
  def record_resolution(slug) do
    Link
    |> where([l], l.slug == ^slug)
    |> Repo.update_all(
      inc: [resolve_count: 1],
      set: [last_resolved_at: DateTime.utc_now()]
    )

    :ok
  end
end
