defmodule RetroHexChat.Commands.Dispatcher do
  @moduledoc """
  Routes parsed commands to their handler modules.
  """

  alias RetroHexChat.Commands.{Handler, Registry}

  @spec dispatch(String.t(), [String.t()], Handler.context()) :: Handler.result()
  def dispatch(command_name, args, context) do
    case Registry.lookup(command_name) do
      {:ok, handler} ->
        run_handler(handler, args, context)

      {:error, :unknown_command} ->
        {:error, "Unknown command: /#{command_name}. Type /help for a list of commands."}
    end
  end

  defp run_handler(handler, ["help" | _], _context) do
    {:ok, :ui_action, :show_command_help, %{help: handler.help()}}
  end

  defp run_handler(handler, args, context) do
    raw_args = Enum.join(args, " ")

    case handler.validate(raw_args) do
      :ok -> handler.execute(args, context)
      {:error, _reason} = error -> error
    end
  end
end
