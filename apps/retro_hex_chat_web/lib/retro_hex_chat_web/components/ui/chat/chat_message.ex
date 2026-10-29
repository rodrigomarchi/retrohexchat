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

  import RetroHexChatWeb.Components.UI.NickFlag
  import RetroHexChatWeb.Components.UI.NickPortrait

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
          "chat-paper flex-1 overflow-y-auto py-1 shadow-retro-field font-mono text-sm",
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

  A row opens with a head — the author (portrait, flag, nickname) or an origin
  with its kind icon, then the time — and goes one of two ways:

    * **stacked** (speech): the head is a line of its own and the text takes the
      full width below it. Metadata costs height, never width, which is what
      makes a phone readable.
    * **inline** (actions, system, service, error, announcement): the text
      continues on the head's own line and wraps back to the left margin, the
      way mIRC printed them.

  Speech is printed in runs, like a continuous-paper log: `band` (`"a"`/`"b"`)
  is the stripe a run is printed on, and `continuation` marks a line that
  continues the run above it. A continuation draws no head; its author and
  time stay in the markup for a screen reader and for Copy Message, and the
  time shows when the line is pointed at or focused.

  `nick` renders the interactive `.chat-nick[data-nick]` handle (click, hover
  card, PM, context menu). `source` renders a non-interactive origin label
  (e.g. "System", "Error", "MOTD") — never both. `meta_title` carries the full
  datetime for the timestamp's hover/accessibility label.

  The kind icon names an origin at a glance (a wrench/shield/warning/etc.). A
  line a person wrote has none: the portrait, flag and coloured nickname already
  say so. It is derived from `type`/`source`; pass `kind` to override it
  explicitly (e.g. `"help"`, `"deleted"`).
  """
  attr :id, :string, default: nil, doc: "Message ID for stream compatibility"
  attr :timestamp, :string, default: nil
  attr :nick, :string, default: nil, doc: "Interactive author nick (rendered as .chat-nick)"

  attr :avatar, :string,
    default: nil,
    doc: "The character the author chose, drawn beside the nick; nil draws nothing"

  attr :locale, :string,
    default: nil,
    doc: "The language the author uses the chat in, drawn as a flag beside the nick"

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

  attr :layout, :string,
    values: ~w(auto stacked inline),
    default: "auto",
    doc: "Overrides the type-derived shape — e.g. a card body always needs stacked"

  attr :band, :string, default: nil, doc: "The stripe the speaker's run is printed on"

  attr :continuation, :boolean,
    default: false,
    doc: "The line continues the run above it and draws no head"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true
  @spec chat_message(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_message(assigns) do
    stacked? = stacked?(assigns.layout, assigns.nick, assigns.type)

    assigns =
      assigns
      |> assign(:stacked?, stacked?)
      |> assign(:continuation, stacked? and assigns.continuation and is_binary(assigns.nick))

    ~H"""
    <div
      id={@id}
      class={classes(["chat-message__row min-w-0", type_class(@type), @class])}
      data-message-id={@id}
      data-message-layout={if(@stacked?, do: "stacked", else: "inline")}
      data-band={@band}
      data-continuation={if(@continuation, do: "true")}
      {@rest}
    >
      <div :if={!@continuation} class="chat-message__head">
        <.message_kind_icon kind={resolve_kind(@kind, @nick, @source, @type)} />
        <.nick_portrait :if={@nick} avatar={@avatar} nickname={@nick} />
        <.nick_flag :if={@nick} locale={@locale} />
        <span
          :if={@nick}
          class={["chat-nick chat-message__author", @nick_color || "text-text"]}
          data-nick={@nick}
          title={@nick}
        >
          {@nick}
        </span>
        <span
          :if={!@nick && @source}
          class="chat-message__author"
          title={@source}
        >
          {@source}
        </span>
        <time
          :if={@timestamp && @timestamp != ""}
          class="chat-message__time"
          data-testid="chat-message-timestamp"
          title={@meta_title}
        >
          {@timestamp}
        </time>
        <span :if={!@stacked?} class={["chat-message__text", message_body_class(@type)]}>
          {render_slot(@inner_block)}
        </span>
      </div>

      <div :if={@stacked?} class="chat-message__body">
        <span :if={@continuation} class="chat-nick chat-message__author sr-only" data-nick={@nick}>
          {@nick}
        </span>
        <time
          :if={@continuation && @timestamp && @timestamp != ""}
          class="chat-message__time chat-message__time--margin"
          data-testid="chat-message-timestamp"
          title={@meta_title}
        >
          {@timestamp}
        </time>
        <div class={["chat-message__text", message_body_class(@type)]}>
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  # Speech gets its own line of text; everything else rides the head line.
  # An action is nick-authored but reads as one sentence ("* alice waves"), so
  # it stays inline with the rest of the narration.
  @spec stacked?(String.t(), String.t() | nil, String.t()) :: boolean()
  defp stacked?("stacked", _nick, _type), do: true
  defp stacked?("inline", _nick, _type), do: false
  defp stacked?(_auto, _nick, "action"), do: false
  defp stacked?(_auto, nick, _type), do: is_binary(nick) and nick != ""

  @doc """
  Renders the small pixel-art kind icon shown before a message's nick/source.

  `kind` is one of the resolved kinds (`"system"`, `"service"`, `"error"`,
  `"notice"`, `"server"`, `"help"`, `"deleted"`); anything else renders
  nothing so an unknown kind never crashes the row. A line a person wrote has
  no kind icon.
  """
  @known_kinds ~w(system service error notice server help deleted)

  attr :kind, :string, default: nil
  attr :class, :string, default: "h-3.5 w-3.5"

  @spec message_kind_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def message_kind_icon(assigns) do
    ~H"""
    <span :if={known_kind?(@kind)} class="flex shrink-0" data-message-kind={@kind}>
      <%= case @kind do %>
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
        <% "deleted" -> %>
          <Icons.icon_close class={@class} />
        <% _ -> %>
      <% end %>
    </span>
    """
  end

  @spec known_kind?(String.t() | nil) :: boolean()
  defp known_kind?(kind), do: kind in @known_kinds

  # An explicit `kind` wins; otherwise a nick-authored line has no icon, and
  # source/origin lines map to their type's icon.
  @spec resolve_kind(String.t() | nil, String.t() | nil, String.t() | nil, String.t()) ::
          String.t() | nil
  defp resolve_kind(kind, _nick, _source, _type) when is_binary(kind), do: kind
  defp resolve_kind(_kind, nick, _source, _type) when is_binary(nick) and nick != "", do: nil
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
