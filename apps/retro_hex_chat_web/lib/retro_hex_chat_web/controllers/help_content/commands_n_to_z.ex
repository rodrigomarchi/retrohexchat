defmodule RetroHexChatWeb.HelpContent.CommandsNtoZ do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams, warn: false
  import RetroHexChatWeb.HelpContent.Helpers

  embed_templates "cmd_{nick*,notice*,notify*,ns*,op*,p2p*,part*,perform*,popups*,query*,quit*,setmotd*,setwelcome*,slow*,timer*,topic*,transfer*,umode*,unban*,unignore*,unmute*,voice*,wallops*,whois*,whowas*}"
end
