defmodule RetroHexChatWeb.Components.AutocompleteDropdown do
  @moduledoc """
  Unified autocomplete dropdown for commands, nicks, and channels.
  Renders above the chat input with 98.css window styling.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :mode, :atom, default: :command, values: [:command, :nick, :channel]
  attr :results, :list, default: []
  attr :selected, :integer, default: 0

  @spec autocomplete_dropdown(map()) :: Phoenix.LiveView.Rendered.t()
  def autocomplete_dropdown(assigns) do
    ~H"""
    <div :if={@visible} class="autocomplete-dropdown" id="autocomplete-dropdown">
      <div
        class="window"
        style="position: absolute; bottom: 100%; left: 0; width: 300px; z-index: 100;"
      >
        <div class="title-bar">
          <div class="title-bar-text">{mode_title(@mode)}</div>
        </div>
        <div class="window-body">
          <ul class="tree-view" style="max-height: 250px; overflow-y: auto;">
            <li :if={@results == []} class="autocomplete-no-results">No results</li>
            {render_results(assigns)}
          </ul>
        </div>
      </div>
    </div>
    """
  end

  defp render_results(%{mode: :command} = assigns) do
    ~H"""
    <%= for {result, idx} <- Enum.with_index(@results) do %>
      <%= if is_binary(result) do %>
        <li class="autocomplete-category-header">{result}</li>
      <% else %>
        <li
          phx-click="autocomplete_select"
          phx-value-type="command"
          phx-value-value={result.name}
          class={"autocomplete-item #{if idx == @selected, do: "selected"}"}
        >
          <span>
            /<.highlight_matches text={result.name} matched_chars={result.matched_chars} />
          </span>
          <span class="autocomplete-description">{result.description}</span>
        </li>
      <% end %>
    <% end %>
    """
  end

  defp render_results(%{mode: :nick} = assigns) do
    ~H"""
    <%= for {result, idx} <- Enum.with_index(@results) do %>
      <li
        phx-click="autocomplete_select"
        phx-value-type="nick"
        phx-value-value={result.nickname}
        class={"autocomplete-item #{if idx == @selected, do: "selected"}"}
      >
        <span class={"autocomplete-status-#{result.status}"}></span>
        <span style={if result.color, do: "color: #{result.color}"}>{result.nickname}</span>
      </li>
    <% end %>
    """
  end

  defp render_results(%{mode: :channel} = assigns) do
    ~H"""
    <%= for {result, idx} <- Enum.with_index(@results) do %>
      <li
        phx-click="autocomplete_select"
        phx-value-type="channel"
        phx-value-value={result.name}
        class={"autocomplete-item #{if idx == @selected, do: "selected"}"}
      >
        <span :if={result.joined?}>✓ </span>
        <span>{result.name}</span>
        <span class="autocomplete-description">({result.user_count} users)</span>
      </li>
    <% end %>
    """
  end

  defp mode_title(:command), do: "Commands"
  defp mode_title(:nick), do: "Nicknames"
  defp mode_title(:channel), do: "Channels"

  attr :text, :string, required: true
  attr :matched_chars, :list, default: []

  defp highlight_matches(assigns) do
    ~H"""
    <%= for {char, idx} <- String.graphemes(@text) |> Enum.with_index() do %>
      <strong :if={idx in @matched_chars}>{char}</strong><span :if={idx not in @matched_chars}>{char}</span>
    <% end %>
    """
  end
end
