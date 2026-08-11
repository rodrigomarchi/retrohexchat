defmodule RetroHexChat.Bots.Registry do
  @moduledoc """
  Registry helpers for bot process lookup via via_tuple.
  """

  alias RetroHexChat.ProcessRegistry

  @registry RetroHexChat.Bots.BotRegistry

  @spec via_tuple(String.t()) :: ProcessRegistry.via()
  def via_tuple(bot_nickname), do: ProcessRegistry.via_tuple(@registry, bot_nickname)

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(bot_nickname), do: ProcessRegistry.lookup(@registry, bot_nickname)

  @spec registered_bots() :: [String.t()]
  def registered_bots do
    Registry.select(@registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end
