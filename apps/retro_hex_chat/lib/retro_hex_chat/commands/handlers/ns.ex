defmodule RetroHexChat.Commands.Handlers.Ns do
  @moduledoc "Handler for /ns (NickServ commands)"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.NickServ

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

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
      call_register(context.nickname, password)
    end
  end

  def execute(["identify" | args], context) do
    password = Enum.join(args, " ")

    if password == "" do
      {:error, dgettext("commands", "Usage: /ns identify <password>")}
    else
      call_identify(context.nickname, password)
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

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "ns",
      syntax: dgettext("commands", "/ns <subcommand> [args]"),
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
      ]
    }
  end

  # -- Private helpers --

  defp call_register(nickname, password) do
    case NickServ.register(nickname, password) do
      {:ok, msg} ->
        {:ok, :system, %{content: dgettext("commands", "[NickServ] %{message}", message: msg)}}

      {:error, msg} ->
        {:error, dgettext("commands", "[NickServ] %{message}", message: msg)}
    end
  end

  defp call_identify(nickname, password) do
    case NickServ.identify(nickname, password) do
      {:ok, msg} ->
        {:ok, :system, %{content: dgettext("commands", "[NickServ] %{message}", message: msg)}}

      {:error, msg} ->
        {:error, dgettext("commands", "[NickServ] %{message}", message: msg)}
    end
  end

  defp call_ghost(target, password, requester) do
    case NickServ.ghost(target, password, requester) do
      {:ok, msg} ->
        {:ok, :system, %{content: dgettext("commands", "[NickServ] %{message}", message: msg)}}

      {:error, msg} ->
        {:error, dgettext("commands", "[NickServ] %{message}", message: msg)}
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
            registered_at: info.registered_at,
            identified: info.identified
          )

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, dgettext("commands", "[NickServ] %{message}", message: msg)}
    end
  end

  defp call_drop(nickname, password) do
    case NickServ.drop(nickname, password) do
      {:ok, msg} ->
        {:ok, :system, %{content: dgettext("commands", "[NickServ] %{message}", message: msg)}}

      {:error, msg} ->
        {:error, dgettext("commands", "[NickServ] %{message}", message: msg)}
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
    case TrustedDevices.list_sessions_for_nick(nickname) do
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
    with {:ok, device_id} <- parse_id(id),
         :ok <- TrustedDevices.revoke_device_for_nick(nickname, device_id, nickname) do
      service_message(dgettext("commands", "Trusted terminal %{id} revoked.", id: id))
    else
      {:error, message} when is_binary(message) ->
        {:error, nickserv_message(message)}

      {:error, _reason} ->
        {:error, revoke_device_usage()}
    end
  end

  defp call_revoke_device(_args, _nickname), do: {:error, revoke_device_usage()}

  defp call_kill_session(["all"], nickname) do
    count = TrustedDevices.kill_all_sessions(nickname, nickname)

    service_message(dgettext("commands", "%{count} active sessions ended.", count: count))
  end

  defp call_kill_session([id], nickname) do
    with {:ok, session_id} <- parse_id(id),
         :ok <- TrustedDevices.kill_session(nickname, session_id, nickname) do
      service_message(dgettext("commands", "Session %{id} ended.", id: id))
    else
      {:error, message} when is_binary(message) ->
        {:error, nickserv_message(message)}

      {:error, _reason} ->
        {:error, kill_session_usage()}
    end
  end

  defp call_kill_session(_args, _nickname), do: {:error, kill_session_usage()}

  defp revoke_device_usage, do: dgettext("commands", "Usage: /ns revoke-device <id|all>")
  defp kill_session_usage, do: dgettext("commands", "Usage: /ns kill-session <id|all>")

  defp require_identified(%{identified: true}, fun), do: fun.()

  defp require_identified(_context, _fun) do
    {:error,
     nickserv_message(dgettext("commands", "You must be identified to manage trusted terminals."))}
  end

  defp service_message(message), do: {:ok, :system, %{content: nickserv_message(message)}}

  defp nickserv_message(message) do
    dgettext("commands", "[NickServ] %{message}", message: message)
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_id), do: {:error, :invalid_id}

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

  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")
  end

  defp format_datetime(_datetime), do: dgettext("commands", "unknown")

  @impl true
  def category, do: :advanced

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "ns",
      syntax: dgettext("commands", "/ns <subcommand> [args]"),
      description:
        dgettext(
          "commands",
          "Register and protect your nickname with a password through NickServ, the nickname services bot."
        ),
      category: :advanced,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: true,
          type: :text,
          position: 0,
          description:
            dgettext(
              "commands",
              "Subcommand: register, identify, ghost, info, drop, devices, sessions, revoke-device, kill-session"
            )
        },
        %Parameter{
          name: "args",
          required: false,
          type: :text,
          position: 1,
          description: dgettext("commands", "Subcommand arguments")
        }
      ],
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
    }
  end
end
