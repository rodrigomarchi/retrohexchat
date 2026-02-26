defmodule RetroHexChatWeb.Components.AutocompleteDropdown do
  @moduledoc """
  Unified autocomplete dropdown for commands, nicks, and channels.
  Renders above the chat input as a minimal dropdown list.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :mode, :atom, default: :command, values: [:command, :nick, :channel, :subcommand]
  attr :results, :list, default: []
  attr :selected, :integer, default: 0
  attr :command, :string, default: nil

  @spec autocomplete_dropdown(map()) :: Phoenix.LiveView.Rendered.t()
  def autocomplete_dropdown(assigns) do
    ~H"""
    <div :if={@visible} class="autocomplete-dropdown" id="autocomplete-dropdown">
      <ul class="u-overflow-y-auto autocomplete-list">
        <li :if={@results == []} class="autocomplete-no-results">No results</li>
        {render_results(assigns)}
      </ul>
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
          <span>/{result.name}</span>
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
        <span class={result.color_class}>{result.nickname}</span>
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

  defp render_results(%{mode: :subcommand} = assigns) do
    ~H"""
    <%= for {result, idx} <- Enum.with_index(@results) do %>
      <li
        phx-click="autocomplete_select"
        phx-value-type="subcommand"
        phx-value-value={result.name}
        phx-value-command={@command}
        class={"autocomplete-item #{if idx == @selected, do: "selected"}"}
      >
        <span>{result.name}</span>
        <span class="autocomplete-description">{result.description}</span>
      </li>
    <% end %>
    """
  end
end
