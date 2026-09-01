defmodule RetroHexChat.ShareLinks.Service do
  @moduledoc """
  Minting, resolving and closing share links.

  Resolution is the operation everything else exists for, and it answers with
  the facts of the link plus whether the thing it names is still there. It does
  not answer whether the person asking may enter — that is the surface's
  question, asked with the surface's own policy, and keeping the two apart is
  what stops a link from becoming a way in.
  """

  alias RetroHexChat.ShareLinks.{Card, Liveness, Policy, Queries, Slug}
  alias RetroHexChat.ShareLinks.Schema.Link

  @type resolution :: %{
          slug: String.t(),
          kind: String.t(),
          target: map(),
          creator_nick: String.t(),
          live?: boolean()
        }

  @doc """
  The person's link to this thing — the one they already have, or a new one.

  Minting is idempotent per `{kind, target, creator}` on purpose. Sharing is a
  button, and a button gets pressed twice: once because the first press was not
  obviously acknowledged, once after a reload put the screen back without the
  address on it. Each press used to mint another slug, all of them live, none of
  them countable — so "revoke the link" was never a whole sentence, because
  revoking one left the siblings working and nobody knew how many there were.

  Returning the existing link makes revocation mean something and makes
  `resolve_count` mean something too: one address per person per room, and the
  number under it is how many people followed *it*.

  The slug is generated here rather than supplied: a caller that chose its own
  would eventually choose a guessable one.
  """
  @spec create(map()) ::
          {:ok, Link.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def create(attrs) do
    kind = Map.get(attrs, :kind) || Map.get(attrs, "kind")
    target = Map.get(attrs, :target) || Map.get(attrs, "target") || %{}
    creator_id = Map.get(attrs, :creator_id) || Map.get(attrs, "creator_id")

    with :ok <- Policy.can_create?(to_string(kind), creator_id) do
      case Queries.find_open(to_string(kind), target, creator_id) do
        %Link{} = existing ->
          {:ok, existing}

        nil ->
          attrs
          |> Map.put(:slug, Slug.generate())
          |> Queries.insert_link()
      end
    end
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
    case describe(slug) do
      {:ok, resolution} ->
        Queries.record_resolution(resolution.slug)
        {:ok, resolution}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  The same answer as `resolve/1`, without counting a visit.

  Drawing a card for a link that appears in a conversation is not somebody
  following it. If the two shared a function, a busy channel would inflate the
  one number that says whether sharing links actually brings anyone.
  """
  @spec describe(term()) ::
          {:ok, resolution()} | {:error, :not_found | :revoked | :expired}
  def describe(slug) do
    with true <- Slug.valid?(slug),
         %Link{} = link <- Queries.get_by_slug(slug),
         :ok <- check_open(link) do
      {:ok, resolution(link)}
    else
      false -> {:error, :not_found}
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  A card for every slug that names a link at all, keyed by slug.

  Malformed and unknown slugs are absent — there is nothing to draw for an
  address this app never minted. A **closed** one is present, and that is the
  correction: filtering revoked and expired links out here did not grey the card
  out, it made the card vanish and left a bare address under a message that once
  explained itself. A link that was closed is a thing that happened, and the
  card is the only place the history says so.
  """
  @spec describe_many([term()]) :: %{String.t() => Card.t()}
  def describe_many(slugs) do
    slugs
    |> Enum.filter(&Slug.valid?/1)
    |> Enum.uniq()
    |> Queries.list_by_slugs()
    |> Map.new(&{&1.slug, Card.of(&1)})
  end

  @doc """
  Closes the link, leaving the room it names untouched.

  Asked of the person doing it, not merely stamped with their name: the creator
  may close their own, and so may an operator of the channel the link leads
  into, because an address people keep arriving through is that channel's
  business. `RetroHexChat.ShareLinks.Policy` holds both halves.

  Revoking an already-revoked link succeeds: the caller asked for it to be
  closed, and it is.
  """
  @spec revoke(term(), String.t()) :: {:ok, Link.t()} | {:error, :not_found | :unauthorized}
  def revoke(slug, revoked_by) do
    with true <- Slug.valid?(slug),
         %Link{} = link <- Queries.get_by_slug(slug),
         :ok <- Policy.can_revoke?(link, revoked_by) do
      case link.revoked_at do
        nil -> Queries.revoke(link, revoked_by)
        _already -> {:ok, link}
      end
    else
      {:error, :unauthorized} -> {:error, :unauthorized}
      _other -> {:error, :not_found}
    end
  end

  defp resolution(%Link{} = link) do
    %{
      slug: link.slug,
      kind: link.kind,
      target: link.target,
      creator_nick: link.creator_nick,
      live?: Liveness.live?(link.kind, link.target)
    }
  end

  defp check_open(%Link{revoked_at: %DateTime{}}), do: {:error, :revoked}

  defp check_open(%Link{expires_at: %DateTime{} = expires_at}) do
    if DateTime.after?(DateTime.utc_now(), expires_at), do: {:error, :expired}, else: :ok
  end

  defp check_open(%Link{}), do: :ok
end
