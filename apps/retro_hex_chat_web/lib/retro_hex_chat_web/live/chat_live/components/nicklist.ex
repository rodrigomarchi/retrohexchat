defmodule RetroHexChatWeb.ChatLive.Components.Nicklist do
  @moduledoc """
  The conversation's user list sidebar. Owns the role-grouped member streams, so
  the roster updates on membership/role/away/mute deltas, not on every chat
  re-render of the parent LiveView.

  It describes whichever conversation is on screen. A channel is its members,
  grouped by role; a private conversation is its two participants, the other
  person first. `RetroHexChat.Chat.Roster` decides who those are and in what
  order — this renders whatever it is handed, so the two kinds cannot drift into
  two lists.

  The parent stays the canonical owner of `conversation_members`: the tab-complete
  (`MenuToolbarEvents`), the nicklist context menu and several PubSub handlers read
  the materialized list. The parent keeps that list and feeds this component the
  matching delta via `send_update/2`:

    * `{:reset, users}` — conversation switch or bulk change (mode, away, rename)
    * `{:upsert, user}` — a single user joined or changed
    * `{:remove, nick}` — a single user left or was kicked

  `show_nicklist` stays on the parent (toggled from the menu/toolbar and read by
  the sidebar visibility gate); it arrives here as `visible`. The container is kept
  mounted while hidden (via a CSS class, not `:if`) so the stream is never torn
  down and rebuilt on toggle. The right-click/double-click `NicklistHook` pushes to
  the parent, which owns the context menu and reads `conversation_members` there.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ListStates
  import RetroHexChatWeb.Components.UI.Nicklist

  alias RetroHexChatWeb.Components.UI.Chat.Role

  @id "nicklist"

  # A busy channel can hold more members than anyone scrolls through, and every
  # one of them would be a DOM row. Rendering is bounded and the total is shown,
  # so a capped list never presents itself as the whole membership.
  @max_rendered 500

  @role_sections [
    %{key: :owner, stream: :owners},
    %{key: :operator, stream: :operators},
    %{key: :half_operator, stream: :half_operators},
    %{key: :voiced, stream: :voiced},
    %{key: :regular, stream: :regulars},
    %{key: :bot, stream: :bots}
  ]

  @doc "Stable component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @doc "Stable DOM id for a user's stream row, keyed by the normalized nick."
  @spec dom_id(String.t()) :: String.t()
  def dom_id(nick), do: "nick-" <> String.downcase(nick)

  @doc "Replaces the whole list (channel switch or bulk change). Returns the socket."
  @spec reset(Phoenix.LiveView.Socket.t(), [map()]) :: Phoenix.LiveView.Socket.t()
  def reset(socket, users) do
    send_update(__MODULE__, id: @id, action: {:reset, users})
    socket
  end

  @doc "How many member rows the list renders at most."
  @spec max_rendered() :: pos_integer()
  def max_rendered, do: @max_rendered

  @doc "Inserts or updates a single user row. Returns the socket."
  @spec upsert(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def upsert(socket, user) do
    send_update(__MODULE__, id: @id, action: {:upsert, user})
    socket
  end

  @doc """
  Marks who is in the channel's conference. Returns the socket.

  Takes the nicknames rather than reading the summary here: the chat already
  holds it for the tab badge and the card in the conversation, and a second
  reader of the same room is how two parts of one screen come to disagree
  about it.
  """
  @spec mark_in_call(Phoenix.LiveView.Socket.t(), [String.t()]) :: Phoenix.LiveView.Socket.t()
  def mark_in_call(socket, nicks) when is_list(nicks) do
    send_update(__MODULE__, id: @id, action: {:in_call, nicks})
    socket
  end

  @doc "Removes a single user row by nick. Returns the socket."
  @spec remove(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def remove(socket, nick) do
    send_update(__MODULE__, id: @id, action: {:remove, nick})
    socket
  end

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    socket =
      socket
      |> assign(
        id: @id,
        available: true,
        visible: false,
        conversation_kind: :channel,
        conversation_label: nil,
        current_modes: nil,
        current_nick: nil,
        users: [],
        sections: [],
        total: 0,
        online_count: 0,
        away_count: 0,
        muted_count: 0,
        call_nicks: MapSet.new(),
        nick_color_fn: fn _nick -> nil end
      )

    {:ok, Enum.reduce(@role_sections, socket, &stream_role_section(&2, &1, []))}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:reset, users}} = assigns, socket) do
    users = sort_users(users)

    {:ok,
     socket
     |> assign_context(assigns)
     |> assign_roster(users)
     |> reset_role_streams(users)}
  end

  def update(%{action: {:upsert, user}} = assigns, socket) do
    users =
      socket.assigns.users
      |> upsert_user(user)
      |> sort_users()

    {:ok,
     socket
     |> assign_context(assigns)
     |> assign_roster(users)
     |> reset_role_streams(users)}
  end

  def update(%{action: {:remove, nick}} = assigns, socket) do
    users = Enum.reject(socket.assigns.users, &same_nick?(&1.nickname, nick))

    {:ok,
     socket
     |> assign_context(assigns)
     |> assign_roster(users)
     |> reset_role_streams(users)}
  end

  # Who is in the channel's conference, from the summary the chat already keeps
  # for the badge and the card. Re-streaming rather than reading it per row on
  # render: these are stream items, and a stream item is drawn when it is
  # inserted, not when an assign around it changes.
  def update(%{action: {:in_call, nicks}} = assigns, socket) do
    wanted = MapSet.new(nicks, &String.downcase/1)

    if wanted == socket.assigns.call_nicks do
      {:ok, assign_context(socket, assigns)}
    else
      socket = assign_context(socket, Map.put(assigns, :call_nicks, wanted))
      {:ok, reset_role_streams(socket, socket.assigns.users)}
    end
  end

  def update(assigns, socket) do
    {:ok, assign_context(socket, assigns)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assign(assigns,
        max_rendered: @max_rendered,
        variant: if(assigns.conversation_kind == :private, do: "pm", else: "channel")
      )

    ~H"""
    <div id={"#{@id}-mount"} class="flex h-full shrink-0">
      <.nicklist_sidebar
        available={@available}
        visible={@visible}
        on_backdrop="toggle_nicklist"
        on_toggle="toggle_nicklist"
        id="nicklist-users"
        phx-hook="NicklistHook"
      >
        <:rail>
          <.nicklist_rail
            expanded={@visible}
            variant={@variant}
            label={@conversation_label}
            total={@total}
            online_count={@online_count}
            away_count={@away_count}
            muted_count={@muted_count}
            sections={@sections}
            on_toggle="toggle_nicklist"
          />
        </:rail>
        <.nicklist_header
          variant={@variant}
          label={@conversation_label}
          total={@total}
          modes={@current_modes}
          on_close="toggle_nicklist"
        />
        <.nicklist_status_strip
          online_count={@online_count}
          away_count={@away_count}
          muted_count={@muted_count}
        />
        <.nicklist_body>
          <.nicklist_section
            :for={section <- @sections}
            role={section.key}
            label={section.label}
            count={section.count}
          >
            <div
              id={"nicklist-users-#{Role.slug(section.key)}"}
              class="contents"
              phx-update="stream"
            >
              <.nicklist_item
                :for={{dom_id, user} <- stream_rows(@streams, section.stream)}
                id={dom_id}
                nick={user.nickname}
                role={Map.get(user, :role, :normal)}
                status={row_status(user)}
                muted={Map.get(user, :muted, false)}
                current={same_nick?(user.nickname, @current_nick)}
                in_call={MapSet.member?(@call_nicks, String.downcase(user.nickname))}
                nick_color={@nick_color_fn.(user.nickname)}
                data-nick={user.nickname}
              />
            </div>
          </.nicklist_section>
          <.list_count_strip shown={min(@total, @max_rendered)} total={@total} />
        </.nicklist_body>
      </.nicklist_sidebar>
    </div>
    """
  end

  @spec row_dom_id(map()) :: String.t()
  defp row_dom_id(user), do: dom_id(user.nickname)

  defp assign_context(socket, assigns) do
    assign(socket,
      id: Map.get(assigns, :id, socket.assigns.id),
      available: Map.get(assigns, :available, socket.assigns.available),
      visible: Map.get(assigns, :visible, socket.assigns.visible),
      conversation_kind: Map.get(assigns, :conversation_kind, socket.assigns.conversation_kind),
      conversation_label:
        Map.get(assigns, :conversation_label, socket.assigns.conversation_label),
      current_modes: Map.get(assigns, :current_modes, socket.assigns.current_modes),
      current_nick: Map.get(assigns, :current_nick, socket.assigns.current_nick),
      nick_color_fn: Map.get(assigns, :nick_color_fn, socket.assigns.nick_color_fn),
      call_nicks: normalize_call_nicks(assigns, socket)
    )
  end

  # Normalised on the way in, once. The summary spells a nickname the way its
  # owner typed it and the rows are keyed by the downcased form; matching them
  # at render time is how the marker comes to be right for `bob` and wrong for
  # `Bob`.
  defp normalize_call_nicks(assigns, socket) do
    case Map.get(assigns, :call_nicks) do
      nil -> socket.assigns.call_nicks
      nicks -> MapSet.new(nicks, &String.downcase/1)
    end
  end

  defp assign_roster(socket, users) do
    section_counts = section_counts(users)
    kind = socket.assigns.conversation_kind

    sections =
      @role_sections
      |> Enum.map(fn section ->
        section
        |> Map.put(:label, section_label(section.key, kind))
        |> Map.put(:count, Map.get(section_counts, section.key, 0))
      end)

    # Every section, every time. The empty ones hide themselves; dropping
    # them here would take their stream containers out of the DOM.

    assign(socket,
      users: users,
      sections: sections,
      total: length(users),
      online_count: Enum.count(users, &online?/1),
      away_count: Enum.count(users, &Map.get(&1, :away, false)),
      muted_count: Enum.count(users, &Map.get(&1, :muted, false))
    )
  end

  # A channel member is present by virtue of being in the channel; the other
  # person in a private conversation may simply not be connected.
  defp online?(user), do: Map.get(user, :online, true) and not Map.get(user, :away, false)

  defp row_status(user) do
    cond do
      not Map.get(user, :online, true) -> "offline"
      Map.get(user, :away, false) -> "away"
      true -> "online"
    end
  end

  defp reset_role_streams(socket, users) do
    visible_groups =
      users
      |> Enum.take(@max_rendered)
      |> Enum.group_by(&Role.key(Map.get(&1, :role, :regular)))

    Enum.reduce(@role_sections, socket, fn section, acc ->
      stream_role_section(acc, section, Map.get(visible_groups, section.key, []), reset: true)
    end)
  end

  defp stream_role_section(socket, section, users, opts \\ []) do
    stream(socket, section.stream, users, Keyword.merge([dom_id: &row_dom_id/1], opts))
  end

  defp section_counts(users) do
    Enum.reduce(users, %{}, fn user, acc ->
      Map.update(acc, Role.key(Map.get(user, :role, :regular)), 1, &(&1 + 1))
    end)
  end

  defp stream_rows(streams, stream_name), do: Map.get(streams, stream_name, [])

  defp upsert_user(users, user) do
    users
    |> Enum.reject(&same_nick?(&1.nickname, user.nickname))
    |> then(&[user | &1])
  end

  # The roster ranks its members — by role in a channel, by who the conversation
  # is with in a private one — and a single-row upsert has to land in the same
  # order the full load produced.
  defp sort_users(users) do
    Enum.sort_by(users, fn user ->
      {Map.get(user, :rank) || role_rank(Map.get(user, :role, :regular)),
       String.downcase(user.nickname)}
    end)
  end

  defp role_rank(:owner), do: 0
  defp role_rank(:operator), do: 1
  defp role_rank(:half_operator), do: 2
  defp role_rank(:voiced), do: 3
  defp role_rank(:regular), do: 4
  defp role_rank(:bot), do: 5
  defp role_rank(role), do: role |> Role.key() |> role_rank()

  # A private conversation has no channel roles to group by: everyone in it is
  # simply one of the two people talking.
  defp section_label(:regular, :private), do: dgettext("chat", "Participants")
  defp section_label(role, _kind), do: section_label(role)

  defp section_label(:owner), do: dgettext("chat", "Owner")
  defp section_label(:operator), do: dgettext("chat", "Operator")
  defp section_label(:half_operator), do: dgettext("chat", "Half-Op")
  defp section_label(:voiced), do: dgettext("chat", "Voiced")
  defp section_label(:bot), do: dgettext("chat", "Bot")
  defp section_label(:regular), do: dgettext("chat", "Users")

  defp same_nick?(_nick, nil), do: false
  defp same_nick?(nil, _nick), do: false

  defp same_nick?(left, right) do
    String.downcase(left) == String.downcase(right)
  end
end
