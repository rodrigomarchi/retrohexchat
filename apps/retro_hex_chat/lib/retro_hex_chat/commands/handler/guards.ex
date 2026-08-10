defmodule RetroHexChat.Commands.Handler.Guards do
  @moduledoc """
  Channel precondition checks shared by the "/" command handlers.

  Each guard reads a `RetroHexChat.Commands.Handler.context/0` and returns either
  the value the command needs or a translated error, shaped to chain inside the
  `with` of an `execute/2` clause.

  The privilege guards take an optional message so a command can explain the
  refusal in its own terms; omitting it falls back to the generic wording.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler

  @doc """
  Resolves the channel the command applies to, refusing when there is none.
  """
  @spec require_channel(Handler.context()) :: {:ok, String.t()} | {:error, String.t()}
  def require_channel(%{active_channel: nil}),
    do: {:error, dgettext("commands", "You are not in any channel")}

  def require_channel(%{active_channel: channel}), do: {:ok, channel}

  @doc """
  Requires channel operator status.
  """
  @spec require_operator(Handler.context(), String.t(), String.t() | nil) ::
          :ok | {:error, String.t()}
  def require_operator(context, channel, message \\ nil) do
    if channel in context.operator_in do
      :ok
    else
      {:error,
       message || dgettext("commands", "You must be a channel operator to use this command")}
    end
  end

  @doc """
  Requires half-operator status or above.
  """
  @spec require_half_op_or_above(Handler.context(), String.t(), String.t() | nil) ::
          :ok | {:error, String.t()}
  def require_half_op_or_above(context, channel, message \\ nil) do
    is_op = channel in context.operator_in
    is_half_op = channel in Map.get(context, :half_operator_in, [])

    if is_op or is_half_op do
      :ok
    else
      {:error,
       message ||
         dgettext("commands", "You must be at least a half-operator to use this command")}
    end
  end
end
