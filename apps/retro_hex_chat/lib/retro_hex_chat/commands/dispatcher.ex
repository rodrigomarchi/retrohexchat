defmodule RetroHexChat.Commands.Dispatcher do
  @moduledoc """
  Routes parsed commands to their handler modules.
  """

  alias RetroHexChat.Commands.{Handler, Registry}

  @spec dispatch(String.t(), [String.t()], Handler.context()) :: Handler.result()
  def dispatch(command_name, args, context) do
    case Registry.lookup(command_name) do
      {:ok, handler} ->
        raw_args = Enum.join(args, " ")

        case handler.validate(raw_args) do
          :ok -> handler.execute(args, context)
          {:error, _reason} = error -> error
        end

      {:error, :unknown_command} ->
        {:error, "Unknown command: /#{command_name}. Type /help for a list of commands."}
    end
  end
end
