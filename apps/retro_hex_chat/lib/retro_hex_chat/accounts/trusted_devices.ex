defmodule RetroHexChat.Accounts.TrustedDevices do
  @moduledoc """
  Trusted-device management for NickServ identities.

  A trusted device is not a public account. It is a revocable browser token that
  may identify one or more registered nicks after the user has proven each nick's
  password once on that device.
  """
  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Query

  alias RetroHexChat.Accounts.ChatDeviceSession
  alias RetroHexChat.Accounts.TrustedDevice
  alias RetroHexChat.Accounts.TrustedDeviceEvent
  alias RetroHexChat.Accounts.TrustedDeviceNick
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick

  @pubsub RetroHexChat.PubSub
  @selector_bytes 18
  @secret_bytes 32
  @default_ttl_days 90
  @max_events 20

  @type remember_result :: %{
          device: TrustedDevice.t(),
          cookie_value: String.t(),
          max_age: pos_integer()
        }

  @spec cookie_max_age() :: pos_integer()
  def cookie_max_age do
    ttl_days() * 24 * 60 * 60
  end

  @spec make_session_ref() :: String.t()
  def make_session_ref, do: random_token(@secret_bytes)

  @spec hash_fingerprint(String.t() | nil) :: String.t() | nil
  def hash_fingerprint(nil), do: nil
  def hash_fingerprint(""), do: nil

  def hash_fingerprint(value) when is_binary(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16(case: :lower)
  end

  @spec verify_cookie(String.t() | nil) :: {:ok, TrustedDevice.t()} | {:error, atom()}
  def verify_cookie(nil), do: {:error, :missing}
  def verify_cookie(""), do: {:error, :missing}

  def verify_cookie(cookie_value) do
    with {:ok, selector, secret} <- parse_cookie(cookie_value),
         %TrustedDevice{} = device <- Repo.get_by(TrustedDevice, selector: selector),
         :ok <- ensure_device_usable(device),
         true <- secure_hash_match?(device.token_hash, secret) do
      touch_device(device)
    else
      nil -> {:error, :not_found}
      false -> {:error, :token_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec remembered_nicks(integer() | nil) :: [map()]
  def remembered_nicks(nil), do: []

  def remembered_nicks(device_id) do
    now = DateTime.utc_now()

    from(g in TrustedDeviceNick,
      join: d in TrustedDevice,
      on: d.id == g.trusted_device_id,
      join: n in RegisteredNick,
      on: n.id == g.registered_nick_id,
      where: d.id == ^device_id,
      where: is_nil(d.revoked_at),
      where: is_nil(g.revoked_at),
      where: d.expires_at > ^now,
      order_by: [desc: g.last_used_at, asc: n.nickname],
      select: %{
        nickname: n.nickname,
        registered_nick_id: n.id,
        device_id: d.id,
        label: d.label,
        last_used_at: g.last_used_at
      }
    )
    |> Repo.all()
  end

  @spec nick_remembered?(integer() | nil, String.t()) :: boolean()
  def nick_remembered?(nil, _nickname), do: false

  def nick_remembered?(device_id, nickname) do
    Enum.any?(remembered_nicks(device_id), &(&1.nickname == nickname))
  end

  @spec authorize_cookie(String.t() | nil, String.t()) ::
          {:ok, %{device: TrustedDevice.t(), nick: RegisteredNick.t()}} | {:error, atom()}
  def authorize_cookie(cookie_value, nickname) do
    with {:ok, %TrustedDevice{} = device} <- verify_cookie(cookie_value),
         %RegisteredNick{} = nick <- Repo.get_by(RegisteredNick, nickname: nickname),
         %TrustedDeviceNick{} = grant <- active_grant(device.id, nick.id) do
      now = DateTime.utc_now()

      grant
      |> TrustedDeviceNick.changeset(%{last_used_at: now})
      |> Repo.update()

      log_event("device.nick.used", device, nick, nickname)

      {:ok, %{device: device, nick: nick}}
    else
      nil -> {:error, :not_authorized}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec remember_nick(String.t() | nil, String.t(), keyword()) ::
          {:ok, remember_result()} | {:error, atom()}
  def remember_nick(cookie_value, nickname, opts \\ []) do
    case Repo.get_by(RegisteredNick, nickname: nickname) do
      %RegisteredNick{} = nick ->
        Repo.transaction(fn ->
          {device, cookie} = resolve_or_create_device(cookie_value, opts)
          grant = upsert_grant(device, nick, nickname)

          log_event("device.nick.granted", device, nick, nickname, %{
            grant_id: grant.id,
            label: device.label
          })

          %{device: device, cookie_value: cookie, max_age: cookie_max_age()}
        end)
        |> case do
          {:ok, result} -> {:ok, result}
          {:error, _reason} -> {:error, :remember_failed}
        end

      nil ->
        {:error, :nick_not_registered}
    end
  end

  @spec record_session_start(String.t(), integer() | nil, map()) ::
          {:ok, ChatDeviceSession.t()} | {:error, Ecto.Changeset.t()}
  def record_session_start(nickname, trusted_device_id, client_info \\ %{}) do
    now = DateTime.utc_now()
    registered_nick_id = registered_nick_id(nickname)

    attrs = %{
      session_ref: make_session_ref(),
      trusted_device_id: trusted_device_id,
      registered_nick_id: registered_nick_id,
      nickname: nickname,
      client_info: normalize_client_info(client_info),
      connected_at: now,
      last_seen_at: now
    }

    %ChatDeviceSession{}
    |> ChatDeviceSession.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, session} ->
        log_event("session.started", session.trusted_device_id, registered_nick_id, nickname, %{
          session_id: session.id
        })

      _ ->
        :ok
    end)
  end

  @spec record_session_stop(String.t() | nil, String.t() | nil) :: :ok
  def record_session_stop(nil, _reason), do: :ok

  def record_session_stop(session_ref, reason) do
    now = DateTime.utc_now()

    from(s in ChatDeviceSession,
      where: s.session_ref == ^session_ref and is_nil(s.disconnected_at)
    )
    |> Repo.update_all(
      set: [
        disconnected_at: now,
        last_seen_at: now,
        disconnect_reason: truncate(reason || "disconnected", 100)
      ]
    )

    :ok
  end

  @spec touch_session(String.t() | nil) :: :ok
  def touch_session(nil), do: :ok

  def touch_session(session_ref) do
    from(s in ChatDeviceSession,
      where: s.session_ref == ^session_ref and is_nil(s.disconnected_at)
    )
    |> Repo.update_all(set: [last_seen_at: DateTime.utc_now()])

    :ok
  end

  @spec snapshot_for_nick(String.t(), integer() | nil, String.t() | nil) :: map()
  def snapshot_for_nick(nickname, current_device_id \\ nil, current_session_ref \\ nil) do
    %{
      devices: list_devices_for_nick(nickname, current_device_id),
      sessions: list_sessions_for_nick(nickname, current_session_ref),
      events: list_events_for_nick(nickname)
    }
  end

  @spec list_devices_for_nick(String.t(), integer() | nil) :: [map()]
  def list_devices_for_nick(nickname, current_device_id \\ nil) do
    now = DateTime.utc_now()

    rows =
      from(g in TrustedDeviceNick,
        join: n in RegisteredNick,
        on: n.id == g.registered_nick_id,
        join: d in TrustedDevice,
        on: d.id == g.trusted_device_id,
        where: n.nickname == ^nickname,
        where: is_nil(g.revoked_at),
        where: is_nil(d.revoked_at),
        where: d.expires_at > ^now,
        order_by: [desc: d.last_seen_at],
        select: {d, g}
      )
      |> Repo.all()

    device_ids = Enum.map(rows, fn {device, _grant} -> device.id end)
    session_counts = active_session_counts(device_ids, nickname)

    Enum.map(rows, fn {device, grant} ->
      %{
        id: device.id,
        label: device.label || default_label(device),
        browser: device.browser,
        os: device.os,
        device_type: device.device_type,
        language: device.language,
        timezone: device.timezone,
        screen: device.screen,
        first_seen_at: device.first_seen_at,
        last_seen_at: device.last_seen_at,
        expires_at: device.expires_at,
        granted_at: grant.granted_at,
        last_used_at: grant.last_used_at,
        current?: device.id == current_device_id,
        revoked?: false,
        active_sessions: Map.get(session_counts, device.id, 0)
      }
    end)
  end

  @spec list_sessions_for_nick(String.t(), String.t() | nil) :: [map()]
  def list_sessions_for_nick(nickname, current_session_ref \\ nil) do
    from(s in ChatDeviceSession,
      left_join: d in TrustedDevice,
      on: d.id == s.trusted_device_id,
      where: s.nickname == ^nickname,
      where: is_nil(s.disconnected_at),
      order_by: [desc: s.connected_at],
      select: {s, d}
    )
    |> Repo.all()
    |> Enum.map(&session_row_to_map(&1, current_session_ref))
  end

  defp session_row_to_map({session, device}, current_session_ref) do
    client_info = session.client_info || %{}

    %{
      id: session.id,
      session_ref: session.session_ref,
      device_id: session.trusted_device_id,
      label: session_device_label(device),
      browser: session_client_value(client_info, "browser", device, :browser),
      os: session_client_value(client_info, "os", device, :os),
      language: session_client_value(client_info, "language", device, :language),
      timezone: session_client_value(client_info, "timezone", device, :timezone),
      screen: session_client_value(client_info, "screen", device, :screen),
      connected_at: session.connected_at,
      last_seen_at: session.last_seen_at,
      current?: session.session_ref == current_session_ref
    }
  end

  defp session_device_label(nil), do: "Unremembered session"
  defp session_device_label(device), do: device.label || default_label(device)

  defp session_client_value(client_info, key, nil, _field), do: Map.get(client_info, key)

  defp session_client_value(client_info, key, device, field) do
    Map.get(client_info, key) || Map.get(device, field)
  end

  @spec list_events_for_nick(String.t(), non_neg_integer()) :: [map()]
  def list_events_for_nick(nickname, limit \\ @max_events) do
    from(e in TrustedDeviceEvent,
      join: n in RegisteredNick,
      on: n.id == e.registered_nick_id,
      left_join: d in TrustedDevice,
      on: d.id == e.trusted_device_id,
      where: n.nickname == ^nickname,
      order_by: [desc: e.inserted_at],
      limit: ^limit,
      select: {e, d}
    )
    |> Repo.all()
    |> Enum.map(fn {event, device} ->
      %{
        id: event.id,
        action: event.action,
        actor_nickname: event.actor_nickname,
        details: event.details,
        inserted_at: event.inserted_at,
        device_id: event.trusted_device_id,
        device_label: device && (device.label || default_label(device))
      }
    end)
  end

  @spec rename_device_for_nick(String.t(), integer(), String.t(), String.t()) ::
          :ok | {:error, String.t()}
  def rename_device_for_nick(nickname, device_id, label, actor) do
    with {:ok, nick, device, _grant} <- owned_device(nickname, device_id) do
      label = label |> String.trim() |> truncate(100)

      case device |> TrustedDevice.changeset(%{label: label}) |> Repo.update() do
        {:ok, updated} ->
          log_event("device.renamed", updated, nick, actor, %{label: label})
          :ok

        {:error, _changeset} ->
          {:error, dgettext("accounts", "Could not rename the terminal.")}
      end
    else
      {:error, :not_found} ->
        {:error, dgettext("accounts", "Trusted terminal not found for this nick.")}
    end
  end

  @spec revoke_device_for_nick(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def revoke_device_for_nick(nickname, device_id, actor) do
    with {:ok, nick, device, grant} <- owned_device(nickname, device_id) do
      revoke_grant(grant, actor)
      log_event("device.nick.revoked", device, nick, actor)
      revoke_device_if_empty(device, actor)
      kill_sessions_for_device(nickname, device.id, actor)
      :ok
    else
      {:error, :not_found} ->
        {:error, dgettext("accounts", "Trusted terminal not found for this nick.")}
    end
  end

  @spec sign_out_device_for_nick(String.t(), integer(), String.t(), String.t() | nil) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def sign_out_device_for_nick(nickname, device_id, actor, except_session_ref \\ nil) do
    with {:ok, nick, device, grant} <- owned_device(nickname, device_id) do
      revoke_grant(grant, actor)
      log_event("device.nick.signed_out", device, nick, actor)
      revoke_device_if_empty(device, actor)
      {:ok, kill_sessions_for_device(nickname, device.id, actor, except_session_ref)}
    else
      {:error, :not_found} ->
        {:error, dgettext("accounts", "Trusted terminal not found for this nick.")}
    end
  end

  @spec revoke_current_device(integer(), String.t()) :: :ok | {:error, String.t()}
  def revoke_current_device(device_id, actor) when is_integer(device_id) do
    case Repo.get(TrustedDevice, device_id) do
      %TrustedDevice{} = device ->
        now = DateTime.utc_now()

        from(g in TrustedDeviceNick,
          where: g.trusted_device_id == ^device.id and is_nil(g.revoked_at)
        )
        |> Repo.update_all(set: [revoked_at: now, revoked_by_nickname: actor])

        device
        |> TrustedDevice.changeset(%{revoked_at: now, revoked_by_nickname: actor})
        |> Repo.update()

        log_event("device.revoked", device, nil, actor)
        :ok

      nil ->
        {:error, dgettext("accounts", "Trusted terminal not found.")}
    end
  end

  def revoke_current_device(_device_id, _actor),
    do: {:error, dgettext("accounts", "This terminal is not remembered.")}

  @spec revoke_all_for_nick(String.t(), String.t()) :: :ok
  def revoke_all_for_nick(nickname, actor) do
    case Repo.get_by(RegisteredNick, nickname: nickname) do
      %RegisteredNick{} = nick ->
        now = DateTime.utc_now()

        from(g in TrustedDeviceNick,
          where: g.registered_nick_id == ^nick.id and is_nil(g.revoked_at)
        )
        |> Repo.update_all(set: [revoked_at: now, revoked_by_nickname: actor])

        log_event("device.nick.revoked_all", nil, nick, actor)
        :ok

      nil ->
        :ok
    end
  end

  @spec sign_out_all_devices_for_nick(String.t(), String.t(), String.t() | nil) ::
          non_neg_integer()
  def sign_out_all_devices_for_nick(nickname, actor, except_session_ref \\ nil) do
    device_ids =
      nickname
      |> list_devices_for_nick()
      |> Enum.map(& &1.id)

    revoke_all_for_nick(nickname, actor)

    device_ids
    |> Enum.map(&kill_sessions_for_device(nickname, &1, actor, except_session_ref))
    |> Enum.sum()
  end

  @spec kill_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  def kill_session(nickname, session_id, actor) do
    case active_session_for_nick(nickname, session_id) do
      %ChatDeviceSession{} = session ->
        reason =
          dgettext("accounts", "Session ended from Trusted Terminals by %{actor}", actor: actor)

        broadcast_session_disconnect(session.session_ref, reason)
        record_session_stop(session.session_ref, "killed_by_#{actor}")

        log_event(
          "session.killed",
          session.trusted_device_id,
          session.registered_nick_id,
          actor,
          %{
            session_id: session.id
          }
        )

        :ok

      nil ->
        {:error, dgettext("accounts", "Active session not found for this nick.")}
    end
  end

  @spec kill_all_sessions(String.t(), String.t(), String.t() | nil) :: non_neg_integer()
  def kill_all_sessions(nickname, actor, except_session_ref \\ nil) do
    sessions =
      from(s in ChatDeviceSession,
        where: s.nickname == ^nickname,
        where: is_nil(s.disconnected_at)
      )
      |> maybe_exclude_session(except_session_ref)
      |> Repo.all()

    Enum.each(sessions, fn session ->
      reason =
        dgettext("accounts", "Session ended from Trusted Terminals by %{actor}", actor: actor)

      broadcast_session_disconnect(session.session_ref, reason)
      record_session_stop(session.session_ref, "killed_by_#{actor}")
    end)

    case Repo.get_by(RegisteredNick, nickname: nickname) do
      nil ->
        :ok

      nick ->
        log_event("session.killed_all", nil, nick, actor, %{count: length(sessions)})
    end

    length(sessions)
  end

  # -- Private helpers --

  defp ttl_days do
    Application.get_env(:retro_hex_chat, :trusted_device_ttl_days, @default_ttl_days)
  end

  defp parse_cookie(cookie_value) do
    case String.split(cookie_value, ".", parts: 2) do
      [selector, secret] when selector != "" and secret != "" -> {:ok, selector, secret}
      _ -> {:error, :invalid_cookie}
    end
  end

  defp ensure_device_usable(%TrustedDevice{revoked_at: %DateTime{}}), do: {:error, :revoked}

  defp ensure_device_usable(%TrustedDevice{expires_at: expires_at}) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
      :ok
    else
      {:error, :expired}
    end
  end

  defp secure_hash_match?(expected_hash, secret) do
    expected_hash == token_hash(secret)
  end

  defp touch_device(device) do
    device
    |> TrustedDevice.changeset(%{last_seen_at: DateTime.utc_now()})
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, _} -> {:ok, device}
    end
  end

  defp active_grant(device_id, registered_nick_id) do
    Repo.one(
      from(g in TrustedDeviceNick,
        where: g.trusted_device_id == ^device_id,
        where: g.registered_nick_id == ^registered_nick_id,
        where: is_nil(g.revoked_at)
      )
    )
  end

  defp resolve_or_create_device(cookie_value, opts) do
    case verify_cookie(cookie_value) do
      {:ok, device} ->
        {update_device_metadata(device, opts), cookie_value}

      {:error, _reason} ->
        create_device!(opts)
    end
  end

  defp create_device!(opts) do
    selector = random_token(@selector_bytes)
    secret = random_token(@secret_bytes)
    now = DateTime.utc_now()

    attrs =
      opts
      |> device_attrs()
      |> Map.merge(%{
        selector: selector,
        token_hash: token_hash(secret),
        first_seen_at: now,
        last_seen_at: now,
        expires_at: DateTime.add(now, ttl_days(), :day)
      })

    device =
      %TrustedDevice{}
      |> TrustedDevice.changeset(attrs)
      |> Repo.insert!()

    log_event("device.created", device, nil, Keyword.get(opts, :actor_nickname))

    {device, "#{selector}.#{secret}"}
  end

  defp update_device_metadata(device, opts) do
    attrs =
      opts
      |> device_attrs()
      |> Map.put(:last_seen_at, DateTime.utc_now())
      |> Map.put(:expires_at, DateTime.add(DateTime.utc_now(), ttl_days(), :day))
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    case device |> TrustedDevice.changeset(attrs) |> Repo.update() do
      {:ok, updated} -> updated
      {:error, _} -> device
    end
  end

  defp device_attrs(opts) do
    client_info = normalize_client_info(Keyword.get(opts, :client_info, %{}))
    label = Keyword.get(opts, :label) || default_label(client_info)

    %{
      label: truncate(label, 100),
      browser: truncate(value(client_info, :browser), 100),
      os: truncate(value(client_info, :os), 100),
      device_type: device_type(client_info),
      language: truncate(value(client_info, :language), 32),
      timezone: truncate(value(client_info, :timezone), 100),
      screen: truncate(value(client_info, :screen), 32),
      color_depth: value(client_info, :color_depth),
      touch: value(client_info, :touch) == true,
      cores: value(client_info, :cores),
      user_agent_hash: Keyword.get(opts, :user_agent_hash),
      last_ip_hash: Keyword.get(opts, :ip_hash)
    }
  end

  defp upsert_grant(device, nick, _actor) do
    now = DateTime.utc_now()

    case Repo.get_by(TrustedDeviceNick,
           trusted_device_id: device.id,
           registered_nick_id: nick.id
         ) do
      nil ->
        %TrustedDeviceNick{}
        |> TrustedDeviceNick.changeset(%{
          trusted_device_id: device.id,
          registered_nick_id: nick.id,
          granted_at: now,
          last_used_at: now
        })
        |> Repo.insert!()

      grant ->
        grant
        |> TrustedDeviceNick.changeset(%{
          last_used_at: now,
          revoked_at: nil,
          revoked_by_nickname: nil
        })
        |> Repo.update!()
    end
  end

  defp registered_nick_id(nickname) do
    case Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> nil
      nick -> nick.id
    end
  end

  defp active_session_counts([], _nickname), do: %{}

  defp active_session_counts(device_ids, nickname) do
    from(s in ChatDeviceSession,
      where: s.nickname == ^nickname,
      where: s.trusted_device_id in ^device_ids,
      where: is_nil(s.disconnected_at),
      group_by: s.trusted_device_id,
      select: {s.trusted_device_id, count(s.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp owned_device(nickname, device_id) do
    row =
      from(g in TrustedDeviceNick,
        join: n in RegisteredNick,
        on: n.id == g.registered_nick_id,
        join: d in TrustedDevice,
        on: d.id == g.trusted_device_id,
        where: n.nickname == ^nickname,
        where: d.id == ^device_id,
        where: is_nil(g.revoked_at),
        where: is_nil(d.revoked_at),
        select: {n, d, g}
      )
      |> Repo.one()

    case row do
      {nick, device, grant} -> {:ok, nick, device, grant}
      nil -> {:error, :not_found}
    end
  end

  defp revoke_grant(grant, actor) do
    grant
    |> TrustedDeviceNick.changeset(%{
      revoked_at: DateTime.utc_now(),
      revoked_by_nickname: actor
    })
    |> Repo.update()
  end

  defp revoke_device_if_empty(device, actor) do
    active =
      from(g in TrustedDeviceNick,
        where: g.trusted_device_id == ^device.id and is_nil(g.revoked_at),
        select: count(g.id)
      )
      |> Repo.one()

    if active == 0 do
      now = DateTime.utc_now()

      device
      |> TrustedDevice.changeset(%{revoked_at: now, revoked_by_nickname: actor})
      |> Repo.update()
    end
  end

  defp kill_sessions_for_device(nickname, device_id, actor, except_session_ref \\ nil) do
    sessions =
      from(s in ChatDeviceSession,
        where: s.nickname == ^nickname,
        where: s.trusted_device_id == ^device_id,
        where: is_nil(s.disconnected_at)
      )
      |> maybe_exclude_session(except_session_ref)
      |> Repo.all()

    Enum.each(sessions, fn session ->
      reason =
        dgettext("accounts", "Session ended from Trusted Terminals by %{actor}", actor: actor)

      broadcast_session_disconnect(session.session_ref, reason)
      record_session_stop(session.session_ref, "device_revoked_by_#{actor}")
    end)

    length(sessions)
  end

  defp active_session_for_nick(nickname, session_id) do
    Repo.one(
      from(s in ChatDeviceSession,
        where: s.nickname == ^nickname,
        where: s.id == ^session_id,
        where: is_nil(s.disconnected_at)
      )
    )
  end

  defp maybe_exclude_session(query, nil), do: query
  defp maybe_exclude_session(query, ""), do: query

  defp maybe_exclude_session(query, session_ref) do
    where(query, [s], s.session_ref != ^session_ref)
  end

  defp broadcast_session_disconnect(session_ref, reason) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "chat_device_session:#{session_ref}",
      {:force_disconnect, %{reason: reason}}
    )
  end

  defp log_event(action, device, nick, actor, details \\ %{})

  defp log_event(action, %TrustedDevice{} = device, nick, actor, details) do
    log_event(action, device.id, nick && nick.id, actor, details)
  end

  defp log_event(action, nil, %RegisteredNick{} = nick, actor, details) do
    log_event(action, nil, nick.id, actor, details)
  end

  defp log_event(action, device_id, registered_nick_id, actor, details) do
    attrs = %{
      trusted_device_id: device_id,
      registered_nick_id: registered_nick_id,
      actor_nickname: actor,
      action: action,
      details: details,
      inserted_at: DateTime.utc_now()
    }

    %TrustedDeviceEvent{}
    |> TrustedDeviceEvent.changeset(attrs)
    |> Repo.insert()

    :ok
  end

  defp normalize_client_info(client_info) when is_map(client_info) do
    client_info
    |> Enum.map(fn {key, value} -> {to_string(key), normalize_client_value(value)} end)
    |> Map.new()
  end

  defp normalize_client_info(_client_info), do: %{}

  defp normalize_client_value(value) when is_binary(value), do: truncate(value, 100)
  defp normalize_client_value(value) when is_integer(value), do: value
  defp normalize_client_value(value) when is_boolean(value), do: value
  defp normalize_client_value(_value), do: nil

  defp value(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, to_string(key), Map.get(map, key))
  end

  defp default_label(%TrustedDevice{} = device) do
    default_label(%{"browser" => device.browser, "os" => device.os})
  end

  defp default_label(client_info) do
    browser = value(client_info, :browser) || dgettext("accounts", "Browser")
    os = value(client_info, :os) || dgettext("accounts", "Unknown OS")
    "#{browser} on #{os}"
  end

  defp device_type(client_info) do
    cond do
      value(client_info, :touch) == true -> "touch"
      is_binary(value(client_info, :screen)) -> "desktop"
      true -> "unknown"
    end
  end

  defp token_hash(secret), do: hash_fingerprint(secret)

  defp random_token(bytes) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp truncate(nil, _max), do: nil
  defp truncate(value, max) when is_binary(value), do: String.slice(value, 0, max)
  defp truncate(value, _max), do: value
end
