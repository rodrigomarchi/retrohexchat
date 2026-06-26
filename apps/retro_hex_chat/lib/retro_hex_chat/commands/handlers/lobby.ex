defmodule RetroHexChat.Commands.Handlers.Lobby do
  @moduledoc "Handler for /lobby <nickname> — open a universal P2P lobby (all features at once)."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handlers.P2p
  alias RetroHexChat.Services.RegisteredNick

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, dgettext("commands", "Usage: /lobby <nickname>")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /lobby <nickname>")}

  def execute([target | _rest], context) do
    with :ok <- validate_identified(context),
         :ok <- validate_not_self(target, context),
         {:ok, target_id} <- resolve_registered_nick(target),
         :ok <- P2p.validate_target_online(target),
         {:ok, creator_id} <- resolve_registered_nick(context.nickname),
         {:ok, result} <- RetroHexChat.Lobby.create_session(creator_id, target_id) do
      {:ok, :ui_action, :lobby_invite,
       %{target: target, token: result.token, creator_id: creator_id}}
    end
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
      name: "lobby",
      syntax: dgettext("commands", "/lobby <nickname>"),
      description:
        dgettext(
          "commands",
          "Open a universal lobby with another user: one persistent connection that runs an audio/video call, file transfers, and games all at the same time.\nRequires: both users must be registered and identified (/ns identify)."
        ),
      examples: [dgettext("commands", "/lobby mario")]
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
      command: "lobby",
      syntax: dgettext("commands", "/lobby <nickname>"),
      description:
        dgettext(
          "commands",
          "Open a universal lobby that hosts calls, file transfers, and games together over one connection.\nRequires: both users must be registered and identified (/ns identify)."
        ),
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "Target user")
        }
      ],
      examples: [dgettext("commands", "/lobby mario")]
    }
  end

  defp validate_identified(%{identified: true}), do: :ok

  defp validate_identified(_),
    do: {:error, dgettext("commands", "You must be identified to use /lobby.")}

  defp validate_not_self(target, %{nickname: nick}) do
    if String.downcase(target) == String.downcase(nick) do
      {:error, dgettext("commands", "You cannot open a lobby with yourself.")}
    else
      :ok
    end
  end

  defp resolve_registered_nick(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil ->
        {:error,
         dgettext("commands", "User '%{nickname}' is not registered.", nickname: nickname)}

      nick ->
        {:ok, nick.id}
    end
  end
end
