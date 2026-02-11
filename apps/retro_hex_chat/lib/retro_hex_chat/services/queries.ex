defmodule RetroHexChat.Services.Queries do
  @moduledoc "Database queries for NickServ and ChanServ services."

  import Ecto.Query

  alias RetroHexChat.Repo
  alias RetroHexChat.Services.AccessListEntry
  alias RetroHexChat.Services.Ban
  alias RetroHexChat.Services.BanException
  alias RetroHexChat.Services.InviteException
  alias RetroHexChat.Services.RegisteredChannel
  alias RetroHexChat.Services.RegisteredNick

  # ── Nick functions ──────────────────────────────────────────

  @spec insert_registered_nick(String.t(), String.t()) ::
          {:ok, RegisteredNick.t()} | {:error, Ecto.Changeset.t()}
  def insert_registered_nick(nickname, password) do
    %RegisteredNick{}
    |> RegisteredNick.registration_changeset(%{nickname: nickname, password: password})
    |> Repo.insert()
  end

  @spec find_by_nickname(String.t()) :: RegisteredNick.t() | nil
  def find_by_nickname(nickname) do
    Repo.get_by(RegisteredNick, nickname: nickname)
  end

  @spec delete_registered_nick(RegisteredNick.t()) ::
          {:ok, RegisteredNick.t()} | {:error, Ecto.Changeset.t()}
  def delete_registered_nick(%RegisteredNick{} = nick) do
    Repo.delete(nick)
  end

  @spec update_last_seen(RegisteredNick.t()) ::
          {:ok, RegisteredNick.t()} | {:error, Ecto.Changeset.t()}
  def update_last_seen(%RegisteredNick{} = nick) do
    nick
    |> RegisteredNick.changeset(%{last_seen_at: DateTime.utc_now()})
    |> Repo.update()
  end

  # ── Channel registration ────────────────────────────────────

  @spec insert_registered_channel(String.t(), String.t()) ::
          {:ok, RegisteredChannel.t()} | {:error, Ecto.Changeset.t()}
  def insert_registered_channel(name, founder_nickname) do
    %RegisteredChannel{}
    |> RegisteredChannel.changeset(%{name: name, founder_nickname: founder_nickname})
    |> Repo.insert()
  end

  @spec find_registered_channel(String.t()) :: RegisteredChannel.t() | nil
  def find_registered_channel(name) do
    Repo.get_by(RegisteredChannel, name: name)
  end

  @spec delete_registered_channel(RegisteredChannel.t()) ::
          {:ok, RegisteredChannel.t()} | {:error, Ecto.Changeset.t()}
  def delete_registered_channel(%RegisteredChannel{} = channel) do
    Repo.delete(channel)
  end

  # ── Access list ─────────────────────────────────────────────

  @spec add_access(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, AccessListEntry.t()} | {:error, Ecto.Changeset.t()}
  def add_access(channel_name, nickname, level, added_by) do
    %AccessListEntry{}
    |> AccessListEntry.changeset(%{
      channel_name: channel_name,
      nickname: nickname,
      level: level,
      added_by: added_by
    })
    |> Repo.insert()
  end

  @spec remove_access(String.t(), String.t()) :: :ok | {:error, :not_found}
  def remove_access(channel_name, nickname) do
    from(a in AccessListEntry,
      where: a.channel_name == ^channel_name and a.nickname == ^nickname
    )
    |> Repo.delete_all()
    |> case do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  @spec list_access(String.t()) :: [AccessListEntry.t()]
  def list_access(channel_name) do
    from(a in AccessListEntry,
      where: a.channel_name == ^channel_name,
      order_by: a.level
    )
    |> Repo.all()
  end

  @spec find_access(String.t(), String.t()) :: AccessListEntry.t() | nil
  def find_access(channel_name, nickname) do
    from(a in AccessListEntry,
      where: a.channel_name == ^channel_name and a.nickname == ^nickname
    )
    |> Repo.one()
  end

  # ── Bans ────────────────────────────────────────────────────

  @spec add_ban(String.t(), String.t(), String.t()) ::
          {:ok, Ban.t()} | {:error, Ecto.Changeset.t()}
  def add_ban(channel_name, nickname, banned_by) do
    %Ban{}
    |> Ban.changeset(%{
      channel_name: channel_name,
      banned_nickname: nickname,
      banned_by: banned_by
    })
    |> Repo.insert()
  end

  @spec remove_ban(String.t(), String.t()) :: :ok | {:error, :not_found}
  def remove_ban(channel_name, nickname) do
    from(b in Ban,
      where: b.channel_name == ^channel_name and b.banned_nickname == ^nickname
    )
    |> Repo.delete_all()
    |> case do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  @spec list_bans(String.t()) :: [Ban.t()]
  def list_bans(channel_name) do
    from(b in Ban, where: b.channel_name == ^channel_name)
    |> Repo.all()
  end

  # ── Ban exceptions ────────────────────────────────────────

  @spec add_ban_exception(String.t(), String.t(), String.t()) ::
          {:ok, BanException.t()} | {:error, Ecto.Changeset.t()}
  def add_ban_exception(channel_name, nickname, added_by) do
    %BanException{}
    |> BanException.changeset(%{
      channel_name: channel_name,
      nickname: nickname,
      added_by: added_by
    })
    |> Repo.insert()
  end

  @spec remove_ban_exception(String.t(), String.t()) :: :ok | {:error, :not_found}
  def remove_ban_exception(channel_name, nickname) do
    from(e in BanException,
      where: e.channel_name == ^channel_name and e.nickname == ^nickname
    )
    |> Repo.delete_all()
    |> case do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  @spec list_ban_exceptions(String.t()) :: [BanException.t()]
  def list_ban_exceptions(channel_name) do
    from(e in BanException,
      where: e.channel_name == ^channel_name,
      order_by: e.inserted_at
    )
    |> Repo.all()
  end

  # ── Invite exceptions ─────────────────────────────────────

  @spec add_invite_exception(String.t(), String.t(), String.t()) ::
          {:ok, InviteException.t()} | {:error, Ecto.Changeset.t()}
  def add_invite_exception(channel_name, nickname, added_by) do
    %InviteException{}
    |> InviteException.changeset(%{
      channel_name: channel_name,
      nickname: nickname,
      added_by: added_by
    })
    |> Repo.insert()
  end

  @spec remove_invite_exception(String.t(), String.t()) :: :ok | {:error, :not_found}
  def remove_invite_exception(channel_name, nickname) do
    from(e in InviteException,
      where: e.channel_name == ^channel_name and e.nickname == ^nickname
    )
    |> Repo.delete_all()
    |> case do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  @spec list_invite_exceptions(String.t()) :: [InviteException.t()]
  def list_invite_exceptions(channel_name) do
    from(e in InviteException,
      where: e.channel_name == ^channel_name,
      order_by: e.inserted_at
    )
    |> Repo.all()
  end
end
