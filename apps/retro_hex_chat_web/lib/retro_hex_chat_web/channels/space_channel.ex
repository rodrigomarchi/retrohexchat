defmodule RetroHexChatWeb.SpaceChannel do
  @moduledoc """
  Realtime channel for conversation-backed virtual spaces (`space:#channel` or
  `space:dm:<key>`).

  Join is authorized by the signed `channel_join_token` issued by the LiveView
  shell. Channel spaces validate channel presence before joining. The reply is
  the `space_init` payload (participant + snapshot). Domain broadcasts on the
  `space:#channel` PubSub topic are pushed through to the client verbatim.
  """
  use Phoenix.Channel, log_join: :debug

  require Logger

  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.ChannelJoinToken
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChatWeb.SpaceAssets

  @impl true
  def join("space:#" <> channel_tail, params, socket) do
    channel_name = "#" <> channel_tail

    with {:ok, data} <- verify_channel_join_token(params, channel_name),
         {:ok, result} <-
           VirtualSpace.join_channel_space(channel_name, build_channel_actor(data, params)) do
      socket =
        socket
        |> assign(:space_kind, :channel)
        |> assign(:space_id, channel_name)
        |> assign(:participant_key, result.participant.key)
        |> assign(:user_id, data.user_id)
        |> assign(:nickname, data.nickname)

      {:ok, space_init(channel_name, result), socket}
    else
      {:error, reason} ->
        {:error, %{reason: join_error(reason)}}
    end
  end

  def join("space:dm:" <> key_tail, params, socket) do
    space_id = "dm:" <> key_tail

    with {:ok, data} <- verify_direct_message_join_token(params, space_id),
         {:ok, result} <-
           VirtualSpace.join_direct_message_space(
             space_id,
             build_channel_actor(data, params),
             data.participants
           ) do
      socket =
        socket
        |> assign(:space_kind, :direct_message)
        |> assign(:space_id, space_id)
        |> assign(:participant_key, result.participant.key)
        |> assign(:user_id, data.user_id)
        |> assign(:nickname, data.nickname)

      {:ok, space_init(space_id, result), socket}
    else
      {:error, reason} ->
        {:error, %{reason: join_error(reason)}}
    end
  end

  def join("space:" <> _not_channel_topic, _params, _socket),
    do: {:error, %{reason: "not_found"}}

  @impl true
  def handle_in("space_input", payload, socket) do
    with %{space_kind: kind, space_id: space_id, participant_key: key} <- socket.assigns,
         {:ok, step} <- parse_input(payload) do
      dispatch_input(kind, space_id, key, step)
    end

    {:noreply, socket}
  end

  def handle_in("space_interact", payload, socket) do
    with %{space_kind: kind, space_id: space_id, participant_key: key} <- socket.assigns,
         {:ok, interact} <- parse_interact(payload),
         {:ok, %{modal: modal}} <- dispatch_interact(kind, space_id, key, interact) do
      push(socket, "space_modal", modal)
    end

    {:noreply, socket}
  end

  def handle_in("space_action", payload, socket) do
    with %{space_kind: kind, space_id: space_id, participant_key: key} <- socket.assigns,
         {:ok, action} <- parse_action(payload) do
      dispatch_action(kind, space_id, key, action)
    end

    {:noreply, socket}
  end

  def handle_in("space_select_avatar", payload, socket) do
    with %{space_kind: kind, space_id: space_id, participant_key: key} <- socket.assigns,
         {:ok, avatar} <- parse_select_avatar(payload) do
      dispatch_select_avatar(kind, space_id, key, avatar)
    end

    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: event, payload: payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{space_kind: :channel, space_id: space_id} ->
        VirtualSpace.leave_channel_space_viewer(space_id)

      %{space_kind: :direct_message, space_id: space_id, participant_key: participant_key} ->
        VirtualSpace.leave_direct_message_space_viewer(space_id, participant_key)

      _ ->
        :ok
    end

    :ok
  end

  defp verify_channel_join_token(%{"join_token" => join_token}, channel_name) do
    case ChannelJoinToken.verify(join_token) do
      {:ok, %{channel_name: ^channel_name} = data} ->
        if Map.get(data, :space_kind, "channel") == "channel" do
          {:ok, data}
        else
          {:error, :invalid_token}
        end

      {:ok, _other_channel} ->
        {:error, :invalid_token}

      {:error, _} ->
        {:error, :invalid_token}
    end
  end

  defp verify_channel_join_token(_params, _channel_name), do: {:error, :invalid_token}

  defp verify_direct_message_join_token(%{"join_token" => join_token}, space_id) do
    case ChannelJoinToken.verify(join_token) do
      {:ok, %{space_kind: "direct_message", space_id: ^space_id} = data} ->
        with {:ok, [nick_a, nick_b] = participants} <-
               DirectMessageSpace.normalize_participants(Map.get(data, :participants)),
             true <- DirectMessageSpace.member?(participants, data.nickname),
             ^space_id <- DirectMessageSpace.space_id(nick_a, nick_b) do
          {:ok, %{data | participants: participants}}
        else
          _ -> {:error, :invalid_token}
        end

      {:ok, _other_space} ->
        {:error, :invalid_token}

      {:error, _} ->
        {:error, :invalid_token}
    end
  end

  defp verify_direct_message_join_token(_params, _space_id), do: {:error, :invalid_token}

  # Only the closed step payload is accepted; anything else is dropped so the
  # channel never forwards malformed client input to the domain.
  defp parse_input(%{"seq" => seq, "dx" => dx, "dy" => dy})
       when is_integer(seq) and is_integer(dx) and is_integer(dy) do
    {:ok, %{seq: seq, dx: dx, dy: dy}}
  end

  defp parse_input(_), do: :error

  defp parse_interact(%{"kind" => kind, "target_id" => target_id})
       when kind in ["sit", "stand", "use"] and is_binary(target_id) do
    {:ok, %{kind: kind, target_id: target_id}}
  end

  defp parse_interact(%{"kind" => "stand"}), do: {:ok, %{kind: "stand", target_id: nil}}

  defp parse_interact(_), do: :error

  defp parse_action(%{"kind" => "sword", "dir" => dir})
       when dir in ["up", "down", "left", "right"] do
    {:ok, %{kind: "sword", dir: dir}}
  end

  defp parse_action(%{"kind" => "sword"}), do: {:ok, %{kind: "sword"}}

  defp parse_action(_), do: :error

  defp parse_select_avatar(%{"avatar" => avatar}) when is_binary(avatar) and avatar != "",
    do: {:ok, avatar}

  defp parse_select_avatar(_), do: :error

  # The viewer picked their class on the entry screen; naming it at join means
  # the snapshot already wears it, so the client downloads one class sheet
  # instead of the default's and then the real one.
  defp build_channel_actor(data, params) do
    %{
      user_id: data.user_id,
      nickname: data.nickname,
      avatar: parse_avatar(params)
    }
  end

  defp parse_avatar(%{"avatar" => avatar}) when is_binary(avatar) and avatar != "", do: avatar
  defp parse_avatar(_params), do: nil

  # `space_init` is the join reply (see `js/lib/space/protocol.js`): the full
  # canonical map inline, the viewer's own key, render config and the initial
  # snapshot. The map is serialized from the Elixir source of truth so the
  # client never keeps its own copy. Its tileset sources are digested on the way
  # out: the domain names the sheet, the web layer knows what URL that is.
  defp space_init(channel_name, result) do
    %{
      version: 1,
      channel_name: channel_name,
      self_key: result.participant.key,
      map: SpaceAssets.digest_map(result.map),
      config: %{
        tile_size: result.map.tile_size,
        # Isometric is the only projection and every tile/avatar is premium art
        # authored at world size, so the whole scene renders native 1:1.
        scale: 1,
        avatar_scale: 1,
        # Movement cooldown; the client paces held-key repeat steps to this.
        step_ms: VirtualSpace.step_ms(),
        text_chat: "global"
      },
      snapshot: result.snapshot
    }
  end

  defp join_error(:not_found), do: "not_found"
  defp join_error(:invalid_token), do: "invalid_token"
  defp join_error(:not_in_channel), do: "not_in_channel"
  defp join_error(:not_in_direct_message), do: "not_in_direct_message"
  defp join_error(:invalid_participants), do: "invalid_token"

  defp join_error(other) do
    Logger.debug("Space join denied: #{inspect(other)}")
    "access_denied"
  end

  defp dispatch_input(:channel, space_id, key, payload),
    do: VirtualSpace.input(space_id, key, payload)

  defp dispatch_input(:direct_message, space_id, key, payload),
    do: VirtualSpace.input_direct_message(space_id, key, payload)

  defp dispatch_interact(:channel, space_id, key, payload),
    do: VirtualSpace.interact(space_id, key, payload)

  defp dispatch_interact(:direct_message, space_id, key, payload),
    do: VirtualSpace.interact_direct_message(space_id, key, payload)

  defp dispatch_action(:channel, space_id, key, payload),
    do: VirtualSpace.action(space_id, key, payload)

  defp dispatch_action(:direct_message, space_id, key, payload),
    do: VirtualSpace.action_direct_message(space_id, key, payload)

  defp dispatch_select_avatar(:channel, space_id, key, avatar),
    do: VirtualSpace.select_avatar(space_id, key, avatar)

  defp dispatch_select_avatar(:direct_message, space_id, key, avatar),
    do: VirtualSpace.select_avatar_direct_message(space_id, key, avatar)
end
