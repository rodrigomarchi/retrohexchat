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

  @doc """
  Defines `via_tuple/1`, `lookup/1` and `registry_name/0` over `:registry`;
  `:key` is the type of what the processes register under.

      use RetroHexChat.ProcessRegistry, registry: RetroHexChat.Lobby.SessionRegistry, key: String.t()
  """
  defmacro __using__(opts) do
    registry = Keyword.fetch!(opts, :registry)
    key = Keyword.get(opts, :key, quote(do: RetroHexChat.ProcessRegistry.key()))

    quote do
      @registry unquote(registry)

      @spec via_tuple(unquote(key)) :: RetroHexChat.ProcessRegistry.via()
      def via_tuple(key), do: RetroHexChat.ProcessRegistry.via_tuple(@registry, key)

      @spec lookup(unquote(key)) :: {:ok, pid()} | {:error, :not_found}
      def lookup(key), do: RetroHexChat.ProcessRegistry.lookup(@registry, key)

      @spec registry_name() :: atom()
      def registry_name, do: @registry
    end
  end

  @typedoc "Whatever a process registers itself under."
  @type key :: term()

  @typedoc "A name `GenServer.start_link/3` accepts, resolved through a registry."
  @type via :: {:via, Registry, {atom(), key()}}

  @doc "The name to start a process under so `key` reaches it afterwards."
  @spec via_tuple(atom(), key()) :: via()
  def via_tuple(registry, key), do: {:via, Registry, {registry, key}}

  @doc """
  The process registered under `key`, if one is still alive.

  A registry forgets a process only when it handles the exit, a moment after
  the process is gone: a lookup straight after stopping one would otherwise
  hand back the pid that just died, and a restart would mistake it for the
  new process.
  """
  @spec lookup(atom(), key()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(registry, key) do
    case Registry.lookup(registry, key) do
      [{pid, _value}] -> if Process.alive?(pid), do: {:ok, pid}, else: {:error, :not_found}
      [] -> {:error, :not_found}
    end
  end
end
