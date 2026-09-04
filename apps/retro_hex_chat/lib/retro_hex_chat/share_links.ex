defmodule RetroHexChat.ShareLinks do
  @moduledoc """
  Public API for share links: one opaque, revocable address per surface.

  A link names a room and never grants access to one. Following it resolves to
  what the room is; the surface then applies its own policy to whoever is
  asking. That separation is why the slug can be posted anywhere — it carries no
  secret, only a name nobody can guess.

  Why not point straight at the room's own token: it would tie a public URL to a
  database column, it could not be closed without closing the room, and a space
  has no token at all — it is a channel name or a direct-message key, neither of
  which belongs in an address bar.
  """

  alias RetroHexChat.ShareLinks.{Card, Schema, Service}

  @type resolution :: Service.resolution()

  @spec create(map()) ::
          {:ok, Schema.Link.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  defdelegate create(attrs), to: Service

  @doc """
  The live link this person already has for this exact thing, or `nil`.

  `create/1` hands back the same link rather than minting a second one, so a
  caller cannot tell from its answer whether the address is new. A screen that
  posts a card needs to: a link that already exists was already announced, and
  announcing it again would put a second card in the conversation for one room.
  """
  @spec find_open(String.t(), map(), integer()) :: Schema.Link.t() | nil
  defdelegate find_open(kind, target, creator_id), to: Service

  @doc """
  The live link for this thing, whoever minted it, and a way to sharpen it.

  A space's door is posted by whoever pressed the entry; the gathering inside it
  is started by whoever walks in first, and they are rarely the same person. So
  the second one finds the card that is already in the conversation and points
  it at the gathering, rather than putting a second door beside it.
  """
  @spec find_open_for_target(String.t(), map()) :: Schema.Link.t() | nil
  defdelegate find_open_for_target(kind, target), to: Service

  @spec retarget(Schema.Link.t(), map()) ::
          {:ok, Schema.Link.t()} | {:error, Ecto.Changeset.t()}
  defdelegate retarget(link, target), to: Service

  @spec resolve(term()) :: {:ok, resolution()} | {:error, :not_found | :revoked | :expired}
  defdelegate resolve(slug), to: Service

  @spec describe(term()) :: {:ok, resolution()} | {:error, :not_found | :revoked | :expired}
  defdelegate describe(slug), to: Service

  @spec describe_many([term()]) :: %{String.t() => Card.t()}
  defdelegate describe_many(slugs), to: Service

  @spec revoke(term(), String.t()) ::
          {:ok, Schema.Link.t()} | {:error, :not_found | :unauthorized}
  defdelegate revoke(slug, revoked_by), to: Service

  @spec kinds() :: [String.t()]
  defdelegate kinds(), to: Schema.Link
end
