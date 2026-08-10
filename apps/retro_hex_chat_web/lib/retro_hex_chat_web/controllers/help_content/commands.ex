defmodule RetroHexChatWeb.HelpContent.CommandsAtoM do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams, warn: false
  import RetroHexChatWeb.HelpContent.Helpers

  embed_templates "{commands_overview*,cmd_alias*,cmd_announce*,cmd_autojoin*,cmd_autorespond*,cmd_away*,cmd_ban*,cmd_bio*,cmd_clear*,cmd_cs*,cmd_deop*,cmd_devoice*,cmd_help*,cmd_ignore*,cmd_invite*,cmd_join*,cmd_kick*,cmd_knock*,cmd_list*,cmd_me*,cmd_mode*,cmd_motd*,cmd_msg*,cmd_mute*}"
end
