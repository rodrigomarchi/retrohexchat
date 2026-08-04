defmodule RetroHexChatWeb.Components.UI.ChatInput do
  @moduledoc """
  Chat input component for the showcase design system.

  Provides a textarea input with optional formatting toolbar slot,
  Send button, and character counter. Supports hooks for autocomplete,
  character counting, and other interactive behaviors.

  ## Usage

      <%!-- Basic (showcase) --%>
      <.chat_input
        value={@draft}
        on_submit="send_message"
      />

      <%!-- Full (real chat) --%>
      <.chat_input
        id="chat-input-area"
        input_id="chat-input"
        value={@input}
        name="input"
        placeholder="Type a message..."
        on_submit="send_input"
        hook="AutocompleteHook"
        wrapper_hook="CharCounterHook"
        autofocus
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders a combined chat input area with textarea, send button, and counter."
  attr :id, :string, default: nil, doc: "Wrapper element ID (for hooks)"
  attr :input_id, :string, default: nil, doc: "Textarea element ID (for hooks and JS focus)"
  attr :value, :string, default: "", doc: "Current input value"
  attr :placeholder, :string, default: nil
  attr :max_length, :integer, default: 1000
  attr :name, :string, default: "message", doc: "Textarea field name"
  attr :disabled, :boolean, default: false
  attr :can_send_empty, :boolean, default: false
  attr :autofocus, :boolean, default: false
  attr :show_toolbar, :boolean, default: true
  attr :notice_target, :string, default: nil
  attr :input_error, :string, default: nil
  attr :content_format, :string, default: "irc"
  attr :on_submit, :any, default: nil, doc: "Form submit / Send button callback"
  attr :on_change, :any, default: nil, doc: "Input change callback"
  attr :on_keydown, :any, default: nil, doc: "Keydown callback (for autocomplete, history, etc.)"
  attr :on_notice_cancel, :any, default: nil, doc: "Cancel notice composer mode"
  attr :input_history, :list, default: []
  attr :recent_commands, :list, default: []

  attr :target, :any,
    default: nil,
    doc: "phx-target for form/button events (e.g. a LiveComponent)"

  attr :hook, :string, default: nil, doc: "Phoenix hook for the textarea (e.g. AutocompleteHook)"

  attr :wrapper_hook, :string,
    default: nil,
    doc: "Phoenix hook for the wrapper div (e.g. CharCounterHook)"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :toolbar_buttons

  @spec chat_input(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_input(assigns) do
    notice_mode? = notice_mode?(assigns.notice_target)

    assigns =
      assigns
      |> assign(:char_count, String.length(assigns.value || ""))
      |> assign(:placeholder, assigns.placeholder || dgettext("chat", "Type a message..."))
      |> assign(:notice_mode?, notice_mode?)
      |> assign(:effective_placeholder, effective_placeholder(assigns, notice_mode?))
      |> assign(:send_label, send_label(notice_mode?))

    ~H"""
    <div
      id={@id}
      class={classes(["flex flex-col", @class])}
      data-testid="chat-input"
      phx-hook={@wrapper_hook}
      {@rest}
    >
      <div
        :if={@notice_mode?}
        class="flex items-center gap-1 px-[2px] pt-[2px] bg-surface text-xs"
        data-testid="chat-notice-composer"
      >
        <Icons.icon_megaphone class="w-4 h-4" />
        <span class="font-bold">
          {dgettext("chat", "Notice to %{target}:", target: @notice_target)}
        </span>
        <.button
          type="button"
          size="icon"
          variant="outline"
          phx-click={@on_notice_cancel}
          phx-target={@target}
          data-testid="chat-notice-cancel"
          class="ml-auto h-6 w-6"
        >
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          <span class="sr-only">{dgettext("chat", "Cancel notice")}</span>
        </.button>
      </div>
      <form
        phx-submit={@on_submit}
        phx-change={@on_change}
        phx-target={@target}
        class="flex items-center gap-1 p-[2px] bg-surface"
        data-testid="chat-input-form"
      >
        <input type="hidden" name="content_format" value={@content_format} />
        <div
          :if={@show_toolbar && @toolbar_buttons != []}
          class="flex shrink-0 items-center gap-0"
          data-testid="chat-input-toolbar"
        >
          {render_slot(@toolbar_buttons)}
        </div>
        <div class="relative flex flex-1 min-w-0">
          <textarea
            id={@input_id}
            name={@name}
            rows="1"
            placeholder={@effective_placeholder}
            maxlength={@max_length}
            disabled={@disabled}
            autocomplete="off"
            autofocus={@autofocus}
            phx-change={@on_change}
            phx-target={@target}
            phx-keydown={@on_keydown}
            phx-hook={@hook}
            data-input-history={Jason.encode!(@input_history)}
            data-recent-commands={Jason.encode!(@recent_commands)}
            data-testid="chat-input-field"
            class="h-8 w-full py-[5px] pl-1 pr-12 font-mono text-sm leading-5 bg-white border border-border shadow-retro-field resize-none outline-none"
          >{@value}</textarea>
          <span
            class="pointer-events-none absolute bottom-[2px] right-1 hidden bg-white px-0.5 text-[9px] leading-none text-muted-foreground md:block"
            data-testid="char-counter"
          >
            {@char_count}/{@max_length}
          </span>
        </div>
        <.button
          type="submit"
          disabled={@disabled || (@char_count == 0 && not @can_send_empty)}
          aria-label={@send_label}
          title={@send_label}
          data-testid="chat-input-send"
          size="icon"
          class="h-8 w-9 min-w-9 px-0"
        >
          <:icon><Icons.icon_btn_send class="w-4 h-4" /></:icon>
          <span class="chat-input-send-label sr-only">{@send_label}</span>
        </.button>
      </form>
      <p
        :if={@input_error}
        class="px-[2px] pb-[2px] bg-surface text-xs text-destructive"
        data-testid="chat-input-error"
      >
        {@input_error}
      </p>
    </div>
    """
  end

  defp effective_placeholder(_assigns, true), do: dgettext("chat", "Notice message")

  defp effective_placeholder(%{placeholder: placeholder}, false), do: placeholder

  defp notice_mode?(target), do: is_binary(target) and target != ""

  defp send_label(true), do: dgettext("chat", "Send Notice")
  defp send_label(false), do: dgettext("chat", "Send")
end
