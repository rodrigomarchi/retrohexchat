defmodule RetroHexChatWeb.ChatLive.Components.HoverCard do
  @moduledoc """
  The nick hover card. Owns the `card` map (visibility, hovered nick, position, and
  the resolved presence/registration/contact fields) so hovering a nick re-renders
  only this island, not the parent chrome.

  The heavy lookup (presence, registry, NickServ, contacts) stays in `HoverEvents`,
  which has the `session`; this component receives the finished map via the `:set`
  action and only renders it. The two PubSub coordinations that used to read the
  parent's `hover_card` now drive this component too:

    * `{:dismiss_if_nick, nick}` — a rename of the hovered nick clears the card
    * `{:update_away, nick, away, message}` — an away change of the hovered nick
      updates the card in place

  `channel_tooltip` / `dismiss_hover_card` are handled globally by `ChatViewportHook`
  (`handleEvent`), so the `dismiss_hover_card` push this component emits on dismiss
  reaches the client regardless of where it originates.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.HoverCard

  @id "hover-card"

  @default %{visible: false, nick: nil, x: 0, y: 0, loading: false, data: nil}

  @doc "Stable component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @doc "The empty hover-card map (hidden, no nick)."
  @spec default() :: map()
  def default, do: @default

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, id: @id, card: @default)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:set, card}}, socket) do
    {:ok, assign(socket, card: card)}
  end

  def update(%{action: :dismiss}, socket) do
    {:ok, assign(socket, card: @default)}
  end

  def update(%{action: {:dismiss_if_nick, nick}}, socket) do
    if socket.assigns.card.nick == nick do
      {:ok, socket |> assign(card: @default) |> push_event("dismiss_hover_card", %{})}
    else
      {:ok, socket}
    end
  end

  def update(%{action: {:update_away, nick, away, message}}, socket) do
    {:ok, update_away(socket, nick, away, message)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, id: Map.get(assigns, :id, socket.assigns.id))}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.hover_card
        :if={@card.visible}
        nick={@card.nick || ""}
        visible={@card.visible}
        loading={@card[:loading] || false}
        x={@card[:x]}
        y={@card[:y]}
        away={@card[:away]}
        host={@card[:host]}
        real_name={@card[:real_name]}
        registered={@card[:registered] || false}
        online_since={@card[:online_since]}
        online_for={@card[:online_for]}
        idle={@card[:idle]}
        client={@card[:client]}
        server={@card[:server]}
        channels={@card[:channels] || []}
        browser={@card[:browser]}
        os={@card[:os]}
        screen_resolution={@card[:screen_resolution]}
        language={@card[:language]}
        timezone_info={@card[:timezone_info]}
        role={@card[:role]}
        is_contact={@card[:is_contact] || false}
        contact_note={@card[:contact_note]}
        is_ignored={@card[:is_ignored] || false}
        on_close="nick_hover_dismiss"
      />
    </div>
    """
  end

  # An away change for the currently-hovered nick updates the card in place.
  @spec update_away(Phoenix.LiveView.Socket.t(), String.t(), boolean(), String.t() | nil) ::
          Phoenix.LiveView.Socket.t()
  defp update_away(socket, nick, away, message) do
    case socket.assigns.card do
      %{visible: true, nick: hover_nick} = card when is_binary(hover_nick) ->
        if String.downcase(hover_nick) == String.downcase(nick) do
          data = Map.get(card, :data) || %{}

          assign(socket,
            card:
              Map.merge(card, %{
                away: if(away, do: message || dgettext("chat", "Away")),
                data: Map.merge(data, %{away: away, away_message: message})
              })
          )
        else
          socket
        end

      _ ->
        socket
    end
  end
end
