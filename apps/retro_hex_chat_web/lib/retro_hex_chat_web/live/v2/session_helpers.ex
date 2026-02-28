defmodule RetroHexChatWeb.V2.SessionHelpers do
  @moduledoc """
  Shared session helper functions for v2 session LiveViews.
  Extracted from duplicated private helpers across ArcadeGameLive,
  SoloSessionLive, GameSessionLive, and P2PSessionLive.
  """

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  alias RetroHexChat.Services.RegisteredNick

  @allowed_client_keys %{
    "browser" => :browser,
    "os" => :os,
    "language" => :language,
    "screen" => :screen,
    "color_depth" => :color_depth,
    "touch" => :touch,
    "cores" => :cores,
    "timezone" => :timezone
  }
  @max_string_length 100

  @spec verify_nickname(Phoenix.LiveView.Socket.t(), String.t() | nil) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:redirect, Phoenix.LiveView.Socket.t()}
  def verify_nickname(socket, nil) do
    {:redirect, Phoenix.LiveView.push_navigate(socket, to: ~p"/v2/connect")}
  end

  def verify_nickname(socket, _nickname), do: {:ok, socket}

  @spec resolve_user_id(String.t()) :: {:ok, integer()} | {:redirect, nil}
  def resolve_user_id(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:redirect, nil}
      nick -> {:ok, nick.id}
    end
  end

  @spec resolve_peer_nick(integer(), map()) :: String.t()
  def resolve_peer_nick(user_id, session) do
    peer_id = if user_id == session.creator_id, do: session.peer_id, else: session.creator_id

    case RetroHexChat.Repo.get(RegisteredNick, peer_id) do
      nil -> "unknown"
      nick -> nick.nickname
    end
  end

  @spec verify_participant(integer(), map()) :: :ok | {:redirect, nil}
  def verify_participant(user_id, session) do
    if user_id == session.creator_id or user_id == session.peer_id do
      :ok
    else
      {:redirect, nil}
    end
  end

  @spec parse_client_info(map() | nil) :: map()
  def parse_client_info(nil), do: %{}

  def parse_client_info(params) do
    case params["client_info"] do
      json when is_binary(json) -> decode_client_json(json)
      _ -> %{}
    end
  end

  @spec webrtc_state_label(String.t(), any()) :: String.t() | nil
  def webrtc_state_label("connecting", _attempt), do: "Connecting..."
  def webrtc_state_label("connected", _attempt), do: "Connected"
  def webrtc_state_label("disconnected", _attempt), do: "Reconnecting..."
  def webrtc_state_label("failed", _attempt), do: "Connection failed"
  def webrtc_state_label(_state, _attempt), do: nil

  # --- Private Helpers ---

  defp decode_client_json(json) do
    case Jason.decode(json) do
      {:ok, data} when is_map(data) ->
        Map.new(@allowed_client_keys, fn {str_key, atom_key} ->
          {atom_key, sanitize_client_value(data[str_key])}
        end)

      _ ->
        %{}
    end
  end

  defp sanitize_client_value(val) when is_binary(val),
    do: String.slice(val, 0, @max_string_length)

  defp sanitize_client_value(val) when is_integer(val), do: val
  defp sanitize_client_value(val) when is_boolean(val), do: val
  defp sanitize_client_value(_), do: nil
end
