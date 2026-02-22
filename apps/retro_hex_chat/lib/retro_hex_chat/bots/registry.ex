defmodule RetroHexChat.Bots.Registry do
  @moduledoc """
  Registry helpers for bot process lookup via via_tuple.
  """

  @registry RetroHexChat.Bots.BotRegistry

  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), String.t()}}
  def via_tuple(bot_nickname) do
    {:via, Registry, {@registry, bot_nickname}}
  end

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(bot_nickname) do
    case Registry.lookup(@registry, bot_nickname) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @spec registered_bots() :: [String.t()]
  def registered_bots do
    Registry.select(@registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end
