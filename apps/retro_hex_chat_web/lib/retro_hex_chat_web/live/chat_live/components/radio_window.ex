defmodule RetroHexChatWeb.ChatLive.Components.RadioWindow do
  @moduledoc """
  Island for Hex Radio's window body: which stations are listed, which one is
  playing, which are starred, and which of the footer's menus is open.

  The lists come from `RetroHexChat.Radio`, read in a task so the window draws
  at once and fills when the catalog answers. Choosing a station tells the
  catalog it was played and hands it to `RadioHook`, which plays the stream in
  the browser — the sound never passes through the server.

  The favourites are kept by the browser, which sends them when its player is
  ready (`radio_ready`, which also asks for the first list) and is sent them
  back to keep whenever a star changes (`radio:favorites`).

  Mounted inside a server-managed window: closing it unmounts the island and
  the music stops with it.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Radio,
    only: [radio_player: 1, radio_equalizer: 1, radio_browser: 1, genres: 0]

  alias RetroHexChat.Radio
  alias RetroHexChatWeb.ChatLive.Components.DialogIsland

  use RetroHexChatWeb.ChatLive.Components.DialogIsland, id: "hex-radio-window"

  @max_favorites 50

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: @id,
       session: nil,
       section: "top",
       query: "",
       menu: nil,
       stations: [],
       loading?: true,
       error: nil,
       playing: nil,
       favorites: [],
       started?: false
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket),
    do: {:ok, assign(socket, DialogIsland.known(socket, assigns, [:session]))}

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("radio_section", %{"section" => "top"}, socket),
    do: {:noreply, socket |> assign(section: "top", query: "", menu: nil) |> load(:top)}

  def handle_event("radio_section", %{"section" => "favorites"}, socket) do
    {:noreply,
     socket
     |> assign(section: "favorites", query: "", menu: nil)
     |> load({:ids, socket.assigns.favorites})}
  end

  def handle_event("radio_section", %{"section" => tag}, socket) do
    if tag in Radio.genres(),
      do: {:noreply, socket |> assign(section: tag, query: "", menu: nil) |> load({:tag, tag})},
      else: {:noreply, socket}
  end

  # GENRE and FIND open what they name under the list, and close it again.
  def handle_event("radio_menu", %{"menu" => menu}, socket) when menu in ~w(genres search) do
    menu = String.to_existing_atom(menu)
    {:noreply, assign(socket, menu: if(socket.assigns.menu == menu, do: nil, else: menu))}
  end

  def handle_event("radio_search", %{"q" => text}, socket) when is_binary(text) do
    text = String.trim(text)

    if String.length(text) < 2 do
      {:noreply,
       assign(socket,
         query: text,
         error: dgettext("ui", "Type at least two letters of the station's name.")
       )}
    else
      {:noreply,
       socket
       |> assign(section: "search", query: String.slice(text, 0, 60))
       |> load({:name, String.slice(text, 0, 60)})}
    end
  end

  def handle_event("radio_play", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.stations, &(&1.id == id)) do
      nil -> {:noreply, socket}
      station -> {:noreply, play(socket, station)}
    end
  end

  # The previous or next station of the list, round its ends; with nothing
  # playing from this list, its first (or last).
  def handle_event("radio_step", %{"by" => by}, socket) do
    stations = socket.assigns.stations
    playing_id = socket.assigns.playing && socket.assigns.playing.id

    case {stations, Enum.find_index(stations, &(&1.id == playing_id)), step(by)} do
      {[], _index, _step} ->
        {:noreply, socket}

      {_stations, _index, nil} ->
        {:noreply, socket}

      {_stations, nil, 1} ->
        {:noreply, play(socket, hd(stations))}

      {_stations, nil, -1} ->
        {:noreply, play(socket, List.last(stations))}

      {_stations, index, step} ->
        {:noreply,
         play(socket, Enum.at(stations, rem(index + step + length(stations), length(stations))))}
    end
  end

  def handle_event("radio_favorite", %{"id" => id}, socket) when is_binary(id) do
    favorites = toggle(socket.assigns.favorites, id)

    socket =
      socket
      |> assign(favorites: favorites)
      |> push_event("radio:favorites", %{ids: favorites})

    if socket.assigns.section == "favorites",
      do:
        {:noreply,
         assign(socket, stations: Enum.filter(socket.assigns.stations, &(&1.id in favorites)))},
      else: {:noreply, socket}
  end

  # The player is ready in the browser, with the favourites it kept. The first
  # list is asked for now rather than when the window mounts: opened by a
  # command, the window arrives in the reply to the composer's submit, and a
  # list that came back before the browser had taken that reply was dropped.
  def handle_event("radio_ready", %{"ids" => ids}, socket) when is_list(ids) do
    favorites =
      ids
      |> Enum.filter(&(is_binary(&1) and byte_size(&1) in 1..64))
      |> Enum.uniq()
      |> Enum.take(@max_favorites)

    socket = assign(socket, favorites: favorites)

    if socket.assigns.started?,
      do: {:noreply, socket},
      else: {:noreply, socket |> assign(started?: true) |> load(:top)}
  end

  @impl true
  @spec handle_async(atom(), {:ok, term()} | {:exit, term()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_async(:stations, {:ok, {:ok, stations}}, socket),
    do: {:noreply, assign(socket, stations: stations, loading?: false, error: nil)}

  def handle_async(:stations, {:ok, {:error, reason}}, socket),
    do: {:noreply, assign(socket, stations: [], loading?: false, error: error_text(reason))}

  def handle_async(:stations, {:exit, _reason}, socket),
    do: {:noreply, assign(socket, stations: [], loading?: false, error: error_text(:unavailable))}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, genres: genres())

    ~H"""
    <div
      id="hex-radio"
      phx-hook="RadioHook"
      phx-target={@myself}
      tabindex="-1"
      class="hex-radio"
      data-testid="hex-radio"
    >
      <.radio_player
        station={@playing}
        starred?={@playing != nil and @playing.id in @favorites}
        target={@myself}
      />
      <.radio_equalizer />
      <.radio_browser
        section={@section}
        genres={@genres}
        query={@query}
        menu={@menu}
        stations={@stations}
        loading?={@loading?}
        error={@error}
        playing_id={@playing && @playing.id}
        favorites={@favorites}
        target={@myself}
      />
    </div>
    """
  end

  defp play(socket, station) do
    :ok = Radio.played(station.id)

    socket
    |> assign(playing: station)
    |> push_event("radio:play", %{id: station.id, name: station.name, stream: station.stream})
  end

  defp step(by) when by in [1, "1"], do: 1
  defp step(by) when by in [-1, "-1"], do: -1
  defp step(_by), do: nil

  # A later list replaces one still on its way: start_async cancels the task
  # of the same name, so a slow genre never overwrites the one chosen after it.
  defp load(socket, query) do
    socket
    |> assign(loading?: true, error: nil)
    |> start_async(:stations, fn -> Radio.list(query) end)
  end

  defp toggle(favorites, id) do
    if id in favorites,
      do: List.delete(favorites, id),
      else: Enum.take(favorites ++ [id], @max_favorites)
  end

  defp error_text(:invalid),
    do: dgettext("ui", "Type at least two letters of the station's name.")

  defp error_text(_reason),
    do: dgettext("ui", "The station directory is not answering. Try again in a moment.")
end
