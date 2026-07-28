defmodule RetroHexChat.Admin.ServerBans do
  @moduledoc "Context for server-level ban management."
  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Query

  alias RetroHexChat.Admin.{BanCache, ServerBan}
  alias RetroHexChat.Page
  alias RetroHexChat.Repo

  @default_page_size 50

  @spec ban(String.t(), String.t(), String.t() | nil, DateTime.t() | nil) ::
          {:ok, ServerBan.t()} | {:error, String.t()}
  def ban(nickname, banned_by, reason \\ nil, expires_at \\ nil) do
    attrs = %{
      nickname: nickname,
      banned_by: banned_by,
      reason: reason,
      expires_at: expires_at,
      active: true
    }

    case %ServerBan{} |> ServerBan.changeset(attrs) |> Repo.insert() do
      {:ok, ban} ->
        BanCache.add(nickname, expires_at)
        {:ok, ban}

      {:error, %Ecto.Changeset{errors: [{:nickname, _} | _]}} ->
        {:error, "#{nickname} is already banned"}

      {:error, _changeset} ->
        {:error, "Failed to ban #{nickname}"}
    end
  end

  @spec unban(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def unban(nickname) do
    query =
      from(b in ServerBan,
        where: b.nickname == ^nickname and b.active == true
      )

    case Repo.one(query) do
      nil ->
        {:error, "#{nickname} is not banned"}

      ban ->
        ban
        |> ServerBan.changeset(%{active: false})
        |> Repo.update()

        BanCache.remove(nickname)
        {:ok, dgettext("admin", "%{nickname} has been unbanned", nickname: nickname)}
    end
  end

  @spec banned?(String.t()) :: boolean()
  def banned?(nickname), do: BanCache.banned?(nickname)

  @doc """
  **Every** active ban, for the enforcement cache.

  Deliberately not paginated and deliberately not sharing a function with the
  admin listing: `BanCache` seeds the ETS table that decides whether a
  connection is refused, so a page of it would silently stop enforcing every ban
  past the page size.
  """
  @spec all_active_bans() :: [ServerBan.t()]
  def all_active_bans do
    from(b in ServerBan, where: b.active == true, order_by: [desc: b.id])
    |> Repo.all()
  end

  @doc """
  One page of the active server bans, newest first — for the admin listing.

  Ordered by id rather than `inserted_at`: bans are append-only, so id order is
  the same chronology and the cursor cannot tie or drift.
  """
  @spec list_active_bans(keyword()) :: Page.t()
  def list_active_bans(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_page_size)
    cursor = Keyword.get(opts, :cursor)

    from(b in ServerBan, where: b.active == true, order_by: [desc: b.id])
    |> then(&if cursor, do: where(&1, [b], b.id < ^cursor), else: &1)
    |> limit(^Page.limit_with_lookahead(limit))
    |> Repo.all()
    |> Page.new(limit, & &1.id)
  end

  @spec expire_bans() :: non_neg_integer()
  def expire_bans do
    now = DateTime.utc_now()

    query =
      from(b in ServerBan,
        where: b.active == true and not is_nil(b.expires_at) and b.expires_at <= ^now,
        select: b.nickname
      )

    nicknames = Repo.all(query)

    {count, _} =
      from(b in ServerBan,
        where: b.nickname in ^nicknames and b.active == true
      )
      |> Repo.update_all(set: [active: false])

    Enum.each(nicknames, &BanCache.remove/1)
    count
  end
end
