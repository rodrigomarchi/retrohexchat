defmodule RetroHexChatWeb.Components.UI.ChatMessage do
  @moduledoc """
  Chat message components for the showcase design system.

  Provides `chat_message_list/1` (scrollable container) and
  `chat_message/1` (single IRC-style message row with timestamp,
  nick, and message body).

  ## Usage

      <.chat_message_list>
        <.chat_message timestamp="12:34" nick="alice" nick_color="nick-color-3">
          Hello world!
        </.chat_message>
      </.chat_message_list>
  """
  use RetroHexChatWeb.Component

  @doc "Renders a scrollable chat message list container."
  attr :class, :any, default: nil
  attr :testid, :string, default: "chat-message-list"
  attr :rest, :global
  slot :inner_block, required: true

  @spec chat_message_list(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_message_list(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex-1 overflow-y-auto px-2 py-1 bg-white shadow-retro-field font-mono text-sm",
          @class
        ])
      }
      data-testid={@testid}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a single IRC-style chat message."
  attr :id, :string, default: nil, doc: "Message ID for stream compatibility"
  attr :timestamp, :string, default: nil
  attr :nick, :string, default: nil
  attr :nick_color, :string, default: nil

  attr :type, :string,
    values:
      ~w(normal action system service error notice notify_online notify_offline motd wallops),
    default: "normal"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec chat_message(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_message(assigns) do
    ~H"""
    <div
      id={@id}
      class={
        classes([
          "grid grid-cols-[auto_10ch_1fr] md:grid-cols-[auto_18ch_1fr] items-baseline",
          type_class(@type),
          @class
        ])
      }
      data-message-id={@id}
      {@rest}
    >
      <span :if={@timestamp} class="text-gray-500 mr-1 font-mono text-xs whitespace-nowrap">
        {@timestamp}
      </span>
      <span :if={!@timestamp} />
      <span
        :if={@nick && @type == "normal"}
        class={[
          "chat-nick font-bold mr-1 font-mono text-right overflow-hidden text-ellipsis whitespace-nowrap",
          @nick_color || "text-text"
        ]}
        data-nick={@nick}
      >
        &lt;{@nick}&gt;
      </span>
      <span
        :if={@nick && @type == "action"}
        class={[
          "chat-nick font-bold mr-1 font-mono overflow-hidden text-ellipsis whitespace-nowrap",
          "text-action"
        ]}
        data-nick={@nick}
      >
        * {@nick}
      </span>
      <span
        :if={@nick && @type not in ["normal", "action"]}
        class="chat-nick font-bold mr-1 font-mono"
        data-nick={@nick}
      >
        {@nick}
      </span>
      <span :if={!@nick} />
      <span class={["font-mono break-words", message_body_class(@type)]}>
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  defp type_class("normal"), do: ""
  defp type_class("action"), do: "text-action"
  defp type_class("system"), do: "text-gray-500 italic"
  defp type_class("service"), do: "text-service"
  defp type_class("error"), do: "text-error font-bold"
  defp type_class("notice"), do: "text-notice"
  defp type_class("motd"), do: "text-gray-500 italic"
  defp type_class("wallops"), do: "text-gray-500 italic"
  defp type_class("notify_online"), do: "text-success"
  defp type_class("notify_offline"), do: "text-gray-500 italic"

  defp message_body_class("action"), do: "chat-action"
  defp message_body_class(_type), do: "chat-content"
end
