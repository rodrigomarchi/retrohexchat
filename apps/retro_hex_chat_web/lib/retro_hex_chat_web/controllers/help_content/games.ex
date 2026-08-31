defmodule RetroHexChatWeb.HelpContent.Games do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams, warn: false
  import RetroHexChatWeb.HelpContent.Helpers

  embed_templates "{feature_retro_games*,feature_game_match*,feature_hex_*,feature_block_breakers*,feature_debris_field*,feature_gravity_well*,feature_light_trails*,feature_pixel_tanks*,feature_star_duel*}"
end
