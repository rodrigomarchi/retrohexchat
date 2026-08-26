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

  @doc """
  Whether a nickname belongs to a bot that is running right now.

  A bot registers under the exact nickname it was started with, so the keyed
  lookup answers almost every call. A nickname read back from a stored
  conversation or typed into a command carries whatever case the person used,
  and a private conversation with a bot is addressed that way — so a miss falls
  back to a case-insensitive pass over the registered names.
  """
  @spec bot?(String.t()) :: boolean()
  def bot?(nickname) when is_binary(nickname) do
    case lookup(nickname) do
      {:ok, _pid} ->
        true

      {:error, :not_found} ->
        target = String.downcase(nickname)
        Enum.any?(registered_bots(), &(String.downcase(&1) == target))
    end
  end

  def bot?(_nickname), do: false
end
