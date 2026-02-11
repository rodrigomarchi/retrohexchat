defmodule RetroHexChatWeb.Components.TopicBar do
  @moduledoc """
  Topic bar showing channel name, modes, and topic text.
  Displays different content for channel, PM, and status views.
  """
  use Phoenix.Component

  attr :channel, :string, default: nil
  attr :pm_target, :string, default: nil
  attr :topic, :string, default: nil
  attr :modes, :string, default: nil
  attr :show_status_tab, :boolean, default: false

  @spec topic_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def topic_bar(assigns) do
    ~H"""
    <div class="topic-bar" data-testid="topic-bar">
      <%= cond do %>
        <% @show_status_tab -> %>
          <span class="topic-text">RetroHexChat Status</span>
        <% @pm_target -> %>
          <span class="topic-text">Private conversation with {@pm_target}</span>
        <% @channel -> %>
          <span class="topic-channel">{@channel}</span>
          <span :if={@modes && @modes != ""} class="topic-modes">[{@modes}]</span>
          <span class="topic-separator">|</span>
          <%= if @topic && @topic != "" do %>
            <span class="topic-text">{@topic}</span>
          <% else %>
            <span class="topic-no-topic">(no topic set)</span>
          <% end %>
        <% true -> %>
          <span class="topic-no-topic">Not connected to a channel</span>
      <% end %>
    </div>
    """
  end
end
