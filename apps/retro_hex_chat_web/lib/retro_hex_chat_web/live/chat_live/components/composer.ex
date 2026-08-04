defmodule RetroHexChatWeb.ChatLive.Components.Composer do
  @moduledoc """
  Stateful island for the chat composer — the bottom input region plus its
  autocomplete dropdown, syntax tooltip and reply bar.

  Owns the full composition state lifted out of the parent `assign_defaults`:
  the input text and modes (`input`, `input_error`, `notice_target`), command
  history (`command_history`, `history_index`, `recent_commands`), reply state
  (`reply_to`), the edit-input mirror
  (`edit_original_input`), and the transient autocomplete/syntax state
  (`autocomplete_*`, `syntax_tooltip`, `command_help_level`). Keystrokes
  (`input_changed`) now re-render only this component instead of the whole
  ChatLive parent — the dominant change-tracking win on the hottest path.

  The form's own DOM events (`input_changed`/`send_input`/`cancel_notice_mode`)
  target this component via `phx-target={@myself}`. The
  `AutocompleteHook` keeps pushing its keyboard-driven events to the parent,
  which forwards them here via `send_update` (the adapter pattern) — so no JS
  changes and every event-name contract is preserved. On send, the component
  resets itself and bubbles a semantic command to the parent
  (`{:composer_dispatch, text, reply_to}` / `{:composer_submit_edit, content}` /
  `:composer_empty_edit`); the parent runs `Parser.parse` + `CommandDispatch`
  and the edit Service calls (privileged work stays on the LiveView).

  `edit_mode_message_id` stays parent-owned (the MessageViewport reads it for the
  `--editing` row class) and arrives here as passthrough context. The composer
  renders from a context-agnostic read-model: `nickname`, `channel_users`,
  `channels`, `strip_formatting`, `placeholder`, `show_emoji_picker`,
  `pm_typing_from`, and a `capabilities` map (`nick_autocomplete`,
  `channel_autocomplete`, `command_autocomplete`, `formatting_toolbar`, `emoji`,
  `typing_indicator`, `paste`) that toggles which features light up. The main chat
  passes a stable `%Session{}` + `show_status_tab` and the composer derives the
  read-model in `update/2` (keeping change tracking keyed on the session struct);
  a host may pass the `capabilities`/`nickname`/… fields directly. Same
  component, two hosts, no fork.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChatInput
  import RetroHexChatWeb.Components.UI.FormattingToolbar
  import RetroHexChatWeb.Components.UI.Autocomplete
  import RetroHexChatWeb.Components.UI.ReplyBar
  import RetroHexChatWeb.Components.UI.SyntaxTooltip
  import RetroHexChatWeb.Components.UI.HistorySearch
  import RetroHexChatWeb.Components.UI.TypingIndicator

  alias RetroHexChat.Chat.InputHistory
  alias RetroHexChat.Commands.{Autocomplete, CommandSyntax, Registry}
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.ChatLive.Components.EmojiPickerDialog

  @id "composer"

  @spec id() :: String.t()
  def id, do: @id

  @default_capabilities %{
    nick_autocomplete: false,
    channel_autocomplete: true,
    command_autocomplete: true,
    formatting_toolbar: true,
    emoji: true,
    typing_indicator: false,
    paste: true
  }

  @doc "Default capability set (full-chat leaning, safe for first paint)."
  @spec default_capabilities() :: map()
  def default_capabilities, do: @default_capabilities

  @doc """
  Derives the composer capability map from a chat `%Session{}` and the
  status-tab flag, preserving the exact gating the composer used to read inline.
  """
  @spec capabilities_from_session(struct(), boolean()) :: map()
  def capabilities_from_session(session, show_status_tab) do
    %{
      nick_autocomplete: not is_nil(session.active_channel) and not show_status_tab,
      channel_autocomplete: true,
      command_autocomplete: true,
      formatting_toolbar: not show_status_tab,
      emoji: true,
      typing_indicator: not is_nil(session.active_pm),
      paste: true
    }
  end

  @owned_defaults %{
    input: "",
    input_error: nil,
    notice_target: nil,
    command_history: [],
    history_index: -1,
    recent_commands: [],
    reply_to: nil,
    edit_original_input: nil,
    autocomplete_visible: false,
    autocomplete_mode: nil,
    autocomplete_command: nil,
    autocomplete_results: [],
    autocomplete_selected: 0,
    syntax_tooltip: nil,
    command_help_level: :beginner
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(@owned_defaults)
     |> assign(
       nickname: "",
       channel_users: [],
       channels: [],
       strip_formatting: false,
       placeholder: "",
       capabilities: @default_capabilities,
       session: nil,
       show_status_tab: false,
       show_emoji_picker: false,
       pm_typing_from: nil,
       edit_mode_message_id: nil
     )}
  end

  # ── Adapter directives (driven by parent `send_update`) ──────────

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{autocomplete_query: params}, socket),
    do: {:ok, compute_autocomplete(socket, params)}

  def update(%{autocomplete_navigate: direction}, socket),
    do: {:ok, navigate_autocomplete(socket, direction)}

  def update(%{autocomplete_select_current: true}, socket),
    do: {:ok, select_current_autocomplete(socket)}

  def update(%{autocomplete_select: params}, socket),
    do: {:ok, select_autocomplete(socket, params)}

  def update(%{autocomplete_close: true}, socket),
    do: {:ok, close_autocomplete(socket)}

  def update(%{recent_commands_loaded: commands}, socket),
    do: {:ok, assign(socket, recent_commands: commands)}

  def update(%{history_navigate: direction}, socket),
    do: {:ok, navigate_history(socket, direction)}

  def update(%{syntax_query: %{command: command, args: args}}, socket),
    do: {:ok, query_syntax(socket, command, args)}

  def update(%{syntax_dismiss: true}, socket),
    do: {:ok, assign(socket, syntax_tooltip: nil)}

  def update(%{tab_complete: params}, socket),
    do: {:ok, tab_complete(socket, params)}

  def update(%{set_reply_to: reply_to}, socket),
    do: {:ok, assign(socket, reply_to: reply_to)}

  def update(%{cancel_reply: true}, socket),
    do: {:ok, assign(socket, reply_to: nil)}

  def update(%{start_notice: nick}, socket) do
    {:ok,
     socket
     |> assign(notice_target: nick, input: "", input_error: nil)
     |> push_event("clear_input", %{})}
  end

  def update(%{reset_modes: true}, socket) do
    {:ok, assign(socket, notice_target: nil, input_error: nil)}
  end

  def update(%{cancel_notice: true}, socket) do
    {:ok,
     socket
     |> assign(notice_target: nil, input: "", input_error: nil)
     |> push_event("clear_input", %{})}
  end

  def update(%{reset_input: true}, socket) do
    {:ok,
     socket
     |> assign(input: "", input_error: nil)
     |> push_event("clear_input", %{})}
  end

  def update(%{enter_edit: content}, socket) do
    {:ok, assign(socket, edit_original_input: socket.assigns.input, input: content)}
  end

  def update(%{exit_edit: :restore}, socket) do
    original = socket.assigns.edit_original_input || ""

    {:ok,
     socket
     |> assign(edit_original_input: nil, input: original)
     |> push_event("set_input", %{value: original})}
  end

  def update(%{exit_edit: :clear}, socket) do
    {:ok,
     socket
     |> assign(edit_original_input: nil, input: "")
     |> push_event("set_input", %{value: ""})}
  end

  # Passthrough context. Two host shapes converge on the same `capabilities`
  # read-model: the main chat passes a stable `%Session{}` + `show_status_tab`
  # (a struct reference that only changes when the session does, keeping the
  # composer's change tracking tight on the hot path) and the composer derives
  # the flags here; the P2P lobby passes `capabilities`/`nickname`/… directly.
  def update(%{session: _} = assigns, socket) do
    {:ok, socket |> assign(assigns) |> derive_from_session()}
  end

  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  defp derive_from_session(socket) do
    session = socket.assigns.session
    show_status_tab = socket.assigns.show_status_tab

    placeholder =
      ChatHelpers.input_placeholder(%{session: session, show_status_tab: show_status_tab})

    socket
    |> push_placeholder_change(placeholder)
    |> maybe_seed_input_history(session.input_history)
    |> assign(
      nickname: session.nickname,
      channels: session.channels,
      strip_formatting: session.strip_formatting,
      capabilities: capabilities_from_session(session, show_status_tab),
      placeholder: placeholder
    )
  end

  # LiveView skips attribute patches on a focused input, so a placeholder that
  # changes while the user is typing (e.g. /join switching the active channel)
  # never lands through the DOM diff — push it to the input hook explicitly.
  defp push_placeholder_change(socket, placeholder) do
    if Map.get(socket.assigns, :placeholder) == placeholder do
      socket
    else
      push_event(socket, "composer_placeholder", %{placeholder: placeholder})
    end
  end

  # ── Form events (phx-target={@myself}) ───────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("input_changed", %{"input" => input}, socket) do
    {:noreply, assign(socket, input: input, input_error: nil)}
  end

  def handle_event("cancel_notice_mode", _params, socket) do
    send(self(), {:composer_notice_active, false})

    {:noreply,
     socket
     |> assign(notice_target: nil, input: "", input_error: nil)
     |> push_event("clear_input", %{})}
  end

  def handle_event("send_input", %{"input" => ""}, socket) do
    {:noreply, handle_empty_submit(socket)}
  end

  def handle_event("send_input", %{"input" => input}, socket) do
    if socket.assigns.edit_mode_message_id do
      send(self(), {:composer_submit_edit, input})
      {:noreply, socket}
    else
      {:noreply, dispatch_and_reset(socket, input)}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-region"} class="contents">
      <.autocomplete
        visible={@autocomplete_visible}
        items={@autocomplete_results}
        selected_index={@autocomplete_selected}
        mode={@autocomplete_mode || :command}
        command={@autocomplete_command}
        on_select="autocomplete_select"
      />
      <.syntax_tooltip tooltip={@syntax_tooltip} detail_level={@command_help_level} />

      <div class="shrink-0">
        <.live_component
          :if={@capabilities.emoji}
          module={EmojiPickerDialog}
          id={EmojiPickerDialog.id()}
          visible={@show_emoji_picker}
        />

        <.reply_bar
          :if={@reply_to}
          author={@reply_to.author}
          message={@reply_to.preview}
          on_dismiss="cancel_reply"
        />

        <.typing_indicator :if={@capabilities.typing_indicator} nick={@pm_typing_from} />

        <.chat_input
          id="chat-input-area"
          input_id="chat-input"
          value={@input}
          name="input"
          placeholder={@placeholder}
          notice_target={@notice_target}
          input_error={@input_error}
          on_submit="send_input"
          on_change="input_changed"
          on_notice_cancel="cancel_notice_mode"
          target={@myself}
          hook="AutocompleteHook"
          wrapper_hook="CharCounterHook"
          input_history={@command_history}
          recent_commands={@recent_commands}
          autofocus
        >
          <:toolbar_buttons :if={@capabilities.formatting_toolbar}>
            <.formatting_toolbar
              strip_active={@strip_formatting}
              show_emoji={@capabilities.emoji}
              on_format="toggle_strip_formatting"
              on_toggle_emoji="toggle_emoji_picker"
            />
          </:toolbar_buttons>
        </.chat_input>
        <%!-- Composer-owned hook: intercepts multi-line paste on #chat-input and
              pushes `paste_lines` to the root LiveView (handled by core_events,
              which forwards to the PasteConfirmDialog island). --%>
        <div :if={@capabilities.paste} id="paste-hook" phx-hook="PasteHook" class="u-hidden"></div>
        <.history_search visible={true} class="u-hidden" />
      </div>
    </div>
    """
  end

  # ── Send / submit ────────────────────────────────────────────────

  defp dispatch_and_reset(socket, input) do
    submitted = input_for_mode(socket, input)
    reply_to = socket.assigns.reply_to

    current_history =
      InputHistory.from_lists(socket.assigns.command_history, socket.assigns.recent_commands)

    input_history = InputHistory.record_submission(current_history, submitted)
    history = InputHistory.entries(input_history)
    recent_commands = InputHistory.recent_commands(input_history)

    if socket.assigns.notice_target, do: send(self(), {:composer_notice_active, false})

    if input_history != current_history,
      do: send(self(), {:composer_input_history, input_history})

    send(self(), {:composer_dispatch, submitted, reply_to})

    socket
    |> assign(
      input: "",
      notice_target: nil,
      input_error: nil,
      reply_to: nil,
      command_history: history,
      recent_commands: recent_commands,
      history_index: -1,
      autocomplete_visible: false,
      autocomplete_results: [],
      autocomplete_selected: 0,
      syntax_tooltip: nil
    )
    |> push_event("clear_input", %{})
  end

  defp maybe_seed_input_history(socket, input_history) do
    if socket.assigns.command_history == [] and socket.assigns.recent_commands == [] do
      assign(socket,
        command_history: InputHistory.entries(input_history),
        recent_commands: InputHistory.recent_commands(input_history)
      )
    else
      socket
    end
  end

  defp handle_empty_submit(socket) do
    cond do
      socket.assigns.edit_mode_message_id ->
        send(self(), :composer_empty_edit)
        socket

      notice_mode?(socket) ->
        assign(socket, input_error: dgettext("chat", "Notice message cannot be empty"))

      true ->
        socket
    end
  end

  defp input_for_mode(socket, input) do
    if notice_mode?(socket), do: "/notice #{socket.assigns.notice_target} #{input}", else: input
  end

  defp notice_mode?(socket) do
    is_binary(socket.assigns.notice_target) and socket.assigns.notice_target != ""
  end

  # ── Autocomplete ─────────────────────────────────────────────────

  defp compute_autocomplete(socket, %{"type" => "command", "partial" => partial}) do
    if socket.assigns.capabilities.command_autocomplete do
      results = Autocomplete.search_commands(partial, socket.assigns.recent_commands)
      open_autocomplete(socket, :command, results)
    else
      socket
    end
  end

  defp compute_autocomplete(socket, %{"type" => "nick", "partial" => partial}) do
    if socket.assigns.capabilities.nick_autocomplete do
      results =
        Autocomplete.search_nicks(partial, socket.assigns.channel_users, socket.assigns.nickname)

      open_autocomplete(socket, :nick, results)
    else
      socket
    end
  end

  defp compute_autocomplete(socket, %{"type" => "channel", "partial" => partial}) do
    if socket.assigns.capabilities.channel_autocomplete do
      results = Autocomplete.search_channels(partial, socket.assigns.channels)
      open_autocomplete(socket, :channel, results)
    else
      socket
    end
  end

  defp compute_autocomplete(socket, %{
         "type" => "arg_nick",
         "partial" => partial,
         "command" => command
       }) do
    case Autocomplete.argument_context(command) do
      {:nick, scope} when scope in [:current_channel, :all_channels] ->
        results =
          Autocomplete.search_nicks(
            partial,
            socket.assigns.channel_users,
            socket.assigns.nickname
          )

        open_autocomplete(socket, :nick, results)

      _ ->
        socket
    end
  end

  defp compute_autocomplete(socket, %{"type" => "arg_channel", "partial" => partial}) do
    if socket.assigns.capabilities.channel_autocomplete do
      results = Autocomplete.search_channels(partial, socket.assigns.channels)
      open_autocomplete(socket, :channel, results)
    else
      socket
    end
  end

  defp compute_autocomplete(socket, %{
         "type" => "arg_subcommand",
         "partial" => partial,
         "command" => command
       }) do
    results = Autocomplete.search_subcommands(command, partial)

    socket
    |> assign(autocomplete_command: command)
    |> open_autocomplete(:subcommand, results)
  end

  defp compute_autocomplete(socket, _params), do: socket

  defp open_autocomplete(socket, mode, results) do
    assign(socket,
      autocomplete_visible: true,
      autocomplete_mode: mode,
      autocomplete_results: results,
      autocomplete_selected: 0
    )
  end

  defp close_autocomplete(socket) do
    socket
    |> assign(
      autocomplete_visible: false,
      autocomplete_mode: nil,
      autocomplete_command: nil,
      autocomplete_results: [],
      autocomplete_selected: 0
    )
    |> push_event("autocomplete_closed", %{})
  end

  defp navigate_autocomplete(socket, direction) do
    results = socket.assigns.autocomplete_results
    selectable_count = Enum.count(results, &(not is_binary(&1)))
    current = socket.assigns.autocomplete_selected

    new_selected =
      case direction do
        "up" -> rem(current - 1 + selectable_count, max(selectable_count, 1))
        "down" -> rem(current + 1, max(selectable_count, 1))
        _ -> current
      end

    assign(socket, autocomplete_selected: new_selected)
  end

  defp select_current_autocomplete(socket) do
    results = socket.assigns.autocomplete_results
    selected = socket.assigns.autocomplete_selected
    mode = socket.assigns.autocomplete_mode
    selectable = Enum.reject(results, &is_binary/1)

    case Enum.at(selectable, selected) do
      nil ->
        socket

      item ->
        {type, value} = select_item_params(mode, item)
        params = %{"type" => type, "value" => value}

        params =
          if mode == :subcommand,
            do: Map.put(params, "command", socket.assigns.autocomplete_command),
            else: params

        select_autocomplete(socket, params)
    end
  end

  defp select_autocomplete(socket, %{"type" => "command", "value" => command}) do
    set_input_from_select(socket, "/#{command} ")
  end

  defp select_autocomplete(socket, %{"type" => "nick", "value" => nickname}) do
    socket
    |> assign(
      autocomplete_visible: false,
      autocomplete_mode: nil,
      autocomplete_results: [],
      autocomplete_selected: 0
    )
    |> push_event("set_input", %{value: "@#{nickname} "})
  end

  defp select_autocomplete(socket, %{"type" => "channel", "value" => channel_name}) do
    socket
    |> assign(
      autocomplete_visible: false,
      autocomplete_mode: nil,
      autocomplete_results: [],
      autocomplete_selected: 0
    )
    |> push_event("set_input", %{value: channel_name <> " "})
  end

  defp select_autocomplete(socket, %{
         "type" => "subcommand",
         "value" => subcommand,
         "command" => command
       }) do
    value = "/#{command} #{subcommand} "

    socket
    |> assign(autocomplete_command: nil, input: value)
    |> set_input_from_select(value)
  end

  defp select_autocomplete(socket, _params), do: socket

  defp set_input_from_select(socket, value) do
    socket
    |> assign(
      input: value,
      autocomplete_visible: false,
      autocomplete_mode: nil,
      autocomplete_results: [],
      autocomplete_selected: 0
    )
    |> push_event("set_input", %{value: value})
  end

  defp select_item_params(:command, %{name: name}), do: {"command", name}
  defp select_item_params(:nick, %{nickname: nick}), do: {"nick", nick}
  defp select_item_params(:channel, %{name: name}), do: {"channel", name}
  defp select_item_params(:subcommand, %{name: name}), do: {"subcommand", name}
  defp select_item_params(_mode, %{name: name}), do: {"command", name}

  # ── History ──────────────────────────────────────────────────────

  defp navigate_history(socket, direction) do
    history = socket.assigns.command_history
    index = socket.assigns.history_index

    case direction do
      "up" ->
        new_index = min(index + 1, length(history) - 1)

        if new_index >= 0 and new_index < length(history) do
          assign(socket, input: Enum.at(history, new_index), history_index: new_index)
        else
          socket
        end

      "down" ->
        new_index = max(index - 1, -1)

        if new_index >= 0 do
          assign(socket, input: Enum.at(history, new_index), history_index: new_index)
        else
          assign(socket, input: "", history_index: -1)
        end

      _ ->
        socket
    end
  end

  # ── Syntax tooltip ───────────────────────────────────────────────

  defp query_syntax(socket, command, args) do
    case Registry.get_syntax(command) do
      nil ->
        assign(socket, syntax_tooltip: nil)

      %CommandSyntax{} = syntax ->
        current_index = CommandSyntax.compute_current_param_index(syntax.parameters, args)
        payload = CommandSyntax.to_client_payload(syntax)

        tooltip_data =
          Map.merge(payload, %{
            current_param_index: current_index,
            context_message: build_context_message(syntax, args, current_index)
          })

        assign(socket, syntax_tooltip: tooltip_data)
    end
  end

  defp build_context_message(%CommandSyntax{} = syntax, args, current_index) do
    trimmed = String.trim(args)

    cond do
      trimmed == "" or current_index == nil ->
        nil

      syntax.sub_options not in [nil, []] ->
        build_sub_option_context(syntax.sub_options, trimmed)

      true ->
        case Enum.at(syntax.parameters, current_index) do
          nil -> nil
          param -> dgettext("chat", "Next: %{parameter}", parameter: param.name)
        end
    end
  end

  defp build_sub_option_context(sub_options, trimmed) do
    first_arg = trimmed |> String.split(~r/\s+/) |> hd()

    case Enum.find(sub_options, &String.starts_with?(first_arg, &1.flag)) do
      nil ->
        nil

      opt ->
        dgettext("chat", "You are setting: %{flag} (%{label})", flag: opt.flag, label: opt.label)
    end
  end

  # ── Tab complete ─────────────────────────────────────────────────

  defp tab_complete(socket, params) do
    partial = params["partial"]
    is_start = Map.get(params, "is_start", true)
    users = socket.assigns.channel_users
    own_nick = socket.assigns.nickname

    case Autocomplete.tab_complete_matches(partial, users, own_nick) do
      [] -> socket
      matches -> push_event(socket, "tab_matches", %{matches: matches, is_start: is_start})
    end
  end
end
