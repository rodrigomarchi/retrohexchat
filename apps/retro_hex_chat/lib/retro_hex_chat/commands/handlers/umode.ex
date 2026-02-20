defmodule RetroHexChat.Commands.Handlers.Umode do
  @moduledoc "Handler for /umode <+/-mode> — manage user modes."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @known_modes %{"w" => :wallops}

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, "Usage: /umode <+/-mode>"}
  end

  def execute([mode_string | _], _context) do
    case parse_mode(mode_string) do
      {:ok, _action, _mode} ->
        {:ok, :ui_action, :set_user_mode, %{mode_string: mode_string}}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "umode",
      syntax: "/umode <+/-mode>",
      description:
        "Toggle personal user modes that affect what messages you receive.\nAvailable modes: +w (wallops — receive operator broadcast messages), -w (stop receiving).\nMust start with + or -. Currently only the w (wallops) mode is supported.",
      examples: ["/umode +w", "/umode -w"]
    }
  end

  defp parse_mode("+" <> flag), do: resolve_flag(:add, flag)
  defp parse_mode("-" <> flag), do: resolve_flag(:remove, flag)
  defp parse_mode(_), do: {:error, "Usage: /umode <+/-mode>"}

  defp resolve_flag(_action, ""), do: {:error, "Usage: /umode <+/-mode>"}

  defp resolve_flag(action, flag) do
    case Map.fetch(@known_modes, flag) do
      {:ok, mode} -> {:ok, action, mode}
      :error -> {:error, "Unknown user mode: #{flag}"}
    end
  end

  @impl true
  def category, do: :config

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "umode",
      syntax: "/umode <+/-mode>",
      description: "Toggle personal user modes that affect what messages you receive.",
      category: :config,
      parameters: [
        %Parameter{
          name: "mode",
          required: true,
          type: :text,
          position: 0,
          description: "User mode: +w (wallops), -w"
        }
      ],
      examples: ["/umode +w", "/umode -w"]
    }
  end
end
