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
      description:
        "Change channel settings and user privileges using mode flags.\nFlags: +o (operator), +v (voice), +b (ban), +h (half-op), +m (moderated), +i (invite-only), +t (topic protected), +k (key/password), +l (user limit), +n (no external messages), +j (join throttle), +K (no knock).\nRequires: channel operator. Half-operators can only set +v/-v. Must be in a channel.",
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
      syntax: "/mode <+/-flags> [params]",
      description:
        "Change channel settings and user privileges using mode flags.\nFlags: +o (operator), +v (voice), +b (ban), +h (half-op), +m (moderated), +i (invite-only), +t (topic protected), +k (key/password), +l (user limit), +n (no external messages), +j (join throttle), +K (no knock).\nRequires: channel operator. Half-operators can only set +v/-v. Must be in a channel.",
      category: :channel,
      parameters: [
        %Parameter{
          name: "+/-flags",
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
          label: "Operator",
          description: "Grant operator status",
          requires_param: true
        },
        %SubOption{
          flag: "+v",
          label: "Voice",
          description: "Grant voice to speak in +m",
          requires_param: true
        },
        %SubOption{
          flag: "+b",
          label: "Ban",
          description: "Ban user from channel",
          requires_param: true
        },
        %SubOption{
          flag: "+i",
          label: "Invite only",
          description: "Channel accessible only by invitation",
          requires_param: false
        },
        %SubOption{
          flag: "+m",
          label: "Moderated",
          description: "Only +v and +o can speak",
          requires_param: false
        },
        %SubOption{
          flag: "+t",
          label: "Topic protected",
          description: "Only operators can change the topic",
          requires_param: false
        },
        %SubOption{
          flag: "+k",
          label: "Key",
          description: "Set channel password",
          requires_param: true
        }
      ]
    }
  end
end
