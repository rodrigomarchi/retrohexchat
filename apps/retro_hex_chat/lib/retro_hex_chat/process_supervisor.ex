defmodule RetroHexChat.ProcessSupervisor do
  @moduledoc """
  A DynamicSupervisor holding one process per live thing — a channel, a room,
  a session.

      use RetroHexChat.ProcessSupervisor, child: RetroHexChat.Lobby.SessionServer

  defines `start_link/1` (the name defaults to the module, `:options` are passed
  to `DynamicSupervisor.start_link/1`), `child_spec/1`, `stop_child/2`, and —
  when `:child` is given — `start_child/2`, which starts `{child, arg}`.
  """

  defmacro __using__(opts) do
    child = Keyword.get(opts, :child)
    options = Keyword.get(opts, :options, [])

    start_child =
      if child do
        quote do
          @spec start_child(term()) :: DynamicSupervisor.on_start_child()
          @spec start_child(GenServer.server(), term()) :: DynamicSupervisor.on_start_child()
          def start_child(supervisor \\ __MODULE__, arg) do
            DynamicSupervisor.start_child(supervisor, {unquote(child), arg})
          end
        end
      end

    quote do
      @spec start_link(keyword()) :: Supervisor.on_start()
      def start_link(opts \\ []) do
        name = Keyword.get(opts, :name, __MODULE__)

        DynamicSupervisor.start_link([strategy: :one_for_one, name: name] ++ unquote(options))
      end

      @spec child_spec(keyword()) :: Supervisor.child_spec()
      def child_spec(opts) do
        %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :supervisor}
      end

      unquote(start_child)

      @spec stop_child(GenServer.server(), pid()) :: :ok | {:error, :not_found}
      def stop_child(supervisor \\ __MODULE__, pid) do
        DynamicSupervisor.terminate_child(supervisor, pid)
      end
    end
  end
end
