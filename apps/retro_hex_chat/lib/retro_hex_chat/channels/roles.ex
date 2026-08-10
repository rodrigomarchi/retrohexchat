defmodule RetroHexChat.Channels.Roles do
  @moduledoc """
  Which of the channels someone is in do they hold a privileged role in.

  A command handler is told what its caller may do as three lists — the channels
  they own, operate, and half-operate — and every one of those answers comes
  from the same place: the live state of each channel process. Deriving them is
  a question about channels, so it is answered here rather than by whoever
  happens to be assembling a command context.

  Owning a channel implies operating it. That rule lives in this one function
  now; it used to be restated by each caller, which is the kind of thing that
  holds until one of them forgets.

  Each channel is asked once for all three roles. Asking per role meant three
  round trips to every channel process a person was in, for a list that is
  rebuilt on every command.

  A channel whose process cannot be reached contributes nothing rather than
  raising: a roster is being described, not a permission granted, and the
  handler that goes on to act still checks.
  """

  alias RetroHexChat.Channels.Server

  @typedoc "The channels held, per role, in the order the caller listed them."
  @type t :: %{
          owner: [String.t()],
          operator: [String.t()],
          half_operator: [String.t()]
        }

  @empty %{owner: [], operator: [], half_operator: []}

  @doc """
  The roles `nickname` holds across `channels`.
  """
  @spec held_by([String.t()], String.t()) :: t()
  def held_by(channels, nickname) when is_list(channels) and is_binary(nickname) do
    channels
    |> Enum.reduce(@empty, fn channel, held ->
      case Server.get_state(channel) do
        {:ok, state} -> collect(held, channel, nickname, state)
        {:error, _unreachable} -> held
      end
    end)
    |> Map.new(fn {role, held} -> {role, Enum.reverse(held)} end)
  end

  defp collect(held, channel, nickname, state) do
    owner? = nickname in Map.get(state, :owners, [])

    held
    |> put_if(owner?, :owner, channel)
    |> put_if(owner? or nickname in Map.get(state, :operators, []), :operator, channel)
    |> put_if(nickname in Map.get(state, :half_operators, []), :half_operator, channel)
  end

  defp put_if(held, false, _role, _channel), do: held
  defp put_if(held, true, role, channel), do: Map.update!(held, role, &[channel | &1])
end
