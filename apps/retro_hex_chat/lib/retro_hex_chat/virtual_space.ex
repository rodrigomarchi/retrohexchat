defmodule RetroHexChat.VirtualSpace do
  @moduledoc """
  Public API for the virtual space bounded context.

  A virtual space is a multiplayer tile map attached directly to a text
  channel. All external callers use this module; internals live in
  `RetroHexChat.VirtualSpace.*`.
  """

  alias RetroHexChat.Observability
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChat.VirtualSpace.Supervisor

  @spec join_channel_space(String.t(), %{user_id: integer() | nil, nickname: String.t()}) ::
          {:ok, %{participant: ChannelSpaceServer.participant(), snapshot: map(), map: map()}}
          | {:error, atom()}
  def join_channel_space(channel_name, actor) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :join],
      %{"chat.channel" => channel_name, space_kind: "channel"},
      fn ->
        with :ok <- ensure_channel_space_process(channel_name) do
          ChannelSpaceServer.join(channel_name, %{
            user_id: actor.user_id,
            nickname: actor.nickname
          })
        end
      end
    )
  end

  @spec join_direct_message_space(String.t(), %{user_id: integer() | nil, nickname: String.t()}, [
          String.t()
        ]) ::
          {:ok, %{participant: ChannelSpaceServer.participant(), snapshot: map(), map: map()}}
          | {:error, atom()}
  def join_direct_message_space(space_id, actor, participants) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :join],
      %{space_kind: "direct_message"},
      fn ->
        with :ok <- ensure_direct_message_space_process(space_id, participants) do
          ChannelSpaceServer.join_direct_message(space_id, %{
            user_id: actor.user_id,
            nickname: actor.nickname
          })
        end
      end
    )
  end

  @spec input(String.t(), String.t(), ChannelSpaceServer.input_payload()) ::
          :ok | {:error, ChannelSpaceServer.input_error()}
  def input(channel_name, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :input],
      %{"chat.channel" => channel_name, space_kind: "channel"},
      fn -> ChannelSpaceServer.input(channel_name, participant_key, payload) end
    )
  end

  @spec input_direct_message(String.t(), String.t(), ChannelSpaceServer.input_payload()) ::
          :ok | {:error, ChannelSpaceServer.input_error()}
  def input_direct_message(space_id, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :input],
      %{space_kind: "direct_message"},
      fn -> ChannelSpaceServer.input_direct_message(space_id, participant_key, payload) end
    )
  end

  @spec interact(String.t(), String.t(), ChannelSpaceServer.interact_payload()) ::
          :ok | {:ok, %{modal: map()}} | {:error, atom()}
  def interact(channel_name, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :interact],
      %{"chat.channel" => channel_name, space_kind: "channel"},
      fn -> ChannelSpaceServer.interact(channel_name, participant_key, payload) end
    )
  end

  @spec interact_direct_message(String.t(), String.t(), ChannelSpaceServer.interact_payload()) ::
          :ok | {:ok, %{modal: map()}} | {:error, atom()}
  def interact_direct_message(space_id, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :interact],
      %{space_kind: "direct_message"},
      fn -> ChannelSpaceServer.interact_direct_message(space_id, participant_key, payload) end
    )
  end

  @spec action(String.t(), String.t(), ChannelSpaceServer.action_payload()) ::
          :ok | {:error, atom()}
  def action(channel_name, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :action],
      %{"chat.channel" => channel_name, space_kind: "channel"},
      fn -> ChannelSpaceServer.action(channel_name, participant_key, payload) end
    )
  end

  @spec action_direct_message(String.t(), String.t(), ChannelSpaceServer.action_payload()) ::
          :ok | {:error, atom()}
  def action_direct_message(space_id, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :action],
      %{space_kind: "direct_message"},
      fn -> ChannelSpaceServer.action_direct_message(space_id, participant_key, payload) end
    )
  end

  @spec avatars() :: [String.t()]
  defdelegate avatars(), to: ChannelSpaceServer

  @spec step_ms() :: non_neg_integer()
  defdelegate step_ms(), to: ChannelSpaceServer

  @spec select_avatar(String.t(), String.t(), String.t()) :: :ok | {:error, atom()}
  def select_avatar(channel_name, participant_key, avatar) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :avatar, :select],
      %{"chat.channel" => channel_name, space_kind: "channel", avatar: avatar},
      fn -> ChannelSpaceServer.select_avatar(channel_name, participant_key, avatar) end
    )
  end

  @spec select_avatar_direct_message(String.t(), String.t(), String.t()) ::
          :ok | {:error, atom()}
  def select_avatar_direct_message(space_id, participant_key, avatar) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :avatar, :select],
      %{space_kind: "direct_message", avatar: avatar},
      fn -> ChannelSpaceServer.select_avatar_direct_message(space_id, participant_key, avatar) end
    )
  end

  @spec leave_channel_space_viewer(String.t()) :: :ok
  defdelegate leave_channel_space_viewer(channel_name),
    to: ChannelSpaceServer,
    as: :leave_channel_viewer

  @spec leave_direct_message_space_viewer(String.t(), String.t()) :: :ok
  defdelegate leave_direct_message_space_viewer(space_id, participant_key),
    to: ChannelSpaceServer,
    as: :leave_direct_message_viewer

  @spec channel_space_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate channel_space_info(channel_name), to: ChannelSpaceServer, as: :get_state

  @spec direct_message_space_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate direct_message_space_info(space_id),
    to: ChannelSpaceServer,
    as: :get_direct_message_state

  @spec snapshot(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate snapshot(channel_name), to: ChannelSpaceServer

  @spec direct_message_snapshot(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate direct_message_snapshot(space_id), to: ChannelSpaceServer

  @spec get_map(String.t()) :: {:ok, map()} | {:error, :unknown_map}
  defdelegate get_map(map_id), to: SpaceMap, as: :get

  @spec map_ids() :: [String.t()]
  defdelegate map_ids(), to: SpaceMap, as: :ids

  @spec direct_message_space_id(String.t(), String.t()) :: String.t()
  defdelegate direct_message_space_id(nick_a, nick_b), to: DirectMessageSpace, as: :space_id

  defp ensure_channel_space_process(channel_name) do
    case RetroHexChat.VirtualSpace.Registry.lookup({:channel_space, channel_name}) do
      {:ok, _pid} ->
        :ok

      {:error, :not_found} ->
        case Supervisor.start_channel_child(channel_name) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp ensure_direct_message_space_process(space_id, participants) do
    case validate_direct_message_space(space_id, participants) do
      {:ok, participants} -> ensure_direct_message_child(space_id, participants)
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_direct_message_space(space_id, participants) do
    with {:ok, [nick_a, nick_b] = participants} <-
           DirectMessageSpace.normalize_participants(participants),
         ^space_id <- DirectMessageSpace.space_id(nick_a, nick_b) do
      {:ok, participants}
    else
      _ -> {:error, :invalid_participants}
    end
  end

  defp ensure_direct_message_child(space_id, participants) do
    case RetroHexChat.VirtualSpace.Registry.lookup({:direct_message_space, space_id}) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> start_direct_message_child(space_id, participants)
    end
  end

  defp start_direct_message_child(space_id, participants) do
    case Supervisor.start_direct_message_child(space_id, participants) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
