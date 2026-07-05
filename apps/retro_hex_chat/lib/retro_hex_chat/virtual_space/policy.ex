defmodule RetroHexChat.VirtualSpace.Policy do
  @moduledoc """
  Authorization rules for virtual space operations.

  Errors are atoms so callers (LiveView, Channel, handlers) can branch on
  them and translate at the presentation layer:

  - `:invalid_origin` — the command did not come from a channel;
  - `:registration_required` — guests cannot use virtual spaces;
  - `:not_identified` — the user has not identified with NickServ;
  - `:cannot_post` — no permission to post in the origin channel;
  - `:channel_access_denied` — the session's channel refuses the user;
  - `:terminal_session` — the session already ended;
  - `:space_full` — the space is at capacity;
  - `:forbidden` — the action requires creator or admin powers.

  Channel access reuses `RetroHexChat.Channels.Policy` against the live
  channel state when the channel process is running, falling back to the
  persisted registered-channel state otherwise.
  """

  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.Channels.Modes
  alias RetroHexChat.Channels.Policy, as: ChannelPolicy
  alias RetroHexChat.Channels.Queries, as: ChannelQueries
  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.VirtualSpace.Schema.Session

  @type actor :: %{
          required(:user_id) => integer() | nil,
          required(:nickname) => String.t(),
          required(:identified) => boolean(),
          optional(:is_admin) => boolean(),
          optional(:is_server_operator) => boolean()
        }

  @type error ::
          :invalid_origin
          | :registration_required
          | :not_identified
          | :cannot_post
          | :channel_access_denied
          | :terminal_session
          | :space_full
          | :forbidden

  @spec can_create?(actor(), String.t() | nil) :: :ok | {:error, error()}
  def can_create?(actor, channel_name) do
    with :ok <- check_channel_origin(channel_name),
         :ok <- check_registered_identified(actor) do
      check_can_post(actor, channel_name)
    end
  end

  @spec can_join?(actor(), Session.t()) :: :ok | {:error, error()}
  def can_join?(actor, session) do
    with :ok <- check_registered_identified(actor),
         :ok <- check_not_terminal(session) do
      check_channel_access(actor, session.channel_name)
    end
  end

  @spec check_capacity(Session.t(), non_neg_integer(), boolean()) :: :ok | {:error, error()}
  def check_capacity(_session, _active_count, true), do: :ok

  def check_capacity(session, active_count, false) do
    if active_count < session.max_participants do
      :ok
    else
      {:error, :space_full}
    end
  end

  @spec can_close?(actor(), Session.t()) :: :ok | {:error, error()}
  def can_close?(actor, session), do: check_creator_or_admin(actor, session)

  @spec can_admin?(actor(), Session.t()) :: :ok | {:error, error()}
  def can_admin?(actor, session), do: check_creator_or_admin(actor, session)

  defp check_channel_origin("#" <> _rest), do: :ok
  defp check_channel_origin(_), do: {:error, :invalid_origin}

  defp check_registered_identified(%{user_id: nil}), do: {:error, :registration_required}
  defp check_registered_identified(%{identified: false}), do: {:error, :not_identified}
  defp check_registered_identified(_actor), do: :ok

  defp check_not_terminal(session) do
    if Session.terminal?(session.status) do
      {:error, :terminal_session}
    else
      :ok
    end
  end

  defp check_creator_or_admin(actor, session) do
    cond do
      actor.user_id == session.creator_id -> :ok
      Map.get(actor, :is_admin, false) -> :ok
      Map.get(actor, :is_server_operator, false) -> :ok
      true -> {:error, :forbidden}
    end
  end

  defp check_can_post(actor, channel_name) do
    case ChannelServer.get_state(channel_name) do
      {:ok, state} ->
        check_moderated_post(actor, state)

      {:error, :not_found} ->
        {:error, :cannot_post}
    end
  end

  defp check_moderated_post(actor, state) do
    member? = Enum.any?(state.members, fn {nick, _role} -> nick == actor.nickname end)

    voiced_or_better? =
      Enum.any?(state.members, fn {nick, role} ->
        nick == actor.nickname and role != :regular
      end)

    cond do
      not member? -> {:error, :cannot_post}
      state.modes_detail.moderated and not voiced_or_better? -> {:error, :cannot_post}
      true -> :ok
    end
  end

  defp check_channel_access(actor, channel_name) do
    case channel_access_data(channel_name) do
      :unrestricted ->
        :ok

      {:live, state} ->
        if member_of_live_channel?(actor, state) do
          :ok
        else
          check_join_rules(actor, state.modes, state.invite_exceptions)
        end

      {:persisted, persisted} ->
        check_join_rules(actor, persisted.modes, persisted.invite_exceptions)
    end
  end

  defp channel_access_data(channel_name) do
    case ChannelServer.get_state(channel_name) do
      {:ok, state} ->
        {:live, state}

      {:error, :not_found} ->
        case ChannelQueries.load_persisted_state(channel_name) do
          nil -> :unrestricted
          persisted -> {:persisted, persisted}
        end
    end
  end

  defp member_of_live_channel?(actor, state) do
    Enum.any?(state.members, fn {nick, _role} -> nick == actor.nickname end)
  end

  defp check_join_rules(actor, mode_string, invite_exceptions) do
    modes = build_modes(mode_string)

    case ChannelPolicy.can_join?(
           modes,
           Membership.new(),
           nil,
           actor.nickname,
           MapSet.new(invite_exceptions),
           actor.identified
         ) do
      :ok -> :ok
      {:error, _reason} -> {:error, :channel_access_denied}
    end
  end

  defp build_modes(mode_string) when is_binary(mode_string) and mode_string != "" do
    normalized =
      if String.starts_with?(mode_string, "+"), do: mode_string, else: "+" <> mode_string

    case Modes.apply_changes(Modes.new(), normalized) do
      {:ok, modes} -> modes
      {:error, _} -> Modes.new()
    end
  end

  defp build_modes(_), do: Modes.new()
end
