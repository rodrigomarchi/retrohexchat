defmodule RetroHexChat.Bots.Loader do
  @moduledoc """
  Boot-time task that loads all enabled bots from the database
  and starts their GenServer processes.
  """
  use Task, restart: :temporary

  require Logger

  alias RetroHexChat.Bots.{Lifecycle, Queries}

  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(_opts) do
    Task.start_link(__MODULE__, :run, [])
  end

  @spec run() :: :ok
  def run do
    bots = Queries.list_enabled_bots()
    Logger.info("BotLoader: loading #{length(bots)} enabled bots")

    Enum.each(bots, fn bot ->
      case Lifecycle.ensure_started(bot) do
        {:ok, _pid} ->
          Logger.debug("BotLoader: started bot #{bot.nickname}")

        {:error, reason} ->
          Logger.error("BotLoader: failed to start bot #{bot.nickname}: #{inspect(reason)}")
      end
    end)

    :ok
  end
end
