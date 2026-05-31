defmodule RetroHexChat.Commands.Handlers.Game do
  @moduledoc "Handler for /game <nickname> — initiate a P2P game session."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handlers.P2p
  alias RetroHexChat.Services.RegisteredNick

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, gettext("Usage: /game <nickname>")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, gettext("Usage: /game <nickname>")}

  def execute([target | _rest], context) do
    with :ok <- validate_identified(context),
         :ok <- validate_not_self(target, context),
         {:ok, target_id} <- resolve_registered_nick(target),
         :ok <- P2p.validate_target_online(target),
         {:ok, creator_id} <- resolve_registered_nick(context.nickname),
         {:ok, result} <- create_session(creator_id, target_id) do
      {:ok, :ui_action, :game_invite,
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
      name: "game",
      syntax: gettext("/game <nickname>"),
      description:
        gettext(
          "Start a peer-to-peer game session with another user.\nRequires: both you and the target must be registered and identified (/ns identify).\nYou pick a game in the lobby after both players join."
        ),
      examples: [gettext("/game mario")]
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
      command: "game",
      syntax: gettext("/game <nickname>"),
      description:
        gettext(
          "Start a peer-to-peer game session with another user.\nRequires: both users must be registered and identified (/ns identify)."
        ),
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: gettext("User to play with")
        }
      ],
      examples: [gettext("/game mario")]
    }
  end

  defp validate_identified(%{identified: true}), do: :ok
  defp validate_identified(_), do: {:error, gettext("You must be identified to use /game.")}

  defp validate_not_self(target, %{nickname: nick}) do
    if String.downcase(target) == String.downcase(nick) do
      {:error, gettext("You cannot start a game session with yourself.")}
    else
      :ok
    end
  end

  defp resolve_registered_nick(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:error, gettext("User '%{nickname}' is not registered.", nickname: nickname)}
      nick -> {:ok, nick.id}
    end
  end

  defp create_session(creator_id, target_id) do
    RetroHexChat.Games.create_session(creator_id, target_id)
  end
end
