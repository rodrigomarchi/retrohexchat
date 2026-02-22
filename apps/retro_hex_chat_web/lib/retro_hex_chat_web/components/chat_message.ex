defmodule RetroHexChatWeb.Components.ChatMessage do
  @moduledoc """
  Individual chat message rendering with timestamp, color-coded nicks, and type-based styling.
  Supports reply blocks, edited tags, and deleted message display.
  """
  use Phoenix.Component

  @nick_colors ~w(#e74c3c #3498db #2ecc71 #e67e22 #9b59b6 #1abc9c #f39c12 #e91e63 #00bcd4 #8bc34a #ff5722 #607d8b)

  attr :message, :map, required: true
  attr :timezone, :string, default: "Etc/UTC"

  @spec chat_message(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_message(assigns) do
    assigns =
      assign(assigns, :formatted_time, format_time(assigns.message.timestamp, assigns.timezone))

    assigns = assign(assigns, :nick_color_value, nick_color(assigns.message.author))

    ~H"""
    <div
      class={"chat-message chat-message--#{@message.type}"}
      id={"msg-#{@message.id}"}
      data-nick={@message.author}
    >
      <span class="chat-timestamp">[{@formatted_time}]</span>
      {render_message_body(assigns)}
    </div>
    """
  end

  @spec render_message_body(map()) :: Phoenix.LiveView.Rendered.t()
  defp render_message_body(%{message: %{type: :action}} = assigns) do
    ~H"""
    <span class="chat-action">* {@message.author} {@message.content}</span>
    """
  end

  defp render_message_body(%{message: %{type: :system}} = assigns) do
    ~H"""
    <span class="chat-system">* {@message.content}</span>
    """
  end

  defp render_message_body(%{message: %{type: :service}} = assigns) do
    ~H"""
    <span class="chat-service">{@message.content}</span>
    """
  end

  defp render_message_body(%{message: %{type: :error}} = assigns) do
    ~H"""
    <span class="chat-error">{@message.content}</span>
    """
  end

  defp render_message_body(%{message: %{type: :notice}} = assigns) do
    ~H"""
    <span class="chat-notice">
      <span class="chat-notice-nick">-{@message.author}-</span> {@message.content}
    </span>
    """
  end

  defp render_message_body(assigns) do
    ~H"""
    <span class="chat-nick" style={"color: #{@nick_color_value}"}>&lt;{@message.author}&gt;</span>
    <span class="chat-content">{@message.content}</span>
    """
  end

  @spec format_time(DateTime.t() | any(), String.t()) :: String.t()
  defp format_time(%DateTime{} = dt, tz) do
    dt |> RetroHexChatWeb.Timezone.shift(tz) |> Calendar.strftime("%H:%M")
  end

  defp format_time(_, _tz), do: "--:--"

  @spec nick_color(String.t()) :: String.t()
  defp nick_color(nickname) do
    index = :erlang.phash2(nickname, length(@nick_colors))
    Enum.at(@nick_colors, index)
  end
end
