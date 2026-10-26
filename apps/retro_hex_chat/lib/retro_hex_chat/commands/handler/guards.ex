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
  alias RetroHexChat.Commands.Handler.Args
  alias RetroHexChat.Games.Catalog

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
  Requires channel ownership.
  """
  @spec require_owner(Handler.context(), String.t(), String.t() | nil) ::
          :ok | {:error, String.t()}
  def require_owner(context, channel, message \\ nil) do
    if channel in Map.get(context, :owner_in, []) do
      :ok
    else
      {:error,
       message || dgettext("commands", "You must be the channel owner to use this command")}
    end
  end

  @doc """
  Requires a nickname identified with NickServ.
  """
  @spec require_identified(Handler.context(), String.t() | nil) :: :ok | {:error, String.t()}
  def require_identified(context, message \\ nil)
  def require_identified(%{identified: true}, _message), do: :ok

  def require_identified(_context, message) do
    {:error,
     message ||
       dgettext("commands", "You must be identified with NickServ to use this command")}
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

  @doc """
  Resolves the game a command run in a game's channel is about: the channel's
  own game, or the mode `args` names — `blitz` in `#hex-hockey` is Hex Hockey:
  Blitz. Refuses anywhere but a game's channel.
  """
  @spec require_game_channel(Handler.context(), [String.t()]) ::
          {:ok, %{channel: String.t(), game_id: String.t()}} | {:error, String.t()}
  def require_game_channel(context, args) do
    with {:ok, channel} <- require_channel(context),
         {:ok, base_id} <- game_of(channel),
         {:ok, game_id} <- mode_of(base_id, args) do
      {:ok, %{channel: channel, game_id: game_id}}
    end
  end

  @doc """
  Refuses a game played alone: there is nobody to seat or invite, and the
  refusal says how it is played instead.
  """
  @spec require_game_for_two(String.t()) :: :ok | {:error, String.t()}
  def require_game_for_two(game_id) do
    if Catalog.solo_only?(game_id) do
      {:error,
       dgettext("commands", "%{game} is a game for one player.", game: Catalog.game_name(game_id))}
    else
      :ok
    end
  end

  defp game_of(channel) do
    case Catalog.game_for_channel(channel) do
      {:ok, base_id} ->
        {:ok, base_id}

      :error ->
        {:error,
         dgettext("commands", "Use this in a game's own channel, like %{channel}.",
           channel: Catalog.channel_name("hex_pong")
         )}
    end
  end

  defp mode_of(base_id, []), do: {:ok, base_id}

  defp mode_of(base_id, [word | _rest]) do
    mode_id = base_id <> "_" <> word

    if Enum.any?(Catalog.modes_of(base_id), &(&1.id == mode_id)) do
      {:ok, mode_id}
    else
      {:error,
       dgettext("commands", "%{game} has no mode called %{mode}.",
         game: Catalog.channel_name(base_id),
         mode: word
       )}
    end
  end

  @doc """
  The shape of a command aimed at one person in the active channel: no
  nickname answers `usage`; otherwise the active channel must exist and
  `check` (one of the `require_*` guards) must pass before `run` gets the
  channel and the nickname — and, when it takes three arguments, the rest of
  the line as a reason (`nil` when there is none).

      def execute(args, context),
        do: on_channel_target(args, context, dgettext("commands", "Usage: /op <nickname>"),
              &require_operator/2, &{:ok, :ui_action, :set_mode, %{channel: &1, mode_string: "+o", params: [&2]}})
  """
  @spec on_channel_target(
          [String.t()],
          Handler.context(),
          String.t(),
          (Handler.context(), String.t() -> :ok | {:error, String.t()}),
          (String.t(), String.t() -> Handler.result())
          | (String.t(), String.t(), String.t() | nil -> Handler.result())
        ) :: Handler.result()
  def on_channel_target([], _context, usage, _check, _run), do: {:error, usage}

  def on_channel_target([nick | rest], context, _usage, check, run) do
    with {:ok, channel} <- require_channel(context),
         :ok <- check.(context, channel) do
      if is_function(run, 3), do: run.(channel, nick, reason(rest)), else: run.(channel, nick)
    end
  end

  # What follows the nickname, as one reason; none when nothing does.
  defp reason([]), do: nil
  defp reason(words), do: Enum.join(words, " ")

  @doc """
  The shape of a command aimed at one message of the active channel by its
  id: no id answers `usage`; otherwise the active channel must exist and the
  id must be a positive integer before `run` gets the channel and the id.
  """
  @spec on_channel_message(
          [String.t()],
          Handler.context(),
          String.t(),
          (String.t(), pos_integer() -> Handler.result())
        ) :: Handler.result()
  def on_channel_message([], _context, usage, _run), do: {:error, usage}

  def on_channel_message([raw_id | _], context, _usage, run) do
    with {:ok, channel} <- require_channel(context),
         {:ok, id} <-
           Args.positive_id(
             raw_id,
             dgettext("commands", "That is not a message id")
           ) do
      run.(channel, id)
    end
  end
end
