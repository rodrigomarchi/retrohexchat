defmodule RetroHexChat.Admin.ServerBans do
  @moduledoc "Context for server-level ban management."
  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Query

  alias RetroHexChat.Admin.{BanCache, ServerBan}
  alias RetroHexChat.Repo

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

  @spec list_active_bans() :: [ServerBan.t()]
  def list_active_bans do
    from(b in ServerBan,
      where: b.active == true,
      order_by: [desc: b.inserted_at]
    )
    |> Repo.all()
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
