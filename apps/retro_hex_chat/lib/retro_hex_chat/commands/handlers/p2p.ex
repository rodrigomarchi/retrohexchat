defmodule RetroHexChat.Commands.Handlers.P2p do
  @moduledoc "Handler for /p2p <nickname> — initiate a P2P session."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.RegisteredNick

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /p2p <nickname>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /p2p <nickname>"}

  def execute([target | _rest], context) do
    do_execute(target, "generic", context)
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
      name: "p2p",
      syntax: "/p2p <nickname>",
      description:
        "Start a direct peer-to-peer session with another user for file transfers, audio calls, or video calls.\nRequires: both you and the target must be registered and identified (/ns identify).\nYou cannot start a session with yourself.",
      examples: ["/p2p mario"]
    }
  end

  @impl true
  def category, do: :user

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "p2p",
      syntax: "/p2p <nickname>",
      description:
        "Start a direct peer-to-peer session with another user for file transfers, audio calls, or video calls.\nRequires: both users must be registered and identified (/ns identify).",
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: "Target user"
        }
      ],
      examples: ["/p2p mario"]
    }
  end

  # Shared execution logic used by /p2p, /call, and /sendfile handlers
  @doc false
  @spec do_execute(String.t(), String.t(), Handler.context()) :: Handler.result()
  def do_execute(target, session_type, context) do
    with :ok <- validate_identified(context),
         :ok <- validate_not_self(target, context),
         {:ok, target_id} <- resolve_registered_nick(target),
         :ok <- validate_target_online(target),
         {:ok, creator_id} <- resolve_registered_nick(context.nickname),
         {:ok, result} <- create_session(creator_id, target_id, session_type) do
      {:ok, :ui_action, :p2p_invite,
       %{target: target, session_type: session_type, token: result.token, creator_id: creator_id}}
    end
  end

  defp validate_identified(%{identified: true}), do: :ok
  defp validate_identified(_), do: {:error, "You must be identified to use /p2p."}

  defp validate_not_self(target, %{nickname: nick}) do
    if String.downcase(target) == String.downcase(nick) do
      {:error, "You cannot start a P2P session with yourself."}
    else
      :ok
    end
  end

  defp resolve_registered_nick(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:error, "User '#{nickname}' is not registered."}
      nick -> {:ok, nick.id}
    end
  end

  @doc false
  @spec validate_target_online(String.t()) :: :ok | {:error, String.t()}
  def validate_target_online(target) do
    if Tracker.online?("presence:global", target) do
      :ok
    else
      {:error, "User '#{target}' is offline."}
    end
  end

  defp create_session(creator_id, target_id, session_type) do
    RetroHexChat.P2P.create_session(creator_id, target_id, session_type: session_type)
  end
end
