defmodule RetroHexChatWeb.Components.CommandPalette do
  @moduledoc """
  Slash-command autocomplete palette, displayed above the chat input.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :commands, :list, default: []
  attr :filter, :string, default: ""

  @spec command_palette(map()) :: Phoenix.LiveView.Rendered.t()
  def command_palette(assigns) do
    ~H"""
    <div :if={@visible} class="command-palette" id="command-palette">
      <div
        class="window"
        style="position: absolute; bottom: 100%; left: 0; width: 300px; z-index: 100;"
      >
        <div class="title-bar">
          <div class="title-bar-text">Commands</div>
        </div>
        <div class="window-body">
          <ul class="tree-view" style="max-height: 200px; overflow-y: auto;">
            <li
              :for={cmd <- filtered_commands(@commands, @filter)}
              phx-click="select_command"
              phx-value-command={cmd}
              class="command-palette-item"
            >
              /{cmd}
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  defp filtered_commands(commands, ""), do: commands

  defp filtered_commands(commands, filter) do
    downcased = String.downcase(filter)
    Enum.filter(commands, &String.starts_with?(&1, downcased))
  end
end
