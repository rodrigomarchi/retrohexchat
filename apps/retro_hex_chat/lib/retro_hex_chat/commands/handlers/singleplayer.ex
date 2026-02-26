defmodule RetroHexChat.Commands.Handlers.SinglePlayer do
  @moduledoc "Handler for /singleplayer — start a solo arcade session."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.RegisteredNick

  @impl true
  @spec validate(String.t()) :: :ok
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, context) do
    with :ok <- validate_identified(context),
         {:ok, creator_id} <- resolve_registered_nick(context.nickname),
         {:ok, result} <- RetroHexChat.Arcade.create_session(creator_id) do
      {:ok, :ui_action, :arcade_session, %{token: result.token}}
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
      name: "singleplayer",
      syntax: "/singleplayer",
      description:
        "Start a solo arcade session to play classic games like DOOM and Quake.\nRequires: you must be registered and identified (/ns identify).\nYou pick a game in the arcade lobby.",
      examples: ["/singleplayer"]
    }
  end

  @impl true
  def category, do: :user

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax

    %CommandSyntax{
      command: "singleplayer",
      syntax: "/singleplayer",
      description:
        "Start a solo arcade session to play classic games (DOOM, Quake) in your browser via WebAssembly.",
      category: :user,
      parameters: [],
      examples: ["/singleplayer"]
    }
  end

  defp validate_identified(%{identified: true}), do: :ok
  defp validate_identified(_), do: {:error, "You must be identified to use /singleplayer."}

  defp resolve_registered_nick(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:error, "You must be registered to play arcade games."}
      nick -> {:ok, nick.id}
    end
  end
end
