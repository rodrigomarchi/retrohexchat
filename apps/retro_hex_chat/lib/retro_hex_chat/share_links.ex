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

  alias RetroHexChat.ShareLinks.{Schema, Service, Slug}

  @type resolution :: Service.resolution()

  @spec create(map()) :: {:ok, Schema.Link.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create(attrs), to: Service

  @spec resolve(term()) :: {:ok, resolution()} | {:error, :not_found | :revoked | :expired}
  defdelegate resolve(slug), to: Service

  @spec describe(term()) :: {:ok, resolution()} | {:error, :not_found | :revoked | :expired}
  defdelegate describe(slug), to: Service

  @spec describe_many([term()]) :: %{String.t() => resolution()}
  defdelegate describe_many(slugs), to: Service

  @spec revoke(term(), String.t()) :: {:ok, Schema.Link.t()} | {:error, :not_found}
  defdelegate revoke(slug, revoked_by), to: Service

  @spec kinds() :: [String.t()]
  defdelegate kinds(), to: Schema.Link

  @doc "The slug generator, exposed for callers that validate before looking up."
  @spec slug_module() :: module()
  def slug_module, do: Slug
end
