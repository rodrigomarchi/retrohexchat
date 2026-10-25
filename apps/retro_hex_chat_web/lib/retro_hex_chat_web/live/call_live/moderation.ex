defmodule RetroHexChatWeb.CallLive.Moderation do
  @moduledoc """
  What a moderator does from inside a channel conference: muting, blocking a
  camera or a screen share, letting someone speak, the same for everyone at
  once, locking the call, removing someone, closing it. Each asks the domain
  (`RetroHexChat.GroupCall`), which holds the authority, and reflects the
  answer on this page.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.Channels.Policy, as: ChannelPolicy
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.Policy
  alias RetroHexChatWeb.App.GroupCallShape
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.CallLive.{CallAssign, Roster}
  alias RetroHexChatWeb.Live.GroupCallConfirmDialog
  alias RetroHexChatWeb.Live.Surface
  alias RetroHexChatWeb.Params

  @doc "Mutes or unmutes a participant's audio, whichever it is now."
  @spec moderate_audio(Socket.t(), String.t() | integer()) :: Socket.t()
  def moderate_audio(socket, participant_id) do
    moderate_participant(
      socket,
      participant_id,
      &set_target_audio(socket.assigns.group_call, &1, &2),
      dgettext("group_call", "Could not update participant media.")
    )
  end

  @doc "Blocks or unblocks a participant's camera, whichever it is now."
  @spec moderate_video(Socket.t(), String.t() | integer()) :: Socket.t()
  def moderate_video(socket, participant_id) do
    moderate_participant(
      socket,
      participant_id,
      &set_target_video(socket.assigns.group_call, &1, &2),
      dgettext("group_call", "Could not update participant camera.")
    )
  end

  @doc "Blocks or allows a participant's screen share, whichever it is now."
  @spec moderate_screen(Socket.t(), String.t() | integer()) :: Socket.t()
  def moderate_screen(socket, participant_id) do
    moderate_participant(
      socket,
      participant_id,
      &set_target_screen_share(socket.assigns.group_call, &1, &2),
      dgettext("group_call", "Could not update participant screen sharing."),
      &CallAssign.push_layout/1
    )
  end

  @doc "Lowers a participant's hand and unmutes them."
  @spec allow_speak(Socket.t(), String.t() | integer()) :: Socket.t()
  def allow_speak(socket, participant_id) do
    moderate_participant(
      socket,
      participant_id,
      fn actor, target ->
        GroupCall.allow_participant_speak(socket.assigns.group_call.token, actor, target.id)
      end,
      dgettext("group_call", "Could not allow participant to speak."),
      &CallAssign.push_layout/1
    )
  end

  # A moderator acting on one participant: find them, act as the moderator,
  # draw the participant as the server now has them. A refusal says why when
  # the server said; anything else is `failure`.
  defp moderate_participant(socket, participant_id, apply, failure, after_update \\ & &1) do
    with participant_id when is_integer(participant_id) <- Params.integer(participant_id),
         {:ok, target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         {:ok, participant} <- apply.(actor, target) do
      socket
      |> CallAssign.update(
        &Roster.put_participant(&1, GroupCallShape.normalize_participant(participant))
      )
      |> after_update.()
    else
      {:error, message} when is_binary(message) -> Surface.error(socket, message)
      _error -> Surface.error(socket, failure)
    end
  end

  @doc "Asks the moderator to confirm muting everyone or turning every camera off."
  @spec open_bulk_media_confirm(Socket.t(), :mute_all | :camera_off_all) :: Socket.t()
  def open_bulk_media_confirm(socket, action) when action in [:mute_all, :camera_off_all] do
    dialog_action =
      case action do
        :mute_all -> :open_mute_all
        :camera_off_all -> :open_camera_off_all
      end

    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: GroupCallConfirmDialog.id(),
      action: {dialog_action, socket.assigns.group_call.channel_name}
    )

    assign(socket, group_call_pending: %{action: action})
  end

  @doc "Mutes everyone or turns every camera off, after the confirmation."
  @spec moderate_all_media(Socket.t(), :mute_all | :camera_off_all) :: Socket.t()
  def moderate_all_media(socket, action) when action in [:mute_all, :camera_off_all] do
    with {:ok, actor} <- actor(socket),
         {:ok, summary} <- apply_bulk_media_action(socket.assigns.group_call, actor, action) do
      socket
      |> CallAssign.update(&put_bulk_media_participants(&1, summary))
      |> maybe_empty_bulk_media_message(summary)
      |> CallAssign.push_layout()
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(socket, dgettext("group_call", "Could not update participants."))
    end
  end

  defp apply_bulk_media_action(call, actor, :mute_all),
    do: GroupCall.mute_all_participants(call.token, actor)

  defp apply_bulk_media_action(call, actor, :camera_off_all),
    do: GroupCall.block_all_participant_videos(call.token, actor)

  defp put_bulk_media_participants(call, %{participants: participants})
       when is_list(participants) do
    Enum.reduce(participants, call, fn participant, call ->
      Roster.put_participant(call, GroupCallShape.normalize_participant(participant))
    end)
  end

  defp put_bulk_media_participants(call, _summary), do: call

  defp maybe_empty_bulk_media_message(socket, %{changed_count: count}) when count > 0, do: socket

  defp maybe_empty_bulk_media_message(socket, _summary) do
    Surface.system(
      socket,
      dgettext("group_call", "No lower-ranked conference participants were affected.")
    )
  end

  @doc "Locks the call to newcomers, or unlocks it."
  @spec toggle_lock(Socket.t()) :: Socket.t()
  def toggle_lock(socket) do
    call = socket.assigns.group_call

    with {:ok, actor} <- actor(socket),
         {:ok, result} <- apply_lock_action(call, actor) do
      socket
      |> CallAssign.update(fn call ->
        %{
          call
          | room: GroupCallShape.normalize_room(GroupCallShape.value(result, :room) || call.room)
        }
      end)
      |> CallAssign.push_layout()
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(socket, dgettext("group_call", "Could not update conference lock."))
    end
  end

  defp apply_lock_action(call, actor) do
    if Policy.locked?(call[:room]) do
      GroupCall.unlock_call(call.token, actor)
    else
      GroupCall.lock_call(call.token, actor)
    end
  end

  @doc "Asks the moderator to confirm removing a participant."
  @spec open_kick_confirm(Socket.t(), String.t() | integer()) :: Socket.t()
  def open_kick_confirm(socket, participant_id) do
    with participant_id when is_integer(participant_id) <- Params.integer(participant_id),
         {:ok, target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         :ok <- authorize_channel_ban(socket.assigns.group_call, actor, target) do
      Phoenix.LiveView.send_update(GroupCallConfirmDialog,
        id: GroupCallConfirmDialog.id(),
        action:
          {:open_kick_participant, socket.assigns.group_call.channel_name, participant_id,
           target.nickname}
      )

      assign(socket,
        group_call_pending: %{
          action: :kick_participant,
          participant_id: participant_id,
          target_nickname: target.nickname
        }
      )
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(socket, dgettext("group_call", "Could not remove participant."))
    end
  end

  @doc "Removes a participant from the call, after the confirmation."
  @spec kick_participant(Socket.t(), integer()) :: Socket.t()
  def kick_participant(socket, participant_id) do
    with participant_id when is_integer(participant_id) <- Params.integer(participant_id),
         {:ok, target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         :ok <- remove_participant_from_channel_call(socket.assigns.group_call, actor, target) do
      socket
      |> CallAssign.update(&Roster.remove_participant(&1, participant_id))
      |> Surface.system(
        dgettext(
          "group_call",
          "%{target} was removed from the conference and banned from %{channel}.",
          target: target.nickname,
          channel: socket.assigns.group_call.channel_name
        )
      )
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(socket, dgettext("group_call", "Could not remove participant."))
    end
  end

  defp remove_participant_from_channel_call(call, actor, target) do
    reason = dgettext("group_call", "Removed from channel conference")

    with :ok <- authorize_channel_ban(call, actor, target),
         :ok <- Server.ban(call.channel_name, actor.nickname, target.nickname, reason),
         :ok <- kick_group_call_participant(call, actor, target) do
      :ok
    end
  end

  defp kick_group_call_participant(call, actor, target) do
    GroupCall.force_kick_participant(call.token, actor, target.id, "channel_kick")
  end

  defp authorize_channel_ban(call, actor, target) do
    with {:ok, channel_state} <- Server.get_state(call.channel_name) do
      channel_state.members
      |> Membership.from_members()
      |> ChannelPolicy.can_ban?(actor.nickname, target.nickname)
    end
  end

  @doc "Ends the call for everyone, after the confirmation."
  @spec close_room(Socket.t()) :: Socket.t()
  def close_room(socket) do
    with {:ok, actor} <- actor(socket),
         :ok <- GroupCall.close_call(socket.assigns.group_call.token, actor, "moderation") do
      socket
      |> assign(group_call: nil, group_call_pending: nil, left_reason: "ended")
      |> Surface.close()
    else
      {:error, message} when is_binary(message) -> Surface.error(socket, message)
      _error -> Surface.error(socket, dgettext("group_call", "Could not end group call."))
    end
  end

  defp set_target_audio(call, actor, target) do
    if GroupCallShape.participant_media?(target, :audio) do
      GroupCall.mute_participant(call.token, actor, target.id)
    else
      GroupCall.unmute_participant(call.token, actor, target.id)
    end
  end

  defp set_target_video(call, actor, target) do
    if participant_media_moderated?(target, :video) do
      GroupCall.unblock_participant_video(call.token, actor, target.id)
    else
      GroupCall.block_participant_video(call.token, actor, target.id)
    end
  end

  defp set_target_screen_share(call, actor, target) do
    if participant_media_moderated?(target, :screen) do
      GroupCall.unblock_participant_screen_share(call.token, actor, target.id)
    else
      GroupCall.block_participant_screen_share(call.token, actor, target.id)
    end
  end

  defp find_participant(call, participant_id) do
    case Enum.find(call.participants, &(&1.id == participant_id)) do
      nil -> {:error, dgettext("group_call", "Participant is no longer in the group call.")}
      participant -> {:ok, participant}
    end
  end

  defp participant_media_moderated?(%{media_state: media}, :video) when is_map(media),
    do: Map.get(media, :server_video_blocked) == true

  defp participant_media_moderated?(%{media_state: media}, :screen) when is_map(media),
    do: Map.get(media, :server_screen_blocked) == true

  defp participant_media_moderated?(_participant, _key), do: false

  @doc "The reader as the domain's actor, or the reason an unregistered nick cannot moderate."
  @spec actor(Socket.t()) ::
          {:ok, %{user_id: integer(), nickname: String.t()}} | {:error, String.t()}
  def actor(socket) do
    case SessionHelpers.resolve_user_id(socket.assigns.nickname) do
      {:ok, user_id} ->
        {:ok, %{user_id: user_id, nickname: socket.assigns.nickname}}

      {:redirect, nil} ->
        {:error, dgettext("group_call", "You must be registered to moderate group calls.")}
    end
  end
end
