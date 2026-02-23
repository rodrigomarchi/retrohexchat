defmodule RetroHexChatWeb.Components.ChatMessage do
  @moduledoc """
  Individual chat message rendering with timestamp, color-coded nicks, and type-based styling.
  Supports reply blocks, edited tags, and deleted message display.
  """
  use Phoenix.Component

  @nick_color_count 12

  attr :message, :map, required: true
  attr :timezone, :string, default: "Etc/UTC"

  @spec chat_message(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_message(assigns) do
    assigns =
      assign(assigns, :formatted_time, format_time(assigns.message.timestamp, assigns.timezone))

    assigns = assign(assigns, :nick_color_class, nick_color_class(assigns.message.author))

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
    <span class={["chat-nick", @nick_color_class]}>&lt;{@message.author}&gt;</span>
    <span class="chat-content">{@message.content}</span>
    """
  end

  @spec format_time(DateTime.t() | any(), String.t()) :: String.t()
  defp format_time(%DateTime{} = dt, tz) do
    dt |> RetroHexChatWeb.Timezone.shift(tz) |> Calendar.strftime("%H:%M")
  end

  defp format_time(_, _tz), do: "--:--"

  @spec nick_color_class(String.t()) :: String.t()
  defp nick_color_class(nickname) do
    "nick-color-#{:erlang.phash2(nickname, @nick_color_count)}"
  end
end
