defmodule RetroHexChatWeb.Components.UI.ChatTaskbar do
  @moduledoc """
  Visual taskbar composition for the main chat desktop.

  The LiveView owns window state and session state. This component turns that
  read model into the classic horizontal strip of window buttons — the same one
  on every screen size. A phone squeezes the buttons and scrolls the strip, as
  Win98 did; it does not swap in a launcher of its own.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.StartMenuApp

  alias RetroHexChatWeb.ChatLive.WindowRegistry
  alias RetroHexChatWeb.Icons

  attr :chat_label, :string,
    required: true,
    doc: "Title of the pinned chat window — the button mirrors it, as Win98 does"

  attr :open_windows, :any, default: MapSet.new()
  attr :is_admin, :boolean, default: false
  attr :p2p_session, :map, default: nil
  attr :group_call, :map, default: nil
  attr :arcade_session, :map, default: nil
  attr :cc_window_channel, :string, default: nil

  @spec chat_taskbar(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_taskbar(assigns) do
    assigns = assign(assigns, :taskbar_slots, assigns |> taskbar_windows() |> group_windows())

    ~H"""
    <.taskbar id="chat-taskbar">
      <:start>
        <%!-- Only the main chat window goes under Start ▸ Windows: every other
              window on this desktop already has its own entry in one of the
              groups above it, and the chat window has none. --%>
        <.start_menu_app
          id="chat-start-menu"
          screen={:chat}
          is_admin={@is_admin}
          p2p_active={@p2p_session != nil}
          windows={[%{id: "chat", label: @chat_label, icon_fn: :icon_chat}]}
        />
      </:start>

      <%= for slot <- @taskbar_slots do %>
        <.taskbar_group
          :if={slot.kind == :group}
          label={slot.label}
          count={length(slot.windows)}
          testid={"taskbar-group-#{slot.family}"}
        >
          <:icon>{apply(Icons, slot.icon_fn, [%{class: "h-4 w-4"}])}</:icon>
          <.taskbar_button
            :for={window <- slot.windows}
            window={window.id}
            label={window.label}
            class="desktop-taskbar__group-item w-full"
            data-testid={Map.get(window, :testid)}
          >
            <:icon>{apply(Icons, window.icon_fn, [%{class: "h-4 w-4"}])}</:icon>
          </.taskbar_button>
        </.taskbar_group>

        <.taskbar_button
          :if={slot.kind == :window}
          window={slot.window.id}
          label={slot.window.label}
          class="desktop-taskbar__window-button"
          data-testid={Map.get(slot.window, :testid)}
        >
          <:icon>{apply(Icons, slot.window.icon_fn, [%{class: "h-4 w-4"}])}</:icon>
        </.taskbar_button>
      <% end %>

      <:tray>
        <.desktop_tray>
          <span id="chat-tray-clock" data-clock phx-hook="ClockHook" class="font-mono tabular-nums">
          </span>
        </.desktop_tray>
      </:tray>
    </.taskbar>
    """
  end

  # Window families that collapse into one taskbar entry. The taskbar is a
  # single `overflow-x-auto` strip of 12ch-truncated buttons, so 49 windows
  # would be thousands of pixels of horizontal scroll if every open one claimed
  # its own button.
  #
  # A family collapses only while TWO OR MORE of its windows are open: grouping
  # a lone window would add a click and hide nothing. Order is preserved — the
  # group takes the position of its first member, so buttons never jump around
  # as sibling windows open.
  #
  # Which windows belong to which family is declared in `WindowRegistry`; only
  # each family's own label and icon live here, because those describe the
  # button rather than any window. Resolved per call, never in a module
  # attribute: a `dgettext` frozen at compile time is what left these labels
  # reading English in all thirteen locales.
  @spec families() :: [{atom(), String.t(), atom()}]
  defp families do
    [
      {:admin, dgettext("chat", "Admin"), :icon_shield},
      {:system, dgettext("chat", "System"), :icon_server},
      {:account, dgettext("chat", "Account"), :icon_status_user},
      {:contacts, dgettext("chat", "Contacts"), :icon_dialog_address_book},
      {:connect, dgettext("chat", "On Connect"), :icon_dialog_perform}
    ]
  end

  @doc """
  Collapses windows of the same family into one slot.

  A window's family is looked up by id rather than read off the map passed in:
  it is a property of the window, not of this particular listing, and asking
  every caller to carry it would be one more thing that can silently disagree.
  """
  @spec group_windows([map()]) :: [map()]
  def group_windows(windows) do
    family_of =
      Map.new(windows, fn window ->
        {window.id, WindowRegistry.fetch(window.id) |> family_of_window()}
      end)

    windows
    |> Enum.reduce({[], %{}}, fn window, {slots, seen} ->
      case Map.get(family_of, window.id) do
        nil -> {slots ++ [{:window, window}], seen}
        family -> {maybe_placeholder(slots, family, seen), Map.put(seen, family, true)}
      end
    end)
    |> then(fn {slots, _seen} -> Enum.map(slots, &expand_slot(&1, windows)) end)
  end

  defp family_of_window(nil), do: nil
  defp family_of_window(window), do: window.family

  defp maybe_placeholder(slots, family, seen) do
    if Map.has_key?(seen, family), do: slots, else: slots ++ [{:family, family}]
  end

  defp expand_slot({:window, window}, _windows), do: %{kind: :window, window: window}

  defp expand_slot({:family, family}, windows) do
    {^family, label, icon_fn} = Enum.find(families(), &(elem(&1, 0) == family))

    members =
      Enum.filter(windows, fn window ->
        WindowRegistry.fetch(window.id) |> family_of_window() == family
      end)

    case members do
      [only] -> %{kind: :window, window: only}
      many -> %{kind: :group, family: family, label: label, icon_fn: icon_fn, windows: many}
    end
  end

  # Every button on the strip, derived from the one place a window is declared.
  # This used to be a pipeline of twenty-nine hand-written `add_window` calls,
  # each repeating an id, a label and an icon that were also written in the
  # markup and in the menus — which is how twelve windows came to render, focus
  # and cascade correctly while having no button here at all.
  defp taskbar_windows(assigns) do
    capabilities = %{
      admin?: assigns.is_admin,
      open_windows: assigns.open_windows || MapSet.new(),
      p2p_session: assigns.p2p_session,
      group_call: assigns.group_call,
      arcade_session: assigns.arcade_session,
      cc_window_channel: assigns.cc_window_channel
    }

    for window <- WindowRegistry.windows(),
        WindowRegistry.on_taskbar?(window, capabilities) do
      %{
        id: window.id,
        label: label(window, assigns),
        icon_fn: window.icon,
        family: window.family,
        testid: testid(window.id)
      }
    end
  end

  # Three buttons name what they are showing rather than what they are: the
  # chat button mirrors the active conversation, and a call names its peer or
  # channel. Everything else is its registered title.
  defp label(%{id: "chat"}, assigns), do: assigns.chat_label
  defp label(%{id: "p2p-call"}, assigns), do: p2p_call_label(assigns.p2p_session)
  defp label(%{id: "group-call"}, assigns), do: group_call_label(assigns.group_call)
  defp label(window, _assigns), do: window.taskbar_label

  # Two buttons are addressed by the call suites and keep their own hooks.
  defp testid("p2p-call"), do: "p2p-call-taskbar"
  defp testid("group-call"), do: "group-call-taskbar"
  defp testid(_id), do: nil

  defp p2p_call_label(%{peer_nick: peer_nick}) when peer_nick not in [nil, ""] do
    dgettext("chat", "P2P: %{peer}", peer: peer_nick)
  end

  defp p2p_call_label(_p2p_session), do: dgettext("chat", "P2P Session")

  defp group_call_label(%{channel_name: channel_name}) when channel_name not in [nil, ""] do
    channel_name
  end

  defp group_call_label(_group_call), do: dgettext("group_call", "Group Call")
end
