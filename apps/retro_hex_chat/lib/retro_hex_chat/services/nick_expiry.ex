defmodule RetroHexChat.Services.NickExpiry do
  @moduledoc "Periodic purge of inactive registered nicknames."
  use Gettext, backend: RetroHexChat.Gettext
  use GenServer

  require Logger

  alias RetroHexChat.Admin.RoleCache
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.Queries

  @default_expiration_days 7
  @default_purge_interval_ms 21_600_000

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    config = %{
      expiration_days: Keyword.get(opts, :expiration_days, @default_expiration_days),
      purge_interval_ms: Keyword.get(opts, :purge_interval_ms, @default_purge_interval_ms),
      nickserv: Keyword.get(opts, :nickserv, NickServ)
    }

    GenServer.start_link(__MODULE__, config, name: name)
  end

  @spec run_now(GenServer.server()) :: {non_neg_integer(), [String.t()]}
  def run_now(server \\ __MODULE__) do
    GenServer.call(server, :run_now)
  end

  # -- GenServer callbacks --

  @impl true
  def init(config) do
    schedule_purge(config.purge_interval_ms)
    {:ok, config}
  end

  @impl true
  def handle_call(:run_now, _from, state) do
    result = do_purge(state)
    {:reply, result, state}
  end

  @impl true
  def handle_info(:purge, state) do
    do_purge(state)
    schedule_purge(state.purge_interval_ms)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Private --

  defp do_purge(state) do
    identified = NickServ.list_identified(state.nickserv)
    admin_nicks = admin_protected_nicks()
    protected = Enum.uniq(identified ++ admin_nicks)
    {count, nicknames} = Queries.purge_expired_nicks(state.expiration_days, protected)

    Enum.each(nicknames, fn nick ->
      NickServ.remove_identified(nick, state.nickserv)
    end)

    if count > 0 do
      Logger.info("NickExpiry: purged #{count} inactive nick(s): #{Enum.join(nicknames, ", ")}")
    end

    handle_founder_succession(nicknames)

    {count, nicknames}
  end

  defp handle_founder_succession(nicknames) do
    Enum.each(nicknames, fn nick ->
      channels = Queries.list_channels_for_founder(nick)
      Queries.remove_access_for_nick(nick)
      Enum.each(channels, &succeed_or_deregister/1)
    end)
  end

  defp succeed_or_deregister(channel_name) do
    case Queries.find_next_successor(channel_name) do
      nil ->
        cleanup_and_delete_channel(channel_name)
        Logger.info("NickExpiry: deregistered orphaned channel #{channel_name}")

      successor ->
        promote_successor(channel_name, successor)
        Logger.info("NickExpiry: promoted #{successor.nickname} to founder of #{channel_name}")
    end
  end

  defp promote_successor(channel_name, successor) do
    Queries.remove_access(channel_name, successor.nickname)

    Queries.add_access(
      channel_name,
      successor.nickname,
      "founder",
      dgettext("services", "NickExpiry")
    )

    Queries.update_channel_founder(channel_name, successor.nickname)
  end

  defp cleanup_and_delete_channel(channel_name) do
    Queries.list_access(channel_name)
    |> Enum.each(fn entry -> Queries.remove_access(channel_name, entry.nickname) end)

    Queries.list_bans(channel_name)
    |> Enum.each(fn ban -> Queries.remove_ban(channel_name, ban.banned_nickname) end)

    Queries.list_ban_exceptions(channel_name)
    |> Enum.each(fn entry -> Queries.remove_ban_exception(channel_name, entry.nickname) end)

    Queries.list_invite_exceptions(channel_name)
    |> Enum.each(fn entry -> Queries.remove_invite_exception(channel_name, entry.nickname) end)

    Queries.delete_welcome_message(channel_name)

    case Queries.find_registered_channel(channel_name) do
      nil -> :ok
      channel -> Queries.delete_registered_channel(channel)
    end
  end

  defp admin_protected_nicks do
    root_admins = Application.get_env(:retro_hex_chat, :root_admins, [])

    db_admins =
      try do
        RoleCache.list_admin_nicks()
      rescue
        _ -> []
      end

    root_admins ++ db_admins
  end

  defp schedule_purge(interval_ms) do
    Process.send_after(self(), :purge, interval_ms)
  end
end
