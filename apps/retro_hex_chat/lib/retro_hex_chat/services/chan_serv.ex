defmodule RetroHexChat.Services.ChanServ do
  @moduledoc "ChanServ: Channel registration and access list management."
  use Gettext, backend: RetroHexChat.Gettext
  use GenServer

  require Logger

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.Queries

  @level_hierarchy %{"founder" => 4, "sop" => 3, "aop" => 2, "vop" => 1}
  @access_levels ~w(sop aop vop)

  # ── Public API ──────────────────────────────────────────────

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    nick_serv = Keyword.get(opts, :nick_serv, NickServ)
    GenServer.start_link(__MODULE__, %{nick_serv: nick_serv}, name: name)
  end

  @spec register(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def register(channel_name, founder_nick, server \\ __MODULE__) do
    GenServer.call(server, {:register, channel_name, founder_nick})
  end

  @spec drop(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def drop(channel_name, nickname, server \\ __MODULE__) do
    GenServer.call(server, {:drop, channel_name, nickname})
  end

  @spec info(String.t(), GenServer.server()) :: {:ok, map()} | {:error, String.t()}
  def info(channel_name, server \\ __MODULE__) do
    GenServer.call(server, {:info, channel_name})
  end

  @spec check_access(String.t(), String.t(), GenServer.server()) :: {:ok, String.t() | nil}
  def check_access(channel_name, nickname, server \\ __MODULE__) do
    GenServer.call(server, {:check_access, channel_name, nickname})
  end

  @spec viewer_role(String.t(), String.t(), GenServer.server()) :: String.t() | nil
  def viewer_role(channel_name, nickname, server \\ __MODULE__) do
    case info(channel_name, server) do
      {:ok, %{founder: ^nickname}} ->
        "founder"

      {:ok, _info} ->
        case Queries.find_access(channel_name, nickname) do
          nil -> nil
          entry -> entry.level
        end

      {:error, _msg} ->
        nil
    end
  end

  @spec registration_snapshot(String.t(), String.t(), GenServer.server()) :: map()
  def registration_snapshot(channel_name, viewer_nick, server \\ __MODULE__) do
    case info(channel_name, server) do
      {:ok, info} ->
        %{
          registered?: true,
          channel_name: info.name,
          founder: info.founder,
          registered_at: info.registered_at,
          viewer_role: viewer_role(channel_name, viewer_nick, server),
          access: access_by_level(channel_name)
        }

      {:error, _msg} ->
        %{
          registered?: false,
          channel_name: channel_name,
          founder: nil,
          registered_at: nil,
          viewer_role: nil,
          access: empty_access()
        }
    end
  end

  @spec manage_access(
          String.t(),
          :add | :remove,
          String.t(),
          String.t(),
          String.t(),
          GenServer.server()
        ) ::
          {:ok, String.t()} | {:error, String.t()}
  def manage_access(
        channel_name,
        action,
        level,
        target_nick,
        requester_nick,
        server \\ __MODULE__
      ) do
    GenServer.call(
      server,
      {:manage_access, channel_name, action, level, target_nick, requester_nick}
    )
  end

  @spec admin_drop(String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def admin_drop(channel_name, server \\ __MODULE__) do
    GenServer.call(server, {:admin_drop, channel_name})
  end

  @spec admin_transfer(String.t(), String.t(), GenServer.server()) ::
          {:ok, String.t()} | {:error, String.t()}
  def admin_transfer(channel_name, new_founder, server \\ __MODULE__) do
    GenServer.call(server, {:admin_transfer, channel_name, new_founder})
  end

  @spec admin_manage_access(
          String.t(),
          :add | :remove,
          String.t(),
          String.t(),
          GenServer.server()
        ) ::
          {:ok, String.t()} | {:error, String.t()}
  def admin_manage_access(channel_name, action, level, target_nick, server \\ __MODULE__) do
    GenServer.call(server, {:admin_manage_access, channel_name, action, level, target_nick})
  end

  # ── GenServer callbacks ─────────────────────────────────────

  @impl true
  def init(config) do
    {:ok, config}
  end

  @impl true
  def handle_call({:register, channel_name, founder_nick}, _from, state) do
    with :ok <- check_identified(founder_nick, state),
         {:ok, _channel} <- do_register_channel(channel_name, founder_nick) do
      {:reply,
       {:ok,
        dgettext("services", "Channel %{channel_name} registered by %{founder_nick}",
          channel_name: channel_name,
          founder_nick: founder_nick
        )}, state}
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:drop, channel_name, nickname}, _from, state) do
    with :ok <- check_identified(nickname, state),
         {:ok, channel} <- find_channel_or_error(channel_name),
         :ok <- verify_founder(channel, nickname) do
      cleanup_channel(channel_name)
      Queries.delete_registered_channel(channel)

      {:reply,
       {:ok, dgettext("services", "Channel %{channel_name} dropped", channel_name: channel_name)},
       state}
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:info, channel_name}, _from, state) do
    case Queries.find_registered_channel(channel_name) do
      nil ->
        {:reply,
         {:error,
          dgettext("services", "Channel %{channel_name} is not registered",
            channel_name: channel_name
          )}, state}

      channel ->
        info = %{
          name: channel.name,
          founder: channel.founder_nickname,
          registered_at: channel.registered_at,
          topic: channel.topic || "",
          modes: channel.modes || ""
        }

        {:reply, {:ok, info}, state}
    end
  end

  def handle_call({:check_access, channel_name, nickname}, _from, state) do
    entry = Queries.find_access(channel_name, nickname)
    level = if entry, do: entry.level, else: nil
    {:reply, {:ok, level}, state}
  end

  def handle_call(
        {:manage_access, channel_name, action, level, target_nick, requester_nick},
        _from,
        state
      ) do
    with :ok <- check_identified(requester_nick, state),
         :ok <- check_hierarchy(channel_name, requester_nick, level) do
      result = do_manage_access(channel_name, action, level, target_nick, requester_nick)
      {:reply, result, state}
    else
      {:error, msg} -> {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:admin_drop, channel_name}, _from, state) do
    case find_channel_or_error(channel_name) do
      {:ok, channel} ->
        cleanup_channel(channel_name)
        Queries.delete_registered_channel(channel)

        {:reply,
         {:ok,
          dgettext("services", "Channel %{channel_name} dropped by admin",
            channel_name: channel_name
          )}, state}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:admin_transfer, channel_name, new_founder}, _from, state) do
    case find_channel_or_error(channel_name) do
      {:ok, channel} ->
        old_founder = channel.founder_nickname
        Queries.remove_access(channel_name, old_founder)
        Queries.add_access(channel_name, old_founder, "sop", "admin")
        Queries.remove_access(channel_name, new_founder)
        Queries.add_access(channel_name, new_founder, "founder", "admin")
        Queries.update_channel_founder(channel_name, new_founder)

        {:reply,
         {:ok,
          dgettext("services", "Founder of %{channel_name} transferred to %{new_founder}",
            channel_name: channel_name,
            new_founder: new_founder
          )}, state}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:admin_manage_access, channel_name, action, level, target_nick}, _from, state) do
    case find_channel_or_error(channel_name) do
      {:ok, _channel} ->
        result = do_manage_access(channel_name, action, level, target_nick, "admin")
        {:reply, result, state}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  # ── Private helpers ─────────────────────────────────────────

  defp check_identified(nickname, state) do
    nick_serv = Map.get(state, :nick_serv, NickServ)

    case NickServ.info(nickname, nick_serv) do
      {:ok, %{identified: true}} -> :ok
      _ -> {:error, dgettext("services", "You must be identified to use ChanServ")}
    end
  end

  defp do_register_channel(channel_name, founder_nick) do
    case Queries.insert_registered_channel(channel_name, founder_nick) do
      {:ok, channel} ->
        Queries.add_access(channel_name, founder_nick, "founder", founder_nick)
        {:ok, channel}

      {:error, changeset} ->
        {:error, format_changeset_error(changeset)}
    end
  end

  defp find_channel_or_error(channel_name) do
    case Queries.find_registered_channel(channel_name) do
      nil ->
        {:error,
         dgettext("services", "Channel %{channel_name} is not registered",
           channel_name: channel_name
         )}

      channel ->
        {:ok, channel}
    end
  end

  defp verify_founder(channel, nickname) do
    if channel.founder_nickname == nickname do
      :ok
    else
      {:error, dgettext("services", "Only the founder can drop a channel")}
    end
  end

  defp cleanup_channel(channel_name) do
    Enum.each(Queries.list_access(channel_name), fn entry ->
      case Queries.remove_access(channel_name, entry.nickname) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to remove access for #{entry.nickname} in #{channel_name}: #{inspect(reason)}"
          )
      end
    end)

    Enum.each(Queries.list_bans(channel_name), fn ban ->
      case Queries.remove_ban(channel_name, ban.banned_nickname) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to remove ban for #{ban.banned_nickname} in #{channel_name}: #{inspect(reason)}"
          )
      end
    end)

    cleanup_exceptions(channel_name)
  end

  defp cleanup_exceptions(channel_name) do
    Enum.each(Queries.list_ban_exceptions(channel_name), fn entry ->
      Queries.remove_ban_exception(channel_name, entry.nickname)
    end)

    Enum.each(Queries.list_invite_exceptions(channel_name), fn entry ->
      Queries.remove_invite_exception(channel_name, entry.nickname)
    end)
  end

  defp check_hierarchy(channel_name, requester_nick, target_level) do
    requester_entry = Queries.find_access(channel_name, requester_nick)
    requester_level = if requester_entry, do: requester_entry.level, else: nil
    requester_rank = Map.get(@level_hierarchy, requester_level, 0)
    target_rank = Map.get(@level_hierarchy, target_level, 0)

    if requester_rank > target_rank do
      :ok
    else
      {:error, "Insufficient permission to manage #{target_level} access"}
    end
  end

  defp access_by_level(channel_name) do
    entries =
      channel_name
      |> Queries.list_access()
      |> Enum.reject(&(&1.level == "founder"))
      |> Enum.map(fn entry ->
        %{nickname: entry.nickname, level: entry.level, added_by: entry.added_by}
      end)

    Map.new(@access_levels, fn level ->
      {level, Enum.filter(entries, &(&1.level == level))}
    end)
  end

  defp empty_access, do: Map.new(@access_levels, &{&1, []})

  defp do_manage_access(channel_name, :add, level, target_nick, requester_nick) do
    case Queries.add_access(channel_name, target_nick, level, requester_nick) do
      {:ok, _} ->
        {:ok,
         dgettext("services", "%{target_nick} added to %{level} list of %{channel_name}",
           target_nick: target_nick,
           level: level,
           channel_name: channel_name
         )}

      {:error, _} ->
        {:error,
         dgettext("services", "Failed to add %{target_nick} to %{level} list",
           target_nick: target_nick,
           level: level
         )}
    end
  end

  defp do_manage_access(channel_name, :remove, _level, target_nick, _requester_nick) do
    case Queries.remove_access(channel_name, target_nick) do
      :ok ->
        {:ok,
         dgettext("services", "%{target_nick} removed from access list of %{channel_name}",
           target_nick: target_nick,
           channel_name: channel_name
         )}

      {:error, :not_found} ->
        {:error,
         dgettext("services", "%{target_nick} not found in access list", target_nick: target_nick)}
    end
  end

  defp format_changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      dgettext("services", "%{field}: %{errors}", field: field, errors: Enum.join(errors, ", "))
    end)
  end
end
