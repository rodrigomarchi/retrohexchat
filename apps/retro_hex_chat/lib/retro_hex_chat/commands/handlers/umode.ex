defmodule RetroHexChat.Commands.Handlers.Umode do
  @moduledoc "Handler for /umode <+/-mode> — manage user modes."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "umode",
    category: :config,
    syntax: dgettext("commands", "/umode <+/-mode>"),
    summary:
      dgettext("commands", "Toggle personal user modes that affect what messages you receive."),
    description:
      dgettext(
        "commands",
        "Toggle personal user modes that affect what messages you receive.\nAvailable modes: +w (wallops — receive operator broadcast messages), -w (stop receiving).\nMust start with + or -. Currently only the w (wallops) mode is supported."
      ),
    examples: [dgettext("commands", "/umode +w"), dgettext("commands", "/umode -w")],
    parameters: [
      %Parameter{
        name: "mode",
        required: true,
        type: :text,
        position: 0,
        description: dgettext("commands", "User mode: +w (wallops), -w")
      }
    ]

  @known_modes %{"w" => :wallops}

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /umode <+/-mode>")}
  end

  def execute([mode_string | _], _context) do
    case parse_mode(mode_string) do
      {:ok, _action, _mode} ->
        {:ok, :ui_action, :set_user_mode, %{mode_string: mode_string}}

      {:error, msg} ->
        {:error, msg}
    end
  end

  defp parse_mode("+" <> flag), do: resolve_flag(:add, flag)
  defp parse_mode("-" <> flag), do: resolve_flag(:remove, flag)
  defp parse_mode(_), do: {:error, dgettext("commands", "Usage: /umode <+/-mode>")}

  defp resolve_flag(_action, ""), do: {:error, dgettext("commands", "Usage: /umode <+/-mode>")}

  defp resolve_flag(action, flag) do
    case Map.fetch(@known_modes, flag) do
      {:ok, mode} -> {:ok, action, mode}
      :error -> {:error, dgettext("commands", "Unknown user mode: %{flag}", flag: flag)}
    end
  end
end
