defmodule RetroHexChatWeb.SpaceChannel do
  @moduledoc """
  Realtime channel for a channel-backed virtual space (`space:#channel`).

  Join is authorized by the signed `channel_join_token` issued by the LiveView
  shell. Channel spaces validate channel presence before joining. The reply is
  the `space_init` payload (participant + snapshot). Domain broadcasts on the
  `space:#channel` PubSub topic are pushed through to the client verbatim.
  """
  use Phoenix.Channel

  require Logger

  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.ChannelJoinToken

  @impl true
  def join("space:#" <> channel_tail, params, socket) do
    channel_name = "#" <> channel_tail

    with {:ok, data} <- verify_channel_join_token(params, channel_name),
         {:ok, result} <- VirtualSpace.join_channel_space(channel_name, build_channel_actor(data)) do
      socket =
        socket
        |> assign(:space_kind, :channel)
        |> assign(:space_channel_name, channel_name)
        |> assign(:participant_key, result.participant.key)
        |> assign(:user_id, data.user_id)
        |> assign(:nickname, data.nickname)

      {:ok, space_init(channel_name, result), socket}
    else
      {:error, reason} ->
        {:error, %{reason: join_error(reason)}}
    end
  end

  def join("space:" <> _not_channel_topic, _params, _socket),
    do: {:error, %{reason: "not_found"}}

  @impl true
  def handle_in("space_input", payload, socket) do
    with %{space_channel_name: channel_name, participant_key: key} <- socket.assigns,
         {:ok, step} <- parse_input(payload) do
      VirtualSpace.input(channel_name, key, step)
    end

    {:noreply, socket}
  end

  def handle_in("space_interact", payload, socket) do
    with %{space_channel_name: channel_name, participant_key: key} <- socket.assigns,
         {:ok, interact} <- parse_interact(payload),
         {:ok, %{modal: modal}} <- VirtualSpace.interact(channel_name, key, interact) do
      push(socket, "space_modal", modal)
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
      %{space_kind: :channel, space_channel_name: channel_name} ->
        VirtualSpace.leave_channel_space_viewer(channel_name)

      _ ->
        :ok
    end

    :ok
  end

  defp verify_channel_join_token(%{"join_token" => join_token}, channel_name) do
    case ChannelJoinToken.verify(join_token) do
      {:ok, %{channel_name: ^channel_name} = data} -> {:ok, data}
      {:ok, _other_channel} -> {:error, :invalid_token}
      {:error, _} -> {:error, :invalid_token}
    end
  end

  defp verify_channel_join_token(_params, _channel_name), do: {:error, :invalid_token}

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

  defp build_channel_actor(data) do
    %{
      user_id: data.user_id,
      nickname: data.nickname
    }
  end

  # `space_init` is the join reply (see `js/lib/space/protocol.js`): the full
  # canonical map inline, the viewer's own key, render config and the initial
  # snapshot. The map is serialized from the Elixir source of truth so the
  # client never keeps its own copy.
  defp space_init(channel_name, result) do
    %{
      version: 1,
      channel_name: channel_name,
      self_key: result.participant.key,
      map: result.map,
      config: %{
        tile_size: result.map.tile_size,
        scale: 2,
        text_chat: "global"
      },
      snapshot: result.snapshot
    }
  end

  defp join_error(:not_found), do: "not_found"
  defp join_error(:invalid_token), do: "invalid_token"
  defp join_error(:not_in_channel), do: "not_in_channel"

  defp join_error(other) do
    Logger.info("Space join denied: #{inspect(other)}")
    "access_denied"
  end
end
