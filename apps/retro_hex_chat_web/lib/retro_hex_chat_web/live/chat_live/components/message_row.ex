defmodule RetroHexChatWeb.ChatLive.Components.MessageRow do
  @moduledoc """
  Pure function component for a single streamed chat message row.

  Renders the row wrapper (the stream `dom_id`, the status/highlight CSS classes,
  and the `data-*` attributes the message-interaction hooks read) plus the body for
  each message type: normal, action, system, service, error, notice, inline-help,
  p2p-invite, deleted, edited, and failed-retry (with its reply block).

  Deterministic and side-effect free. It takes only the rendering context it needs
  (`nick_color_fn`, `timestamp_format`, `timezone`, `strip_formatting`,
  `edit_mode_message_id`) — never the full `Session` — so `MessageViewport` can
  render thousands of rows from its stream cheaply, without a LiveComponent per row.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.MessageRow

  alias RetroHexChatWeb.App.ChatHelpers

  attr :dom_id, :string, required: true
  attr :msg, :map, required: true
  attr :nick_color_fn, :any, required: true
  attr :timestamp_format, :atom, required: true
  attr :timezone, :string, required: true
  attr :strip_formatting, :boolean, required: true
  attr :edit_mode_message_id, :any, required: true
  attr :viewer, :string, default: nil, doc: "Viewing user's nickname (P2P invite cards)"

  @doc "Renders one chat message row (wrapper + type-specific body) for the viewport stream."
  @spec message_row(map()) :: Phoenix.LiveView.Rendered.t()
  def message_row(assigns) do
    ~H"""
    <div
      id={@dom_id}
      class={message_classes(@msg, @edit_mode_message_id)}
      data-testid={if(Map.get(@msg, :highlighted), do: "highlighted-message", else: nil)}
      data-author={Map.get(@msg, :author)}
      data-message-id={@dom_id}
      data-temp-id={if(Map.get(@msg, :status) in [:pending, :failed], do: @msg.id, else: nil)}
      data-msg-status={if(Map.get(@msg, :status), do: Atom.to_string(@msg.status), else: nil)}
      data-system-message={
        if(
          Map.get(@msg, :type, :normal) in [:system, :service, :inline_help],
          do: "true",
          else: nil
        )
      }
      data-real-id={Map.get(@msg, :id)}
    >
      <.message_row_body
        msg={@msg}
        nick_color_fn={@nick_color_fn}
        timestamp_format={@timestamp_format}
        timezone={@timezone}
        strip_formatting={@strip_formatting}
        viewer={@viewer}
      />
    </div>
    """
  end

  @spec message_classes(map(), term()) :: String.t()
  defp message_classes(msg, edit_mode_message_id) do
    base = "chat-message chat-message--#{Map.get(msg, :type, :normal)}"

    highlighted = if Map.get(msg, :highlighted), do: " chat-message--highlighted", else: ""
    highlight_bg = ChatHelpers.highlight_bg_class(msg)
    pending = if Map.get(msg, :status) == :pending, do: " chat-message--pending", else: ""
    failed = if Map.get(msg, :status) == :failed, do: " chat-message--failed", else: ""
    deleted = if Map.get(msg, :deleted_at), do: " chat-message--deleted", else: ""

    editing =
      if Map.get(msg, :id) == edit_mode_message_id, do: " chat-message--editing", else: ""

    base <> highlighted <> highlight_bg <> pending <> failed <> deleted <> editing
  end
end
