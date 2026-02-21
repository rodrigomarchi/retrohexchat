defmodule RetroHexChat.Commands.Handlers.Ns do
  @moduledoc "Handler for /ns (NickServ commands)"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.NickServ

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, "Usage: /ns <register|identify|ghost|info|drop|help> [args]"}
  end

  def execute(["register" | args], context) do
    password = Enum.join(args, " ")

    if password == "" do
      {:error, "Usage: /ns register <password>"}
    else
      call_register(context.nickname, password)
    end
  end

  def execute(["identify" | args], context) do
    password = Enum.join(args, " ")

    if password == "" do
      {:error, "Usage: /ns identify <password>"}
    else
      call_identify(context.nickname, password)
    end
  end

  def execute(["ghost" | args], context) do
    case args do
      [target | _] -> call_ghost(target, context.nickname)
      [] -> {:error, "Usage: /ns ghost <nickname>"}
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
      {:error, "Usage: /ns drop <password>"}
    else
      call_drop(context.nickname, password)
    end
  end

  def execute(["help" | _], _context) do
    {:ok, :ui_action, :show_help,
     %{commands: ["ns register", "ns identify", "ns ghost", "ns info", "ns drop"]}}
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
      syntax: "/ns <subcommand> [args]",
      description:
        "Register and protect your nickname with a password through NickServ.\nSubcommands: register <password>, identify <password>, ghost <nick>, info [nick], drop <password>, help.\nRegister: claims current nickname. Identify: authenticates each session.\nGhost: disconnects a stale session using your registered nickname.",
      examples: [
        "/ns register mypassword",
        "/ns identify mypassword",
        "/ns ghost othernick",
        "/ns info",
        "/ns drop mypassword"
      ]
    }
  end

  # -- Private helpers --

  defp call_register(nickname, password) do
    case NickServ.register(nickname, password) do
      {:ok, msg} -> {:ok, :system, %{content: "[NickServ] #{msg}"}}
      {:error, msg} -> {:error, "[NickServ] #{msg}"}
    end
  end

  defp call_identify(nickname, password) do
    case NickServ.identify(nickname, password) do
      {:ok, msg} -> {:ok, :system, %{content: "[NickServ] #{msg}"}}
      {:error, msg} -> {:error, "[NickServ] #{msg}"}
    end
  end

  defp call_ghost(target, requester) do
    case NickServ.ghost(target, requester) do
      {:ok, msg} -> {:ok, :system, %{content: "[NickServ] #{msg}"}}
      {:error, msg} -> {:error, "[NickServ] #{msg}"}
    end
  end

  defp call_info(nickname) do
    case NickServ.info(nickname) do
      {:ok, info} ->
        text =
          "[NickServ] #{nickname}: registered #{info.registered_at}, identified: #{info.identified}"

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, "[NickServ] #{msg}"}
    end
  end

  defp call_drop(nickname, password) do
    case NickServ.drop(nickname, password) do
      {:ok, msg} -> {:ok, :system, %{content: "[NickServ] #{msg}"}}
      {:error, msg} -> {:error, "[NickServ] #{msg}"}
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
      syntax: "/ns <subcommand> [args]",
      description:
        "Register and protect your nickname with a password through NickServ, the nickname services bot.",
      category: :advanced,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: true,
          type: :text,
          position: 0,
          description: "Subcommand: register, identify, ghost, info, drop"
        },
        %Parameter{
          name: "args",
          required: false,
          type: :text,
          position: 1,
          description: "Subcommand arguments"
        }
      ],
      examples: [
        "/ns register mypassword",
        "/ns identify mypassword",
        "/ns ghost othernick",
        "/ns info",
        "/ns drop mypassword"
      ],
      subcommands: [
        %{name: "register", description: "Register your nickname with a password"},
        %{name: "identify", description: "Authenticate with your registered password"},
        %{name: "ghost", description: "Disconnect a stale session using your nickname"},
        %{name: "info", description: "View registration info for a nickname"},
        %{name: "drop", description: "Delete your nickname registration"},
        %{name: "help", description: "Show NickServ help"}
      ]
    }
  end
end
