defmodule RetroHexChat.Commands.Handlers.Ns do
  @moduledoc "Handler for /ns (NickServ commands)"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.NickServ

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /ns <register|identify|ghost|info|drop|help> [args]")}
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
          "Register and protect your nickname with a password through NickServ.\nSubcommands: register <password>, identify <password>, ghost <nick> <password>, info [nick], drop <password>, help.\nRegister: claims current nickname. Identify: authenticates each session.\nGhost: disconnects a stale session using the registered nickname's password."
        ),
      examples: [
        dgettext("commands", "/ns register mypassword"),
        dgettext("commands", "/ns identify mypassword"),
        dgettext("commands", "/ns ghost othernick mypassword"),
        dgettext("commands", "/ns info"),
        dgettext("commands", "/ns drop mypassword")
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
          description: dgettext("commands", "Subcommand: register, identify, ghost, info, drop")
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
        dgettext("commands", "/ns drop mypassword")
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
        %{name: "help", description: dgettext("commands", "Show NickServ help")}
      ]
    }
  end
end
