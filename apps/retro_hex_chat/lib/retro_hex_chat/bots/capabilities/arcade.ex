defmodule RetroHexChat.Bots.Capabilities.Arcade do
  @moduledoc """
  Arcade capability for bots — lets users start solo arcade sessions.

  Responds to `!play` or `!BotName play` in channels where the bot is active.
  Creates a solo arcade session and replies with the lobby URL.

  Requirements: user must be registered and identified via NickServ.
  """
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Services.{NickServ, RegisteredNick}

  @impl true
  @spec name() :: atom()
  def name, do: :arcade

  @impl true
  @spec description() :: String.t()
  def description, do: "Start solo arcade sessions with !play"

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, author, ctx) do
    prefix = ctx.command_prefix
    bot_name = ctx.bot_nickname

    case parse_command(content, prefix, bot_name) do
      :play -> handle_play(author)
      :ignore -> :ignore
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec default_config() :: map()
  def default_config, do: %{"enabled" => true}

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_config), do: :ok

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands do
    [%{trigger: "play", description: "Start a solo arcade session"}]
  end

  # ── Internal ──

  @spec parse_command(String.t(), String.t(), String.t()) :: :play | :ignore
  defp parse_command(content, prefix, bot_name) do
    lower = String.downcase(String.trim(content))
    bot_lower = String.downcase(bot_name)
    long_prefix = String.downcase(prefix) <> bot_lower
    short_prefix = String.downcase(prefix)

    cond do
      # Long format: !BotName play
      lower == long_prefix <> " play" or String.starts_with?(lower, long_prefix <> " play ") ->
        :play

      # Short format: !play (exact match only)
      lower == short_prefix <> "play" ->
        :play

      true ->
        :ignore
    end
  end

  @spec handle_play(String.t()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_play(author) do
    with :ok <- check_identified(author),
         {:ok, creator_id} <- resolve_registered_nick(author),
         {:ok, result} <- RetroHexChat.Arcade.create_session(creator_id) do
      {:notice, author, "/solo/#{result.token}"}
    end
  end

  @spec check_identified(String.t()) :: :ok | {:reply, String.t()}
  defp check_identified(author) do
    if NickServ.identified?(author) do
      :ok
    else
      {:reply, "#{author}: You must be identified to play. Use /ns identify <password> first."}
    end
  end

  @spec resolve_registered_nick(String.t()) :: {:ok, integer()} | {:reply, String.t()}
  defp resolve_registered_nick(author) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: author) do
      nil ->
        {:reply, "#{author}: You must be registered to play. Use /ns register <password> first."}

      nick ->
        {:ok, nick.id}
    end
  end
end
