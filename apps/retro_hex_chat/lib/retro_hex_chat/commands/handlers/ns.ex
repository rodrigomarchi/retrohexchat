defmodule RetroHexChat.Commands.Handlers.Ns do
  @moduledoc "Handler for /ns (NickServ commands)"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Args
  alias RetroHexChat.Commands.Handler.Guards
  alias RetroHexChat.Commands.Timestamp
  alias RetroHexChat.Services.NickServ

  use RetroHexChat.Commands.Handler,
    name: "ns",
    category: :advanced,
    syntax: dgettext("commands", "/ns <subcommand> [args]"),
    summary:
      dgettext(
        "commands",
        "Register and protect your nickname with a password through NickServ, the nickname services bot."
      ),
    description:
      dgettext(
        "commands",
        "Register and protect your nickname with a password through NickServ.\nSubcommands: register <password>, identify <password>, ghost <nick> <password>, info [nick], drop <password>, devices, sessions, revoke-device <id|all>, kill-session <id|all>, help.\nRegister: claims current nickname. Identify: authenticates each session.\nGhost: disconnects a stale session using the registered nickname's password."
      ),
    examples: [
      dgettext("commands", "/ns register mypassword"),
      dgettext("commands", "/ns identify mypassword"),
      dgettext("commands", "/ns ghost othernick mypassword"),
      dgettext("commands", "/ns info"),
      dgettext("commands", "/ns drop mypassword"),
      dgettext("commands", "/ns devices"),
      dgettext("commands", "/ns sessions"),
      dgettext("commands", "/ns revoke-device 12"),
      dgettext("commands", "/ns kill-session 44")
    ],
    parameters: [
      Parameter.required(
        :text,
        "subcommand",
        dgettext(
          "commands",
          "Subcommand: register, identify, ghost, info, drop, devices, sessions, revoke-device, kill-session"
        )
      ),
      Parameter.optional(:text, "args", dgettext("commands", "Subcommand arguments"))
    ],
    subcommands: [
      %{
        name: "register",
        description: dgettext("commands", "Register your nickname with a password")
      },
      %{
        name: "identify",
        description: dgettext("commands", "Authenticate with your registered password")
      },
      %{
        name: "ghost",
        description: dgettext("commands", "Disconnect a stale session using its password")
      },
      %{
        name: "info",
        description: dgettext("commands", "View registration info for a nickname")
      },
      %{name: "drop", description: dgettext("commands", "Delete your nickname registration")},
      %{name: "devices", description: dgettext("commands", "List trusted terminals")},
      %{name: "sessions", description: dgettext("commands", "List active sessions")},
      %{name: "revoke-device", description: dgettext("commands", "Revoke a trusted terminal")},
      %{name: "kill-session", description: dgettext("commands", "End an active session")},
      %{name: "help", description: dgettext("commands", "Show NickServ help")}
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error,
     dgettext(
       "commands",
       "Usage: /ns <register|identify|ghost|info|drop|devices|sessions|revoke-device|kill-session|help> [args]"
     )}
  end

  def execute(["register" | args], context) do
    password = Enum.join(args, " ")

    if password == "" do
      {:error, dgettext("commands", "Usage: /ns register <password>")}
    else
      call_register(context.nickname, password, context[:session_id])
    end
  end

  def execute(["identify" | args], context) do
    password = Enum.join(args, " ")

    if password == "" do
      {:error, dgettext("commands", "Usage: /ns identify <password>")}
    else
      call_identify(context.nickname, password, context[:session_id])
    end
  end

  def execute(["ghost" | args], context) do
    case args do
      [target | password_parts] when password_parts != [] ->
        call_ghost(target, Enum.join(password_parts, " "), context.nickname)

      _ ->
        {:error, dgettext("commands", "Usage: /ns ghost <nickname> <password>")}
    end
  end

  def execute(["info" | args], context) do
    target =
      case args do
        [nick | _] -> nick
        [] -> context.nickname
      end

    call_info(target)
  end

  def execute(["drop" | args], context) do
    password = Enum.join(args, " ")

    if password == "" do
      {:error, dgettext("commands", "Usage: /ns drop <password>")}
    else
      call_drop(context.nickname, password)
    end
  end

  def execute(["devices"], context) do
    require_identified(context, fn -> call_devices(context.nickname) end)
  end

  def execute(["sessions"], context) do
    require_identified(context, fn -> call_sessions(context.nickname) end)
  end

  def execute(["revoke-device" | args], context) do
    require_identified(context, fn -> call_revoke_device(args, context.nickname) end)
  end

  def execute(["kill-session" | args], context) do
    require_identified(context, fn -> call_kill_session(args, context.nickname) end)
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown NickServ command: #{subcmd}. Try /ns help"}
  end

  # -- Private helpers --

  defp call_register(nickname, password, session_id) do
    case NickServ.register(nickname, password) do
      {:ok, msg} ->
        bind_session(nickname, session_id)
        service_message(msg)

      {:error, msg} ->
        {:error, nickserv_message(msg)}
    end
  end

  defp call_identify(nickname, password, session_id) do
    case NickServ.identify(nickname, password) do
      {:ok, msg} ->
        bind_session(nickname, session_id)
        service_message(msg)

      {:error, msg} ->
        {:error, nickserv_message(msg)}
    end
  end

  # The proof is this browser session's, so a reload of it stays identified.
  defp bind_session(_nickname, nil), do: :ok
  defp bind_session(nickname, session_id), do: NickServ.bind_session(nickname, session_id)

  defp call_ghost(target, password, requester) do
    case NickServ.ghost(target, password, requester) do
      {:ok, msg} ->
        service_message(msg)

      {:error, msg} ->
        {:error, nickserv_message(msg)}
    end
  end

  defp call_info(nickname) do
    case NickServ.info(nickname) do
      {:ok, info} ->
        text =
          dgettext(
            "commands",
            "[NickServ] %{nickname}: registered %{registered_at}, identified: %{identified}",
            nickname: nickname,
            registered_at: Timestamp.format(info.registered_at),
            identified: info.identified
          )

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, nickserv_message(msg)}
    end
  end

  defp call_drop(nickname, password) do
    case NickServ.drop(nickname, password) do
      {:ok, msg} ->
        service_message(msg)

      {:error, msg} ->
        {:error, nickserv_message(msg)}
    end
  end

  defp call_devices(nickname) do
    case TrustedDevices.list_devices_for_nick(nickname) do
      [] ->
        service_message(dgettext("commands", "No trusted terminals for this nickname."))

      devices ->
        lines =
          devices
          |> Enum.map(&format_device_line/1)
          |> Enum.join("\n")

        service_message(dgettext("commands", "Trusted terminals:\n%{lines}", lines: lines))
    end
  end

  defp call_sessions(nickname) do
    case TrustedDevices.list_sessions_for_nick(nickname).items do
      [] ->
        service_message(dgettext("commands", "No active sessions for this nickname."))

      sessions ->
        lines =
          sessions
          |> Enum.map(&format_session_line/1)
          |> Enum.join("\n")

        service_message(dgettext("commands", "Active sessions:\n%{lines}", lines: lines))
    end
  end

  defp call_revoke_device(["all"], nickname) do
    count = TrustedDevices.sign_out_all_devices_for_nick(nickname, nickname)

    service_message(
      dgettext(
        "commands",
        "All trusted terminals revoked. %{count} active sessions ended.",
        count: count
      )
    )
  end

  defp call_revoke_device([id], nickname) do
    by_id(
      id,
      &TrustedDevices.revoke_device_for_nick(nickname, &1, nickname),
      dgettext("commands", "Trusted terminal %{id} revoked.", id: id),
      revoke_device_usage()
    )
  end

  defp call_revoke_device(_args, _nickname), do: {:error, revoke_device_usage()}

  defp call_kill_session(["all"], nickname) do
    count = TrustedDevices.kill_all_sessions(nickname, nickname)

    service_message(dgettext("commands", "%{count} active sessions ended.", count: count))
  end

  defp call_kill_session([id], nickname) do
    by_id(
      id,
      &TrustedDevices.kill_session(nickname, &1, nickname),
      dgettext("commands", "Session %{id} ended.", id: id),
      kill_session_usage()
    )
  end

  defp call_kill_session(_args, _nickname), do: {:error, kill_session_usage()}

  # One terminal or session, by its id: done, refused in NickServ's words, or
  # the usage when the id does not parse.
  defp by_id(id, act, done, usage) do
    with {:ok, parsed} <- Args.positive_id(id, :invalid_id),
         :ok <- act.(parsed) do
      service_message(done)
    else
      {:error, message} when is_binary(message) -> {:error, nickserv_message(message)}
      {:error, _reason} -> {:error, usage}
    end
  end

  defp revoke_device_usage, do: dgettext("commands", "Usage: /ns revoke-device <id|all>")
  defp kill_session_usage, do: dgettext("commands", "Usage: /ns kill-session <id|all>")

  defp require_identified(context, fun) do
    message =
      nickserv_message(
        dgettext("commands", "You must be identified to manage trusted terminals.")
      )

    with :ok <- Guards.require_identified(context, message), do: fun.()
  end

  defp service_message(message), do: {:ok, :system, %{content: nickserv_message(message)}}

  defp nickserv_message(message) do
    dgettext("commands", "[NickServ] %{message}", message: message)
  end

  defp format_device_line(device) do
    dgettext(
      "commands",
      "#%{id} %{label} | %{browser} / %{os} | active %{sessions} | last %{last_seen}",
      id: device.id,
      label: device.label,
      browser: device.browser || dgettext("commands", "Unknown browser"),
      os: device.os || dgettext("commands", "Unknown OS"),
      sessions: device.active_sessions,
      last_seen: format_datetime(device.last_seen_at)
    )
  end

  defp format_session_line(session) do
    dgettext(
      "commands",
      "#%{id} %{label} | %{browser} / %{os} | last %{last_seen}",
      id: session.id,
      label: session.label,
      browser: session.browser || dgettext("commands", "Unknown browser"),
      os: session.os || dgettext("commands", "Unknown OS"),
      last_seen: format_datetime(session.last_seen_at)
    )
  end

  defp format_datetime(nil), do: dgettext("commands", "never")

  defp format_datetime(datetime), do: Timestamp.format(datetime)
end
