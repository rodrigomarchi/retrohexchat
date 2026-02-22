defmodule RetroHexChat.Bots.Loader do
  @moduledoc """
  Boot-time task that loads all enabled bots from the database
  and starts their GenServer processes.
  """
  use Task, restart: :temporary

  require Logger

  alias RetroHexChat.Bots.{Queries, Supervisor}

  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(_opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  @spec run() :: :ok
  def run do
    bots = Queries.list_enabled_bots()
    Logger.info("BotLoader: loading #{length(bots)} enabled bots")

    Enum.each(bots, fn bot ->
      bot_data = %{
        id: bot.id,
        name: bot.name,
        nickname: bot.nickname,
        command_prefix: bot.command_prefix,
        created_by: bot.created_by,
        enabled: bot.enabled,
        cooldown_ms: bot.cooldown_ms,
        capabilities: bot.capabilities,
        channel_configs: bot.channel_configs,
        custom_commands: bot.custom_commands
      }

      case Supervisor.start_bot(bot_data) do
        {:ok, _pid} ->
          Logger.info("BotLoader: started bot #{bot.nickname}")

        {:error, reason} ->
          Logger.error("BotLoader: failed to start bot #{bot.nickname}: #{inspect(reason)}")
      end
    end)

    :ok
  end
end
