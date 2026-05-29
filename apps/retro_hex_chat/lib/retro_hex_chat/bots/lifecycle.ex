defmodule RetroHexChat.Bots.Lifecycle do
  @moduledoc """
  Runtime lifecycle operations for configured bots.
  """

  alias RetroHexChat.Bots.{Bot, Queries, Registry, Server, Supervisor}

  @spec destroy_bot(Bot.t()) :: {:ok, Bot.t()} | {:error, Ecto.Changeset.t()}
  def destroy_bot(%Bot{} = bot) do
    part_from_configured_channels(bot)
    Supervisor.stop_bot(bot.nickname)
    Queries.delete_bot(bot)
  end

  @spec part_from_configured_channels(Bot.t()) :: :ok
  def part_from_configured_channels(%Bot{} = bot) do
    bot.id
    |> Queries.list_channel_configs()
    |> Enum.each(&part_channel(bot, &1.channel_name))

    :ok
  end

  defp part_channel(bot, channel) do
    case Registry.lookup(bot.nickname) do
      {:ok, _pid} ->
        case safe_bot_part(bot.nickname, channel) do
          :ok -> :ok
          _ -> direct_channel_part(channel, bot.nickname)
        end

      {:error, :not_found} ->
        direct_channel_part(channel, bot.nickname)
    end
  end

  defp safe_bot_part(nickname, channel) do
    Server.part_channel(nickname, channel)
  catch
    :exit, _reason -> {:error, :exit}
  end

  defp direct_channel_part(channel, nickname) do
    case RetroHexChat.Channels.Registry.lookup(channel) do
      {:ok, _pid} ->
        RetroHexChat.Channels.Server.part(channel, nickname, "Bot destroyed")
        :ok

      {:error, :not_found} ->
        :ok
    end
  catch
    :exit, _reason -> :ok
  end
end
