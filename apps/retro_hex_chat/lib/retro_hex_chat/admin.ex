defmodule RetroHexChat.Admin do
  @moduledoc """
  Facade for admin operations. Each function orchestrates:
  1. Domain action (DB mutation, cache update, etc.)
  2. Audit log entry
  3. PubSub broadcast (where applicable)
  4. Return `{:ok, message}` or `{:error, message}`
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Accounts.{ChatDeviceSession, NicknameValidator}
  alias RetroHexChat.Admin.{AuditLogs, GlobalMutes, RoleCache, ServerBans}
  alias RetroHexChat.Bots
  alias RetroHexChat.Channels
  alias RetroHexChat.Commands.Duration
  alias RetroHexChat.Jobs
  alias RetroHexChat.P2P.RateLimitTable, as: P2PRateLimitTable
  alias RetroHexChat.Presence.{Tracker, WhowasCache}
  alias RetroHexChat.RateLimit.Table, as: ChatRateLimitTable
  alias RetroHexChat.Scraper.Cache, as: ScraperCache
  alias RetroHexChat.Services.{ChanServ, NickServ, Queries}
  alias RetroHexChat.Topics

  @pubsub RetroHexChat.PubSub

  # ── User Management ──────────────────────────────────────────

  @spec ban_user(String.t(), String.t(), String.t() | nil, non_neg_integer() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def ban_user(nickname, admin, reason \\ nil, duration_seconds \\ nil) do
    expires_at =
      if duration_seconds,
        do: DateTime.add(DateTime.utc_now(), duration_seconds, :second),
        else: nil

    case ServerBans.ban(nickname, admin, reason, expires_at) do
      {:ok, _ban} ->
        AuditLogs.log(admin, "user.ban", {"user", nickname}, %{
          reason: reason,
          duration: duration_seconds
        })

        ban_reason = reason || dgettext("admin", "No reason given")

        broadcast_user(
          nickname,
          {:force_disconnect,
           %{reason: dgettext("admin", "Server banned: %{reason}", reason: ban_reason)}}
        )

        duration_text =
          if duration_seconds,
            do:
              dgettext("admin", " for %{duration_seconds}",
                duration_seconds: Duration.format(duration_seconds)
              ),
            else: dgettext("admin", " permanently")

        {:ok,
         dgettext("admin", "%{nickname} has been server-banned%{duration_text}.",
           nickname: nickname,
           duration_text: duration_text
         )}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec unban_user(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def unban_user(nickname, admin) do
    case ServerBans.unban(nickname) do
      {:ok, _msg} ->
        AuditLogs.log(admin, "user.unban", {"user", nickname})

        {:ok,
         dgettext("admin", "%{nickname} has been unbanned from the server.", nickname: nickname)}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec kick_user(String.t(), String.t(), String.t() | nil) :: {:ok, String.t()}
  def kick_user(nickname, admin, reason \\ nil) do
    AuditLogs.log(admin, "user.kick", {"user", nickname}, %{reason: reason})

    broadcast_user(
      nickname,
      {:force_disconnect, %{reason: reason || dgettext("admin", "Kicked by administrator")}}
    )

    {:ok, dgettext("admin", "%{nickname} has been kicked from the server.", nickname: nickname)}
  end

  @spec mute_user(String.t(), String.t(), String.t() | nil, non_neg_integer() | :permanent) ::
          {:ok, String.t()} | {:error, String.t()}
  def mute_user(nickname, admin, reason \\ nil, duration \\ :permanent) do
    case GlobalMutes.mute(nickname, admin, reason, duration) do
      :ok ->
        AuditLogs.log(admin, "user.mute", {"user", nickname}, %{
          reason: reason,
          duration: duration
        })

        broadcast_user(
          nickname,
          {:user_muted, %{nickname: nickname, reason: reason, admin: admin}}
        )

        duration_text =
          if duration == :permanent,
            do: "permanently",
            else: dgettext("admin", "for %{duration}", duration: Duration.format(duration))

        {:ok,
         dgettext("admin", "%{nickname} has been muted %{duration_text}.",
           nickname: nickname,
           duration_text: duration_text
         )}

      {:error, reason} ->
        Logger.warning("Failed to persist global mute for #{nickname}: #{inspect(reason)}")
        {:error, dgettext("admin", "Failed to mute %{nickname}.", nickname: nickname)}
    end
  end

  @spec unmute_user(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def unmute_user(nickname, admin) do
    case GlobalMutes.unmute(nickname, admin) do
      :ok ->
        AuditLogs.log(admin, "user.unmute", {"user", nickname})
        broadcast_user(nickname, {:user_unmuted, %{nickname: nickname}})
        {:ok, dgettext("admin", "%{nickname} has been unmuted.", nickname: nickname)}

      {:error, reason} ->
        Logger.warning("Failed to persist global unmute for #{nickname}: #{inspect(reason)}")
        {:error, dgettext("admin", "Failed to unmute %{nickname}.", nickname: nickname)}
    end
  end

  @spec rename_user(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def rename_user(old_nick, new_nick, admin) do
    case NicknameValidator.validate(new_nick) do
      :ok ->
        AuditLogs.log(admin, "user.rename", {"user", old_nick}, %{
          new_nick: new_nick
        })

        broadcast_user(
          old_nick,
          {:admin_rename, %{old_nick: old_nick, new_nick: new_nick, admin: admin}}
        )

        {:ok,
         dgettext("admin", "%{old_nick} has been renamed to %{new_nick}.",
           old_nick: old_nick,
           new_nick: new_nick
         )}

      {:error, msg} ->
        {:error, "Invalid nickname: #{msg}"}
    end
  end

  @spec set_role(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def set_role(nickname, role, admin) when role in ~w(admin server_operator user) do
    root_admins = Application.get_env(:retro_hex_chat, :root_admins, [])

    cond do
      nickname in root_admins ->
        {:error, dgettext("admin", "Cannot modify role of a root admin")}

      role == "user" ->
        remove_roles(nickname, admin)

      true ->
        add_role(nickname, role, admin)
    end
  end

  def set_role(_nickname, role, _admin) do
    {:error, "Invalid role: #{role}. Valid roles: admin, server_operator, user"}
  end

  # ── NickServ Admin ───────────────────────────────────────────

  @spec drop_nick(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def drop_nick(nickname, admin) do
    case NickServ.admin_drop(nickname) do
      {:ok, msg} ->
        AuditLogs.log(admin, "ns.drop", {"user", nickname})

        broadcast_user(
          nickname,
          {:force_disconnect,
           %{reason: dgettext("admin", "Your nick registration was dropped by an administrator")}}
        )

        {:ok, msg}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec reset_password(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def reset_password(nickname, new_password, admin) do
    case NickServ.admin_reset_password(nickname, new_password) do
      {:ok, msg} ->
        AuditLogs.log(admin, "ns.resetpass", {"user", nickname}, %{
          note: dgettext("admin", "Password was reset")
        })

        {:ok, msg}

      {:error, msg} ->
        {:error, msg}
    end
  end

  # ── ChanServ Admin ──────────────────────────────────────────

  @spec drop_channel(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def drop_channel(channel_name, admin) do
    case ChanServ.admin_drop(channel_name) do
      {:ok, msg} ->
        AuditLogs.log(admin, "cs.drop", {"channel", channel_name})
        {:ok, msg}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec transfer_channel(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def transfer_channel(channel_name, new_founder, admin) do
    case ChanServ.admin_transfer(channel_name, new_founder) do
      {:ok, msg} ->
        AuditLogs.log(admin, "cs.transfer", {"channel", channel_name}, %{
          new_founder: new_founder
        })

        {:ok, msg}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec manage_channel_access(String.t(), :add | :remove, String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def manage_channel_access(channel_name, action, level, nickname, admin) do
    case ChanServ.admin_manage_access(channel_name, action, level, nickname) do
      {:ok, msg} ->
        AuditLogs.log(admin, "cs.access", {"channel", channel_name}, %{
          action: action,
          level: level,
          target: nickname
        })

        {:ok, msg}

      {:error, msg} ->
        {:error, msg}
    end
  end

  # ── Channel Operations ──────────────────────────────────────

  @spec create_channel(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def create_channel(channel_name, admin) do
    case Channels.Supervisor.start_child(channel_name) do
      {:ok, _pid} ->
        ChanServ.register(channel_name, admin)
        Channels.Server.mark_registered(channel_name)
        AuditLogs.log(admin, "channel.create", {"channel", channel_name})

        {:ok,
         dgettext("admin", "Channel %{channel_name} created and registered.",
           channel_name: channel_name
         )}

      {:error, reason} ->
        {:error, "Failed to create channel: #{inspect(reason)}"}
    end
  end

  @spec delete_channel(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def delete_channel(channel_name, admin) do
    broadcast_channel(channel_name, {:channel_deleted, %{channel: channel_name, admin: admin}})

    case Queries.find_registered_channel(channel_name) do
      nil -> :ok
      _ch -> ChanServ.admin_drop(channel_name)
    end

    case Channels.Registry.lookup(channel_name) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      {:error, :not_found} -> :ok
    end

    AuditLogs.log(admin, "channel.delete", {"channel", channel_name})

    {:ok,
     dgettext("admin", "Channel %{channel_name} has been deleted.", channel_name: channel_name)}
  end

  @spec purge_channel(String.t(), keyword(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def purge_channel(channel_name, opts, admin) do
    from_nick = Keyword.get(opts, :from)

    count =
      if from_nick do
        RetroHexChat.Chat.Queries.bulk_delete_messages(channel_name, from_nick)
      else
        RetroHexChat.Chat.Queries.bulk_delete_messages(channel_name)
      end

    AuditLogs.log(admin, "channel.purge", {"channel", channel_name}, %{
      from: from_nick,
      count: count
    })

    broadcast_channel(
      channel_name,
      {:channel_purged, %{channel: channel_name, admin: admin, from: from_nick, count: count}}
    )

    msg =
      if from_nick,
        do:
          dgettext("admin", "Purged %{count} messages from %{from_nick} in %{channel_name}.",
            count: count,
            from_nick: from_nick,
            channel_name: channel_name
          ),
        else:
          dgettext("admin", "Purged %{count} messages from %{channel_name}.",
            count: count,
            channel_name: channel_name
          )

    {:ok, msg}
  end

  # ── Server Settings ─────────────────────────────────────────

  @server_setting_defaults %{
    "server_name" => "RetroHexChat",
    "server_description" => "",
    "welcome_message" => "",
    "max_channels" => "10",
    "registration" => "open",
    "whowas_retention_seconds" => "3600"
  }

  @server_setting_keys ~w(server_name server_description welcome_message max_channels registration whowas_retention_seconds)

  @spec server_setting_keys() :: [String.t()]
  def server_setting_keys, do: @server_setting_keys

  @spec server_settings_values() :: %{String.t() => String.t()}
  def server_settings_values do
    Map.new(@server_setting_keys, fn key ->
      {key, Queries.get_setting(key) || Map.fetch!(@server_setting_defaults, key)}
    end)
  end

  @spec server_setting_changes(map(), map()) :: [{String.t(), String.t()}]
  def server_setting_changes(current, submitted) do
    @server_setting_keys
    |> Enum.filter(&Map.has_key?(submitted, &1))
    |> Enum.map(fn key -> {key, submitted |> Map.get(key, "") |> to_string()} end)
    |> Enum.reject(fn {key, value} -> value == Map.get(current, key, "") end)
  end

  @spec set_setting(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def set_setting(key, value, admin) do
    previous = Queries.get_setting(key)

    case Queries.upsert_setting(key, value, admin) do
      {:ok, _} ->
        AuditLogs.log(admin, "server.set", {"server", key}, %{
          value: value,
          previous: previous
        })

        broadcast_server({:server_setting_changed, %{key: key, value: value}})

        {:ok,
         dgettext("admin", "Server setting '%{key}' set to '%{value}'.", key: key, value: value)}

      {:error, _} ->
        {:error, "Failed to set server setting '#{key}'"}
    end
  end

  # ── System Nuke ─────────────────────────────────────────────

  @nuke_targets [
    {"messages", RetroHexChat.Chat.Message},
    {"private_messages", RetroHexChat.Chat.PrivateMessage},
    {"bans", RetroHexChat.Services.Ban},
    {"ban_exceptions", RetroHexChat.Services.BanException},
    {"invite_exceptions", RetroHexChat.Services.InviteException},
    {"access_list_entries", RetroHexChat.Services.AccessListEntry},
    {"channel_welcome_messages", RetroHexChat.Services.ChannelWelcomeMessage},
    {"autojoin_entries", RetroHexChat.Chat.Schemas.AutojoinListEntry},
    {"aliases", RetroHexChat.Chat.Schemas.AliasEntry},
    {"custom_menu_items", RetroHexChat.Chat.Schemas.CustomMenuItem},
    {"autorespond_rules", RetroHexChat.Chat.Schemas.AutoRespondRule},
    {"perform_entries", RetroHexChat.Chat.Schemas.PerformListEntry},
    {"contacts", RetroHexChat.Accounts.ContactEntry},
    {"nick_color_overrides", RetroHexChat.Accounts.NickColorEntry},
    {"highlight_words", RetroHexChat.Accounts.HighlightWordEntry},
    {"ignore_list_entries", RetroHexChat.Chat.Schemas.IgnoreListEntry},
    {"notify_list_entries", RetroHexChat.Presence.NotifyListEntry},
    {"notify_list_settings", RetroHexChat.Presence.NotifyListSettings},
    {"user_bios", RetroHexChat.Chat.Schemas.UserBio},
    {"perform_settings", RetroHexChat.Chat.Schemas.PerformSettings},
    {"flood_protection_settings", RetroHexChat.Chat.Schemas.FloodProtectionSetting},
    {"sound_settings", RetroHexChat.Chat.Schemas.SoundSetting},
    {"input_histories", RetroHexChat.Chat.Schemas.InputHistory},
    {"contextual_tip_settings", RetroHexChat.Chat.Schemas.ContextualTipSetting},
    {"reconnect_states", RetroHexChat.Chat.Schemas.ReconnectState},
    {"notice_routing_settings", RetroHexChat.Chat.Schemas.NoticeRoutingSetting},
    {"user_preferences", RetroHexChat.Chat.Schemas.UserPreference},
    {"group_call_tracks", RetroHexChat.GroupCall.Schema.Track},
    {"group_call_participants", RetroHexChat.GroupCall.Schema.Participant},
    {"group_call_rooms", RetroHexChat.GroupCall.Schema.Room},
    {"lobby_sessions", RetroHexChat.Lobby.Schema.Session},
    {"solo_sessions", RetroHexChat.Arcade.Schema.SoloSession},
    {"game_sessions", "game_sessions"},
    {"trusted_device_events", RetroHexChat.Accounts.TrustedDeviceEvent},
    {"trusted_device_nicks", RetroHexChat.Accounts.TrustedDeviceNick},
    {"chat_device_sessions", RetroHexChat.Accounts.ChatDeviceSession},
    {"trusted_devices", RetroHexChat.Accounts.TrustedDevice},
    {"global_mutes", RetroHexChat.Admin.GlobalMute},
    {"oban_jobs", :oban_jobs},
    {"bot_event_log", RetroHexChat.Bots.BotEventLog},
    {"bot_custom_commands", RetroHexChat.Bots.BotCustomCommand},
    {"bot_channel_configs", RetroHexChat.Bots.BotChannelConfig},
    {"bots", RetroHexChat.Bots.Bot},
    {"registered_channels", RetroHexChat.Services.RegisteredChannel},
    {"registered_nicks", RetroHexChat.Services.RegisteredNick}
  ]

  @spec nuke_preview(String.t()) ::
          {:ok, [{String.t(), non_neg_integer()}]} | {:error, String.t()}
  def nuke_preview(admin) do
    AuditLogs.log(admin, "system.nuke_preview")

    counts = Enum.map(@nuke_targets, fn {name, source} -> {name, nuke_target_count(source)} end)

    {:ok, counts}
  end

  @spec nuke_system(String.t()) :: {:ok, [{String.t(), non_neg_integer()}]} | {:error, String.t()}
  def nuke_system(admin) do
    alias RetroHexChat.Repo

    connected_targets = connected_targets(admin)

    AuditLogs.log(admin, "system.nuke", {"system", "all"}, %{
      action: "factory_reset"
    })

    multi =
      @nuke_targets
      |> Enum.reduce(Ecto.Multi.new(), fn {name, source}, multi ->
        nuke_target_delete_all(multi, name, source)
      end)
      |> Ecto.Multi.run(:registration_open, fn _repo, _changes ->
        Queries.upsert_setting("registration", "open", admin)
      end)

    case Repo.transaction(multi) do
      {:ok, results} ->
        reset_runtime_state()
        broadcast_system_nuke(admin)
        force_disconnect_connected_users(admin, connected_targets)

        summary =
          Enum.map(@nuke_targets, fn {name, _source} ->
            {count, _} = Map.get(results, String.to_atom(name), {0, nil})
            {name, count}
          end)

        Logger.warning("SYSTEM NUKE executed by #{admin}")
        {:ok, summary}

      {:error, failed_step, _changeset, _completed} ->
        {:error, "Nuke failed at step: #{failed_step}"}
    end
  end

  defp nuke_target_count(:oban_jobs), do: Jobs.count_all()

  defp nuke_target_count(source) do
    import Ecto.Query
    alias RetroHexChat.Repo

    Repo.aggregate(from(_ in source), :count)
  end

  defp nuke_target_delete_all(multi, name, :oban_jobs) do
    Ecto.Multi.run(multi, String.to_atom(name), fn _repo, _changes ->
      {:ok, Jobs.delete_all()}
    end)
  end

  defp nuke_target_delete_all(multi, name, source) do
    import Ecto.Query

    Ecto.Multi.delete_all(multi, String.to_atom(name), from(_ in source))
  end

  defp connected_targets(admin) do
    nicknames = connected_nicknames(admin)

    %{
      nicknames: nicknames,
      session_refs: active_chat_device_session_refs(nicknames)
    }
  end

  defp connected_nicknames(admin) do
    Tracker.list_users(Topics.presence())
    |> Enum.map(& &1.nickname)
    |> then(&[admin | &1])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  rescue
    e ->
      Logger.warning("Nuke online user lookup failed: #{inspect(e)}")
      [admin]
  end

  defp active_chat_device_session_refs(nicknames) do
    import Ecto.Query
    alias RetroHexChat.Repo

    from(s in ChatDeviceSession,
      where: is_nil(s.disconnected_at),
      where: s.nickname not in ^nicknames,
      select: s.session_ref
    )
    |> Repo.all()
  rescue
    e ->
      Logger.warning("Nuke active device session lookup failed: #{inspect(e)}")
      []
  end

  defp reset_runtime_state do
    shutdown_all_bots()

    [
      {RetroHexChat.GroupCall.PeerSupervisor, "group-call peer"},
      {RetroHexChat.GroupCall.RoomSupervisor, "group-call room"},
      {RetroHexChat.Lobby.Supervisor, "lobby"},
      {RetroHexChat.Arcade.Supervisor, "arcade"},
      {RetroHexChat.VirtualSpace.Supervisor, "virtual space"},
      {RetroHexChat.P2P.Turn.AllocationSupervisor, "TURN allocation"},
      {Channels.Supervisor, "channel"}
    ]
    |> Enum.each(fn {supervisor, label} -> shutdown_dynamic_supervisor(supervisor, label) end)

    clear_ephemeral_user_state()
  end

  defp shutdown_all_bots do
    Bots.Supervisor.stop_all()
  rescue
    e -> Logger.warning("Bot shutdown during nuke failed: #{inspect(e)}")
  end

  defp shutdown_dynamic_supervisor(supervisor, label) do
    case Process.whereis(supervisor) do
      nil -> :ok
      _pid -> terminate_dynamic_supervisor_children(supervisor)
    end
  rescue
    e -> Logger.warning("#{label} shutdown during nuke failed: #{inspect(e)}")
  end

  defp terminate_dynamic_supervisor_children(supervisor) do
    supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(&terminate_dynamic_supervisor_child(supervisor, &1))
  end

  defp terminate_dynamic_supervisor_child(supervisor, {_, pid, _, _}) when is_pid(pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
  end

  defp terminate_dynamic_supervisor_child(_supervisor, _child), do: :ok

  defp clear_ephemeral_user_state do
    clear_nickserv_runtime_state()
    clear_ets_table(:global_mutes, "global mute")
    clear_ets_table(ChatRateLimitTable.table_name(), "chat rate limit")
    clear_ets_table(P2PRateLimitTable.table_name(), "P2P rate limit")
    # Only the in-memory copy. A scraped page is a public fact about somebody
    # else's website, not state this server holds about its users, and the stored
    # rows outlive a nuke on purpose — dropping a 120-day archive would mean
    # re-fetching the internet to rebuild what nobody asked to erase.
    clear_ets_table(ScraperCache, "scraped page")
    WhowasCache.clear()
  rescue
    e -> Logger.warning("Ephemeral state cleanup during nuke failed: #{inspect(e)}")
  end

  defp clear_nickserv_runtime_state do
    if Process.whereis(NickServ) do
      NickServ.clear_runtime_state()
    end
  rescue
    e -> Logger.warning("NickServ runtime cleanup during nuke failed: #{inspect(e)}")
  catch
    :exit, reason ->
      Logger.warning("NickServ runtime cleanup during nuke failed: #{inspect(reason)}")
  end

  defp clear_ets_table(table, label) do
    case :ets.whereis(table) do
      :undefined -> :ok
      _tid -> :ets.delete_all_objects(table)
    end
  rescue
    e -> Logger.warning("#{label} ETS cleanup during nuke failed: #{inspect(e)}")
  end

  defp broadcast_system_nuke(admin) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "server:settings",
      {:system_nuked, nuke_disconnect_payload(admin)}
    )
  rescue
    e -> Logger.warning("Nuke broadcast failed: #{inspect(e)}")
  end

  defp force_disconnect_connected_users(admin, %{nicknames: nicknames, session_refs: session_refs}) do
    payload = nuke_disconnect_payload(admin)

    Enum.each(nicknames, fn nickname ->
      Phoenix.PubSub.broadcast(
        @pubsub,
        "user:#{nickname}",
        {:force_disconnect, Map.put(payload, :nickname, nickname)}
      )
    end)

    Enum.each(session_refs, fn session_ref ->
      Phoenix.PubSub.broadcast(
        @pubsub,
        "chat_device_session:#{session_ref}",
        {:force_disconnect, Map.put(payload, :session_ref, session_ref)}
      )
    end)
  rescue
    e -> Logger.warning("Nuke force disconnect failed: #{inspect(e)}")
  end

  defp nuke_disconnect_payload(admin) do
    %{
      force_disconnect: true,
      reason: dgettext("admin", "System reset by administrator %{admin}", admin: admin),
      system_nuke: true,
      skip_whowas: true
    }
  end

  # ── Private ─────────────────────────────────────────────────

  defp add_role(nickname, role, admin) do
    import Ecto.Query
    alias RetroHexChat.Admin.AdminRole
    alias RetroHexChat.Repo

    attrs = %{nickname: nickname, role: role, granted_by: admin}

    case %AdminRole{} |> AdminRole.changeset(attrs) |> Repo.insert() do
      {:ok, _} ->
        RoleCache.add(nickname, role)
        AuditLogs.log(admin, "user.role", {"user", nickname}, %{role: role})
        broadcast_user(nickname, {:role_changed, %{nickname: nickname, role: role}})

        {:ok,
         dgettext("admin", "%{nickname} has been set as %{role}.", nickname: nickname, role: role)}

      {:error, %Ecto.Changeset{errors: [{_, {_, [constraint: :unique, constraint_name: _]}} | _]}} ->
        {:error, "#{nickname} already has role #{role}"}

      {:error, _} ->
        {:error, "Failed to set role for #{nickname}"}
    end
  end

  defp remove_roles(nickname, admin) do
    import Ecto.Query
    alias RetroHexChat.Admin.AdminRole
    alias RetroHexChat.Repo

    from(r in AdminRole, where: r.nickname == ^nickname) |> Repo.delete_all()
    RoleCache.remove_all(nickname)
    AuditLogs.log(admin, "user.role", {"user", nickname}, %{role: "user"})
    broadcast_user(nickname, {:role_changed, %{nickname: nickname, role: "user"}})
    {:ok, dgettext("admin", "Admin roles removed from %{nickname}.", nickname: nickname)}
  end

  defp broadcast_user(nickname, message) do
    Phoenix.PubSub.broadcast(@pubsub, "user:#{nickname}", message)
  rescue
    e -> Logger.warning("Admin broadcast to user:#{nickname} failed: #{inspect(e)}")
  end

  defp broadcast_channel(channel_name, message) do
    Phoenix.PubSub.broadcast(@pubsub, "channel:#{channel_name}", message)
  rescue
    e -> Logger.warning("Admin broadcast to channel:#{channel_name} failed: #{inspect(e)}")
  end

  defp broadcast_server(message) do
    Phoenix.PubSub.broadcast(@pubsub, "server:settings", message)
  rescue
    e -> Logger.warning("Admin broadcast to server:settings failed: #{inspect(e)}")
  end
end
