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

  alias RetroHexChatWeb.Icons

  @doc "Renders a scrollable chat message list container."
  attr :class, :any, default: nil
  attr :testid, :string, default: "chat-message-list"
  attr :fill, :boolean, default: false, doc: "Shrink to fill remaining flex space (adds min-h-0)"
  attr :hidden, :boolean, default: false, doc: "Hide the container without unmounting it"
  attr :rest, :global
  slot :inner_block, required: true

  @spec chat_message_list(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_message_list(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex-1 overflow-y-auto px-2 py-1 bg-white shadow-retro-field font-mono text-sm",
          @fill && "min-h-0",
          @hidden && "hidden",
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

  @doc """
  Renders a single chat message row.

  Layout is a two-column grid: a compact right-aligned metadata column (a small
  kind icon + the interactive nick *or* non-interactive origin on the first line,
  a smaller timestamp on the second) and the message body, which gets the wider
  column and a slightly larger font. This reads well on phones while keeping the
  retro monospace identity.

  `nick` renders the interactive `.chat-nick[data-nick]` handle (click, hover
  card, PM, context menu). `source` renders a non-interactive origin label
  (e.g. "System", "Error", "MOTD") — never both. `meta_title`
  carries the full datetime for the timestamp's hover/accessibility label.

  A pixel-art kind icon is prepended to that first line to signal the sender at a
  glance (a user glyph for any nick-authored line; a wrench/shield/warning/etc.
  for origin lines). The icon is derived from `type`/`nick`/`source`; pass `kind`
  to override it explicitly (e.g. `"help"`, `"arcade"`, `"deleted"`).
  """
  attr :id, :string, default: nil, doc: "Message ID for stream compatibility"
  attr :timestamp, :string, default: nil
  attr :nick, :string, default: nil, doc: "Interactive author nick (rendered as .chat-nick)"

  attr :source, :string,
    default: nil,
    doc: "Non-interactive origin label"

  attr :nick_color, :string, default: nil
  attr :meta_title, :string, default: nil, doc: "Full datetime for the timestamp hover/aria label"

  attr :type, :string,
    values:
      ~w(normal action system service error notice notify_online notify_offline notify_rename motd wallops announcement),
    default: "normal"

  attr :kind, :string,
    default: nil,
    doc: "Kind-icon override; when nil, derived from type/nick/source"

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
          "grid min-w-0 grid-cols-[5rem_1fr] sm:grid-cols-[7rem_1fr] gap-x-2 items-start py-0.5",
          type_class(@type),
          @class
        ])
      }
      data-message-id={@id}
      {@rest}
    >
      <span class="min-w-0 flex flex-col items-end leading-tight text-right">
        <span class="flex min-w-0 max-w-full items-center gap-1">
          <.message_kind_icon kind={resolve_kind(@kind, @nick, @source, @type)} />
          <span
            :if={@nick}
            class={[
              "chat-nick min-w-0 truncate font-mono text-[13px] font-bold leading-tight",
              @nick_color || "text-text"
            ]}
            data-nick={@nick}
            title={@nick}
          >
            {@nick}
          </span>
          <span
            :if={!@nick && @source}
            class="min-w-0 truncate font-mono text-[13px] font-bold leading-tight"
            title={@source}
          >
            {@source}
          </span>
        </span>
        <time
          :if={@timestamp && @timestamp != ""}
          class="block font-mono text-[9px] text-gray-500 whitespace-nowrap leading-tight"
          data-testid="chat-message-timestamp"
          title={@meta_title}
        >
          {@timestamp}
        </time>
      </span>
      <span class={[
        "font-mono min-w-0 break-words text-[15px] leading-snug",
        message_body_class(@type)
      ]}>
        {render_slot(@inner_block)}
      </span>
    </div>
    """
  end

  @doc """
  Renders the small pixel-art kind icon shown before a message's nick/source.

  `kind` is one of the resolved kinds (`"user"`, `"system"`, `"service"`,
  `"error"`, `"notice"`, `"server"`, `"help"`, `"arcade"`, `"deleted"`);
  anything else renders nothing so an unknown kind never crashes the row.
  """
  @known_kinds ~w(user system service error notice server help arcade deleted)

  attr :kind, :string, required: true
  attr :class, :string, default: "h-3.5 w-3.5"

  @spec message_kind_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def message_kind_icon(assigns) do
    ~H"""
    <span :if={known_kind?(@kind)} class="flex shrink-0" data-message-kind={@kind}>
      <%= case @kind do %>
        <% "user" -> %>
          <Icons.icon_status_user class={@class} />
        <% "system" -> %>
          <Icons.icon_wrench class={@class} />
        <% "service" -> %>
          <Icons.icon_shield class={@class} />
        <% "error" -> %>
          <Icons.icon_warning class={@class} />
        <% "notice" -> %>
          <Icons.icon_megaphone class={@class} />
        <% "server" -> %>
          <Icons.icon_server class={@class} />
        <% "help" -> %>
          <Icons.icon_question class={@class} />
        <% "arcade" -> %>
          <Icons.icon_game_arcade class={@class} />
        <% "deleted" -> %>
          <Icons.icon_close class={@class} />
        <% _ -> %>
      <% end %>
    </span>
    """
  end

  @spec known_kind?(String.t()) :: boolean()
  defp known_kind?(kind), do: kind in @known_kinds

  # An explicit `kind` wins; otherwise any nick-authored line is a user, and
  # source/origin lines map to their type's icon.
  @spec resolve_kind(String.t() | nil, String.t() | nil, String.t() | nil, String.t()) ::
          String.t()
  defp resolve_kind(kind, _nick, _source, _type) when is_binary(kind), do: kind
  defp resolve_kind(_kind, nick, _source, _type) when is_binary(nick) and nick != "", do: "user"
  defp resolve_kind(_kind, _nick, _source, type), do: type_kind(type)

  @spec type_kind(String.t()) :: String.t()
  defp type_kind("service"), do: "service"
  defp type_kind("error"), do: "error"
  defp type_kind("notice"), do: "notice"
  defp type_kind("announcement"), do: "server"
  defp type_kind(_type), do: "system"

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
  defp type_class("notify_rename"), do: "text-notice"
  defp type_class("announcement"), do: "text-service font-bold"
  # Defensive catch-all: an unknown message type must never crash the chat
  # LiveView (which would reload every connected client). Render it plainly.
  defp type_class(_type), do: ""

  defp message_body_class("action"), do: "chat-action"
  defp message_body_class(_type), do: "chat-content"
end
