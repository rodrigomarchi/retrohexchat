defmodule RetroHexChatWeb.Components.UI.ChatMessage do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc "Renders a scrollable chat message list container."
  attr :class, :any, default: nil
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
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a single IRC-style chat message."
  attr :timestamp, :string, default: nil
  attr :nick, :string, default: nil
  attr :nick_color, :string, default: nil
  attr :type, :string, values: ~w(normal action system service error notice), default: "normal"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec chat_message(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_message(assigns) do
    ~H"""
    <div
      class={classes(["grid grid-cols-[auto_18ch_1fr] items-baseline", type_class(@type), @class])}
      {@rest}
    >
      <span :if={@timestamp} class="text-gray-500 mr-1 font-mono text-xs whitespace-nowrap">
        [{@timestamp}]
      </span>
      <span :if={!@timestamp} />
      <span
        :if={@nick && @type == "normal"}
        class={[
          "font-bold mr-1 font-mono text-right overflow-hidden text-ellipsis whitespace-nowrap",
          @nick_color || "text-text"
        ]}
      >
        &lt;{@nick}&gt;
      </span>
      <span
        :if={@nick && @type == "action"}
        class={[
          "font-bold mr-1 font-mono overflow-hidden text-ellipsis whitespace-nowrap",
          "text-action"
        ]}
      >
        * {@nick}
      </span>
      <span :if={@nick && @type not in ["normal", "action"]} class="font-bold mr-1 font-mono">
        {@nick}
      </span>
      <span :if={!@nick} />
      <span class="font-mono break-words">
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
end
