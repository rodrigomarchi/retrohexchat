defmodule RetroHexChat.Commands.Handlers.Mode do
  @moduledoc "Handler for /mode <+/-flags> [params]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, "Usage: /mode <+/-flags> [params]"}
  end

  def execute([mode_string | params], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_mode_privilege(context, channel, mode_string) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: mode_string, params: params}}
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
      name: "mode",
      syntax: "/mode <+/-flags> [params]",
      description: "Set or unset channel modes. Requires operator privilege.",
      examples: ["/mode +m", "/mode +k secret", "/mode -t", "/mode +o nickname"]
    }
  end

  defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
  defp require_channel(%{active_channel: channel}), do: {:ok, channel}

  defp require_mode_privilege(context, channel, mode_string) do
    is_operator = channel in context.operator_in
    is_half_op = channel in Map.get(context, :half_operator_in, [])

    cond do
      is_operator ->
        :ok

      is_half_op ->
        # Half-ops can only set +v/-v
        flags = extract_flags(mode_string)

        if Enum.all?(flags, &(&1 == "v")) do
          :ok
        else
          {:error, "Insufficient privileges to set channel modes"}
        end

      true ->
        {:error, "You must be a channel operator to change modes"}
    end
  end

  defp extract_flags(mode_string) do
    case String.split(mode_string, "", trim: true) do
      ["+" | flags] -> flags
      ["-" | flags] -> flags
      _ -> []
    end
  end

  @impl true
  def category, do: :channel

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.{Parameter, SubOption}

    %CommandSyntax{
      command: "mode",
      syntax: "/mode <+/-modos> [nick]",
      description: "Set or unset channel modes. Requires operator privilege.",
      category: :channel,
      parameters: [
        %Parameter{
          name: "+/-modos",
          required: true,
          type: :mode_flags,
          position: 0,
          description: "Mode flags to set or unset"
        },
        %Parameter{
          name: "nick",
          required: false,
          type: :nick,
          position: 1,
          description: "Target nickname (for +o, +v, +b)"
        }
      ],
      examples: ["/mode +m", "/mode +k secret", "/mode -t", "/mode +o nickname"],
      sub_options: [
        %SubOption{
          flag: "+o",
          label: "Operador",
          description: "Dar status de operador",
          requires_param: true
        },
        %SubOption{
          flag: "+v",
          label: "Voz",
          description: "Dar voz ao usuário",
          requires_param: true
        },
        %SubOption{
          flag: "+b",
          label: "Ban",
          description: "Banir usuário do canal",
          requires_param: true
        },
        %SubOption{
          flag: "+i",
          label: "Somente convite",
          description: "Canal acessível apenas por convite",
          requires_param: false
        },
        %SubOption{
          flag: "+m",
          label: "Moderado",
          description: "Somente +v e +o podem falar",
          requires_param: false
        },
        %SubOption{
          flag: "+t",
          label: "Tópico protegido",
          description: "Somente operadores alteram o tópico",
          requires_param: false
        },
        %SubOption{
          flag: "+k",
          label: "Senha",
          description: "Definir senha do canal",
          requires_param: true
        }
      ]
    }
  end
end
