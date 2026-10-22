defmodule RetroHexChatWeb.Components.UI.GroupCall.MediaState do
  @moduledoc """
  Whether your own microphone, camera or screen share is on in a group call.

  The panel's toggles, the video surface and the pre-join preview all draw
  from it. A call that has not said yet is heard and seen (audio and video
  start on) and shares no screen until you choose to.
  """

  @spec enabled?(map() | nil, :audio | :video | :screen) :: boolean()
  def enabled?(%{media: media}, key) when is_map(media), do: enabled?(media, key)
  def enabled?(media, key) when is_map(media), do: Map.get(media, key, default(key)) == true
  def enabled?(_none, key), do: default(key)

  defp default(:screen), do: false
  defp default(_audio_or_video), do: true
end
