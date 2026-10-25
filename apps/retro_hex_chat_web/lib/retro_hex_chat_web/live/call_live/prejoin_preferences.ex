defmodule RetroHexChatWeb.CallLive.PrejoinPreferences do
  @moduledoc """
  The choices a person makes in the conference's antechamber — microphone and
  camera on or off, the layout, the devices — normalized, and remembered on
  their trusted device so the next antechamber opens with them.
  """

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChatWeb.App.GroupCallShape
  alias RetroHexChatWeb.CallLive.Layout
  alias RetroHexChatWeb.MediaDevices
  alias RetroHexChatWeb.Params

  @prejoin_preference_namespace "group_call_prejoin"

  @doc "The antechamber's choices before anyone made one."
  @spec default() :: map()
  def default do
    %{
      media: %{audio: true, video: true},
      layout: Layout.default_layout(),
      device_preferences: MediaDevices.no_preference()
    }
  end

  @doc "Choices from any shape (form params, a persisted map) with every key present; anything unreadable is the default."
  @spec normalize(term()) :: map()
  def normalize(nil), do: default()

  def normalize(preferences) when is_map(preferences) do
    defaults = default()

    %{
      media:
        defaults.media
        |> Map.merge(normalize_prejoin_media(preferences))
        |> Map.take([:audio, :video]),
      layout:
        defaults.layout
        |> Map.merge(normalize_prejoin_layout(preferences))
        |> Map.take([:mode, :focused_participant_id, :self_view, :mini]),
      device_preferences:
        defaults.device_preferences
        |> Map.merge(MediaDevices.preferences(preferences))
        |> Map.take([:audio_input_id, :video_input_id, :audio_output_id])
    }
  end

  def normalize(_preferences), do: default()

  defp normalize_prejoin_media(preferences) do
    media = GroupCallShape.value(preferences, :media)

    %{
      audio:
        Params.boolean(
          preference_value(
            GroupCallShape.value(preferences, :audio),
            GroupCallShape.value(media, :audio)
          ),
          true
        ),
      video:
        Params.boolean(
          preference_value(
            GroupCallShape.value(preferences, :video),
            GroupCallShape.value(media, :video)
          ),
          true
        )
    }
  end

  defp normalize_prejoin_layout(preferences) do
    layout = GroupCallShape.value(preferences, :layout)

    mode =
      preference_value(
        GroupCallShape.value(preferences, :layout_mode),
        GroupCallShape.value(layout, :mode)
      )

    self_view =
      preference_value(
        GroupCallShape.value(preferences, :self_view),
        GroupCallShape.value(layout, :self_view)
      )

    %{
      mode: Layout.layout_mode(mode),
      focused_participant_id: nil,
      self_view: Layout.self_view_mode(self_view),
      mini: false
    }
  end

  defp preference_value(nil, fallback), do: fallback

  defp preference_value(value, _fallback), do: value

  @doc "The choices remembered on this trusted device, or nil."
  @spec load(Phoenix.LiveView.Socket.t()) :: map() | nil
  def load(%{assigns: %{nickname: nickname}} = socket) do
    with persisted when is_map(persisted) <-
           TrustedDevices.get_device_preference(
             socket.assigns[:trusted_device_id],
             nickname,
             @prejoin_preference_namespace
           ) do
      normalize(persisted)
    else
      _missing -> nil
    end
  end

  def load(_socket), do: nil

  @doc "Remembers the choices on this trusted device."
  @spec save(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def save(
        %{assigns: %{nickname: nickname}} = socket,
        preferences
      ) do
    safe_preferences = persistable_prejoin_preferences(preferences)

    _ =
      TrustedDevices.put_device_preference(
        socket.assigns[:trusted_device_id],
        nickname,
        @prejoin_preference_namespace,
        safe_preferences
      )

    socket
  end

  def save(socket, _preferences), do: socket

  # The media defaults belong to the person, not to the door they leave by.
  # Closing the antechamber unmounts this LiveView, so a choice that only lives
  # in `group_call_prejoin_preferences` is gone by the time the antechamber
  # opens again; only the trusted-device record survives that.
  @doc "Remembers the open antechamber's choices before it closes."
  @spec remember(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def remember(
        %{assigns: %{group_call_prejoin: %{}, group_call_prejoin_preferences: preferences}} =
          socket
      )
      when is_map(preferences) do
    save(socket, preferences)
  end

  def remember(socket), do: socket

  defp persistable_prejoin_preferences(preferences) do
    preferences = normalize(preferences)

    %{
      "media" => %{
        "audio" => preferences.media.audio,
        "video" => preferences.media.video
      },
      "layout" => %{
        "mode" => Atom.to_string(preferences.layout.mode),
        "self_view" => Atom.to_string(preferences.layout.self_view)
      },
      "device_preferences" => %{
        "audio_input_id" => preferences.device_preferences.audio_input_id,
        "video_input_id" => preferences.device_preferences.video_input_id,
        "audio_output_id" => preferences.device_preferences.audio_output_id
      }
    }
  end
end
