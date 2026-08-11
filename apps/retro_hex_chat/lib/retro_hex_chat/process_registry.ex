defmodule RetroHexChat.ProcessRegistry do
  @moduledoc """
  Finding the process that stands for a name.

  Channels, bots, lobby and arcade sessions and virtual spaces are each a
  process addressed by something the rest of the system already has — a channel
  name, a nickname, a session token, a space key. Every one of them registers
  under that value and is reached back through it, and each keeps a small module
  naming its own registry.

  What those modules share is the answer they give: a lookup either finds the
  process or reports `{:error, :not_found}`, never an empty list and never a
  raise. Callers branch on that pair everywhere — a session server that cannot
  be reached is a session that ended, and that is an ordinary outcome rather
  than a fault.
  """

  @typedoc "Whatever a process registers itself under."
  @type key :: term()

  @typedoc "A name `GenServer.start_link/3` accepts, resolved through a registry."
  @type via :: {:via, Registry, {atom(), key()}}

  @doc "The name to start a process under so `key` reaches it afterwards."
  @spec via_tuple(atom(), key()) :: via()
  def via_tuple(registry, key), do: {:via, Registry, {registry, key}}

  @doc "The process registered under `key`, if one is still alive."
  @spec lookup(atom(), key()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(registry, key) do
    case Registry.lookup(registry, key) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end
end
