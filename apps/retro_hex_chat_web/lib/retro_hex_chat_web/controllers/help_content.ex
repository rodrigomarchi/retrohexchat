defmodule RetroHexChatWeb.HelpContent do
  @moduledoc """
  HEEx template components for help topic content.

  Each `.html.heex` file in `help_content/` is compiled into a function
  component via `embed_templates`. Topic IDs map to function names by
  replacing hyphens with underscores (e.g., `"cmd-join"` → `cmd_join/1`).
  """
  use Phoenix.Component

  import RetroHexChatWeb.HelpLive.HelpHelpers, only: [help_h4: 1, help_link: 1]

  embed_templates "help_content/*"
end
