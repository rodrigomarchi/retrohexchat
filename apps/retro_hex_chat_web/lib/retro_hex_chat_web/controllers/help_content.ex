defmodule RetroHexChatWeb.HelpContent do
  @moduledoc """
  HEEx template components for help topic content.

  Topic IDs map to function names by replacing hyphens with underscores
  (e.g., `"cmd-join"` -> `cmd_join/1`). The actual templates are split across
  smaller modules below so compiling the help system does not build one huge
  HEEx module.
  """
end
