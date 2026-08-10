defmodule RetroHexChatWeb.HelpContent.P2P do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams, warn: false
  import RetroHexChatWeb.HelpContent.Helpers

  embed_templates "{feature_audio_call*,feature_call_quality*,feature_channel_conference*,feature_connection_diagram*,feature_file_transfer*,feature_media_devices*,feature_network_stats*,feature_p2p_in_chat*,feature_privacy_settings*,feature_single_session*,feature_universal_lobby*,feature_video_call*}"
end
