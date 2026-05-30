defmodule RetroHexChat.Admin do
  @moduledoc """
  Facade for admin operations. Each function orchestrates:
  1. Domain action (DB mutation, cache update, etc.)
  2. Audit log entry
  3. PubSub broadcast (where applicable)
  4. Return `{:ok, message}` or `{:error, message}`
  """

  require Logger

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Admin.{AuditLogs, GlobalMutes, RoleCache, ServerBans}
  alias RetroHexChat.Bots
  alias RetroHexChat.Channels
  alias RetroHexChat.Commands.Duration
  alias RetroHexChat.Services.{ChanServ, NickServ, Queries}

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

        broadcast_user(
          nickname,
          {:force_disconnect, %{reason: "Server banned: #{reason || "No reason given"}"}}
        )

        duration_text =
          if duration_seconds,
            do: " for #{Duration.format(duration_seconds)}",
            else: " permanently"

        {:ok, "#{nickname} has been server-banned#{duration_text}."}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec unban_user(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def unban_user(nickname, admin) do
    case ServerBans.unban(nickname) do
      {:ok, _msg} ->
        AuditLogs.log(admin, "user.unban", {"user", nickname})
        {:ok, "#{nickname} has been unbanned from the server."}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec kick_user(String.t(), String.t(), String.t() | nil) :: {:ok, String.t()}
  def kick_user(nickname, admin, reason \\ nil) do
    AuditLogs.log(admin, "user.kick", {"user", nickname}, %{reason: reason})
    broadcast_user(nickname, {:force_disconnect, %{reason: reason || "Kicked by administrator"}})
    {:ok, "#{nickname} has been kicked from the server."}
  end

  @spec mute_user(String.t(), String.t(), String.t() | nil, non_neg_integer() | :permanent) ::
          {:ok, String.t()}
  def mute_user(nickname, admin, reason \\ nil, duration \\ :permanent) do
    GlobalMutes.mute(nickname, reason, duration)
    AuditLogs.log(admin, "user.mute", {"user", nickname}, %{reason: reason, duration: duration})

    broadcast_user(nickname, {:user_muted, %{nickname: nickname, reason: reason, admin: admin}})

    duration_text =
      if duration == :permanent, do: "permanently", else: "for #{Duration.format(duration)}"

    {:ok, "#{nickname} has been muted #{duration_text}."}
  end

  @spec unmute_user(String.t(), String.t()) :: {:ok, String.t()}
  def unmute_user(nickname, admin) do
    GlobalMutes.unmute(nickname)
    AuditLogs.log(admin, "user.unmute", {"user", nickname})
    broadcast_user(nickname, {:user_unmuted, %{nickname: nickname}})
    {:ok, "#{nickname} has been unmuted."}
  end

  @spec rename_user(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def rename_user(old_nick, new_nick, admin) do
    case NicknameValidator.validate(new_nick) do
      :ok ->
        AuditLogs.log(admin, "user.rename", {"user", old_nick}, %{new_nick: new_nick})

        broadcast_user(
          old_nick,
          {:admin_rename, %{old_nick: old_nick, new_nick: new_nick, admin: admin}}
        )

        {:ok, "#{old_nick} has been renamed to #{new_nick}."}

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
        {:error, "Cannot modify role of a root admin"}

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
          {:force_disconnect, %{reason: "Your nick registration was dropped by an administrator"}}
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
        AuditLogs.log(admin, "ns.resetpass", {"user", nickname}, %{note: "Password was reset"})
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
        {:ok, "Channel #{channel_name} created and registered."}

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
    {:ok, "Channel #{channel_name} has been deleted."}
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
        do: "Purged #{count} messages from #{from_nick} in #{channel_name}.",
        else: "Purged #{count} messages from #{channel_name}."

    {:ok, msg}
  end

  # ── Server Settings ─────────────────────────────────────────

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
        {:ok, "Server setting '#{key}' set to '#{value}'."}

      {:error, _} ->
        {:error, "Failed to set server setting '#{key}'"}
    end
  end

  # ── System Nuke ─────────────────────────────────────────────

  @nuke_schemas [
    {"messages", RetroHexChat.Chat.Message},
    {"private_messages", RetroHexChat.Chat.PrivateMessage},
    {"p2p_sessions", RetroHexChat.P2P.Schema.Session},
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
    {"notice_routing_settings", RetroHexChat.Chat.Schemas.NoticeRoutingSetting},
    {"user_preferences", RetroHexChat.Chat.Schemas.UserPreference},
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
    import Ecto.Query
    alias RetroHexChat.Repo

    AuditLogs.log(admin, "system.nuke_preview")

    counts =
      Enum.map(@nuke_schemas, fn {name, schema} ->
        count = Repo.aggregate(from(_ in schema), :count)
        {name, count}
      end)

    {:ok, counts}
  end

  @spec nuke_system(String.t()) :: {:ok, [{String.t(), non_neg_integer()}]} | {:error, String.t()}
  def nuke_system(admin) do
    import Ecto.Query
    alias RetroHexChat.Repo

    AuditLogs.log(admin, "system.nuke", {"system", "all"}, %{action: "factory_reset"})

    multi =
      Enum.reduce(@nuke_schemas, Ecto.Multi.new(), fn {name, schema}, multi ->
        Ecto.Multi.delete_all(multi, String.to_atom(name), from(_ in schema))
      end)

    case Repo.transaction(multi) do
      {:ok, results} ->
        shutdown_all_bots()
        shutdown_all_channels()
        broadcast_system_nuke()

        summary =
          Enum.map(@nuke_schemas, fn {name, _schema} ->
            {count, _} = Map.get(results, String.to_atom(name), {0, nil})
            {name, count}
          end)

        Logger.warning("SYSTEM NUKE executed by #{admin}")
        {:ok, summary}

      {:error, failed_step, _changeset, _completed} ->
        {:error, "Nuke failed at step: #{failed_step}"}
    end
  end

  defp shutdown_all_bots do
    Bots.Supervisor.stop_all()
  rescue
    e -> Logger.warning("Bot shutdown during nuke failed: #{inspect(e)}")
  end

  defp shutdown_all_channels do
    children = DynamicSupervisor.which_children(Channels.Supervisor)

    Enum.each(children, fn {_, pid, _, _} ->
      if is_pid(pid), do: Channels.Supervisor.stop_child(pid)
    end)
  rescue
    e -> Logger.warning("Channel shutdown during nuke failed: #{inspect(e)}")
  end

  defp broadcast_system_nuke do
    Phoenix.PubSub.broadcast(@pubsub, "server:settings", {:system_nuked, %{}})
  rescue
    e -> Logger.warning("Nuke broadcast failed: #{inspect(e)}")
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
        {:ok, "#{nickname} has been set as #{role}."}

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
    {:ok, "Admin roles removed from #{nickname}."}
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
