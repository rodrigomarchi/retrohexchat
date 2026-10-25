defmodule RetroHexChatWeb.P2PLive.SetupPreferences do
  @moduledoc """
  The choices made before a P2P session starts — microphone and camera, the
  devices, relaying through TURN only — read from the setup form, normalized,
  and remembered on the trusted device for the next session.
  """

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChatWeb.MediaDevices
  alias RetroHexChatWeb.Params

  @p2p_setup_preference_namespace "p2p_setup"

  @doc "The session's setup from the form, TURN-only only when TURN is configured; remembered on the device."
  @spec from_params(Phoenix.LiveView.Socket.t(), map(), boolean()) :: map()
  def from_params(socket, params, turn_configured?) do
    preferences = normalize(params)

    media_mode =
      normalize_media_mode(params["media_mode"] || media_mode(preferences))

    turn_only = turn_configured? and Params.truthy?(params["turn_only"])

    setup_opts = %{
      media_mode: media_mode,
      media: preferences.media,
      turn_only: turn_only,
      device_preferences: preferences.device_preferences
    }

    save_p2p_setup_preferences(socket, setup_opts)
    setup_opts
  end

  defp normalize_media_mode(mode) when mode in ~w(video audio receive), do: mode

  defp normalize_media_mode(_mode), do: "video"

  defp default_p2p_setup_preferences do
    %{
      media: %{audio: true, video: true},
      device_preferences: MediaDevices.no_preference(),
      turn_only: false
    }
  end

  @doc "Choices from the form or a remembered map with every key present; anything unreadable is the default."
  @spec normalize(term()) :: map()
  def normalize(preferences) when is_map(preferences) do
    defaults = default_p2p_setup_preferences()
    media = Params.value(preferences, :media)

    audio =
      Params.boolean(
        preference_value(Params.value(preferences, :audio), Params.value(media, :audio)),
        true
      )

    video =
      Params.boolean(
        preference_value(Params.value(preferences, :video), Params.value(media, :video)),
        true
      )

    %{
      media: %{audio: audio, video: video},
      device_preferences: MediaDevices.preferences(preferences),
      turn_only: Params.boolean(Params.value(preferences, :turn_only), defaults.turn_only)
    }
  end

  def normalize(_preferences), do: default_p2p_setup_preferences()

  @doc "The media mode the choices amount to: video, audio, or receive only."
  @spec media_mode(map()) :: String.t()
  def media_mode(%{media: %{audio: true, video: true}}), do: "video"

  def media_mode(%{media: %{audio: true, video: false}}), do: "audio"

  def media_mode(_preferences), do: "receive"

  @doc "The choices remembered on this trusted device, or the default."
  @spec load(Phoenix.LiveView.Socket.t()) :: map()
  def load(%{assigns: %{nickname: nickname}} = socket)
      when is_binary(nickname) do
    socket.assigns[:trusted_device_id]
    |> TrustedDevices.get_device_preference(nickname, @p2p_setup_preference_namespace)
    |> normalize()
  end

  def load(_socket), do: default_p2p_setup_preferences()

  defp save_p2p_setup_preferences(%{assigns: %{nickname: nickname}} = socket, preferences)
       when is_binary(nickname) do
    _ =
      TrustedDevices.put_device_preference(
        socket.assigns[:trusted_device_id],
        nickname,
        @p2p_setup_preference_namespace,
        persistable_p2p_setup_preferences(preferences)
      )

    :ok
  end

  defp save_p2p_setup_preferences(_socket, _preferences), do: :ok

  defp persistable_p2p_setup_preferences(preferences) do
    preferences = normalize(preferences)

    %{
      "media" => %{
        "audio" => preferences.media.audio,
        "video" => preferences.media.video
      },
      "turn_only" => preferences.turn_only == true,
      "device_preferences" => %{
        "audio_input_id" => preferences.device_preferences.audio_input_id,
        "video_input_id" => preferences.device_preferences.video_input_id,
        "audio_output_id" => preferences.device_preferences.audio_output_id
      }
    }
  end

  defp preference_value(nil, fallback), do: fallback

  defp preference_value(value, _fallback), do: value
end
