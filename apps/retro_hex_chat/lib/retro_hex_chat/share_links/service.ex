defmodule RetroHexChat.ShareLinks.Service do
  @moduledoc """
  Minting, resolving and closing share links.

  Resolution is the operation everything else exists for, and it answers with
  the facts of the link plus whether the thing it names is still there. It does
  not answer whether the person asking may enter — that is the surface's
  question, asked with the surface's own policy, and keeping the two apart is
  what stops a link from becoming a way in.
  """

  alias RetroHexChat.ShareLinks.{Liveness, Queries, Slug}
  alias RetroHexChat.ShareLinks.Schema.Link

  @type resolution :: %{
          slug: String.t(),
          kind: String.t(),
          target: map(),
          creator_nick: String.t(),
          live?: boolean()
        }

  @doc """
  Mints a link for `attrs`, which must carry a `kind`, a `target` and a creator.

  The slug is generated here rather than supplied: a caller that chose its own
  would eventually choose a guessable one.
  """
  @spec create(map()) :: {:ok, Link.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs
    |> Map.put(:slug, Slug.generate())
    |> Queries.insert_link()
  end

  @doc """
  What `slug` points at, or why it does not point anywhere any more.

  A slug that could not have been generated never reaches the database — it is
  `:not_found` by shape, which is also the answer a stranger gets for a link
  that exists and one that does not.
  """
  @spec resolve(term()) ::
          {:ok, resolution()} | {:error, :not_found | :revoked | :expired}
  def resolve(slug) do
    with true <- Slug.valid?(slug),
         %Link{} = link <- Queries.get_by_slug(slug),
         :ok <- check_open(link) do
      Queries.record_resolution(link.slug)

      {:ok,
       %{
         slug: link.slug,
         kind: link.kind,
         target: link.target,
         creator_nick: link.creator_nick,
         live?: Liveness.live?(link.kind, link.target)
       }}
    else
      false -> {:error, :not_found}
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Closes the link, leaving the room it names untouched.

  Revoking an already-revoked link succeeds: the caller asked for it to be
  closed, and it is.
  """
  @spec revoke(term(), String.t()) :: {:ok, Link.t()} | {:error, :not_found}
  def revoke(slug, revoked_by) do
    with true <- Slug.valid?(slug),
         %Link{} = link <- Queries.get_by_slug(slug) do
      case link.revoked_at do
        nil -> Queries.revoke(link, revoked_by)
        _already -> {:ok, link}
      end
    else
      _other -> {:error, :not_found}
    end
  end

  defp check_open(%Link{revoked_at: %DateTime{}}), do: {:error, :revoked}

  defp check_open(%Link{expires_at: %DateTime{} = expires_at}) do
    if DateTime.after?(DateTime.utc_now(), expires_at), do: {:error, :expired}, else: :ok
  end

  defp check_open(%Link{}), do: :ok
end
