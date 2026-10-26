defmodule RetroHexChat.Jobs.BotCapability do
  @moduledoc """
  A bot job's capability configuration, or the job cancelled: a capability its
  owner switched off or never set up leaves nothing for the job to do, and
  retrying would not change that.
  """

  alias RetroHexChat.Bots.Bot

  @spec enabled_config(Bot.t(), String.t()) :: {:ok, map()} | {:cancel, String.t()}
  def enabled_config(%Bot{} = bot, key) do
    case Bot.capability_config(bot, key) do
      {:ok, config} -> {:ok, config}
      {:error, :disabled} -> {:cancel, "#{key} disabled"}
      {:error, :missing} -> {:cancel, "#{key} not configured"}
    end
  end
end
