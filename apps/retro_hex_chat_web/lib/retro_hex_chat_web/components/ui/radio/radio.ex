defmodule RetroHexChatWeb.Components.UI.Radio do
  @moduledoc """
  Hex Radio, drawn as the appliance it is: three stacked panels in graphite
  and Hex teal, under the window's thin `device` title strip.

    * the player — an amber LCD with the time, the spectrum, the station and
      its facts, the volume, the EQ and LIST switches, and the transport
    * the equaliser — on/off, flat, the preamp and ten bands, with their curve
    * the stations — a numbered list, with the lists and the search on the
      buttons under it

  The sound lives in the browser (`lib/radio/`, through `RadioHook`): the
  stream, the spectrum, the volume and the equaliser never round-trip through
  the server, so their controls send a `radio:command` to the hook root
  (`JS.dispatch`) and the LCD's moving fields are written there. What the
  server owns is the list — which stations, which is playing, which are
  starred, which list is open — and it draws that from the window's island.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChat.Radio.Station
  alias RetroHexChatWeb.Icons

  @root "#hex-radio"

  # The bands of the equaliser, in hertz, as a classic player draws them.
  @bands [60, 170, 310, 600, 1_000, 3_000, 6_000, 12_000, 14_000, 16_000]

  @doc "The element the controls send their commands to."
  @spec root() :: String.t()
  def root, do: @root

  @doc "The equaliser's bands, in hertz."
  @spec bands() :: [pos_integer()]
  def bands, do: @bands

  @doc "A command for the player, sent from a button."
  @spec command(String.t(), map()) :: Phoenix.LiveView.JS.t()
  def command(name, detail \\ %{}),
    do: JS.dispatch("radio:command", to: @root, detail: Map.put(detail, :command, name))

  # A panel shown or put away by its switch. A JS command, not an assign: the
  # browser keeps the attribute through every patch, so the server never has
  # to know which panels are open.
  defp toggle_panel(panel, switch) do
    JS.toggle_attribute({"data-open", "true", "false"}, to: panel)
    |> JS.toggle_attribute({"aria-pressed", "true", "false"}, to: switch)
  end

  @doc """
  The player: the LCD, the volume and the panel switches, and the transport.
  The station, its facts and its star are the server's; the time, the state
  and the spectrum are written by the browser.
  """
  attr :station, :any, required: true, doc: "the station chosen, a `Radio.Station` or nil"
  attr :starred?, :boolean, required: true
  attr :target, :any, required: true

  @spec radio_player(map()) :: Phoenix.LiveView.Rendered.t()
  def radio_player(assigns) do
    ~H"""
    <section class="hex-radio__main" data-testid="hex-radio-player">
      <div class="hex-radio__lcd" data-testid="hex-radio-display">
        <div class="hex-radio__clock">
          <span class="hex-radio__glyph" aria-hidden="true"></span>
          <span
            id="hex-radio-time"
            class="hex-radio__time"
            phx-update="ignore"
            data-radio-field="time"
          >
            --:--
          </span>
        </div>
        <div id="hex-radio-scope-wrap" class="hex-radio__scope" phx-update="ignore">
          <canvas
            data-radio-scope
            class="hex-radio__canvas"
            title={dgettext("ui", "Click to switch between the spectrum and the oscilloscope")}
            phx-click={command("visual")}
            data-testid="hex-radio-scope"
          ></canvas>
        </div>
        <div class="hex-radio__info">
          <div class="hex-radio__marquee">
            <span class="hex-radio__name" data-testid="hex-radio-station-name">
              {if @station, do: @station.name, else: dgettext("ui", "Choose a station")}
            </span>
          </div>
          <div class="hex-radio__facts" data-testid="hex-radio-station-facts">
            <span :if={@station && @station.bitrate} class="hex-radio__fact">
              <span class="hex-radio__box">{@station.bitrate}</span>kbps
            </span>
            <span :if={@station && @station.codec} class="hex-radio__box">{@station.codec}</span>
            <span :if={@station && @station.country} class="hex-radio__box">
              {@station.country}
            </span>
            <span class="hex-radio__lamps">
              <span class="hex-radio__lamp hex-radio__lamp--live">{dgettext("ui", "LIVE")}</span>
              <span
                class="hex-radio__lamp hex-radio__lamp--sim"
                title={
                  dgettext("ui", "This station does not share its sound: the bars only dance along")
                }
              >
                {dgettext("ui", "SIM")}
              </span>
            </span>
          </div>
          <div
            id="hex-radio-status-state"
            class="hex-radio__state"
            phx-update="ignore"
            data-radio-status="state"
            data-testid="hex-radio-status-state"
          >
            {dpgettext("ui", "radio", "Stopped")}
          </div>
        </div>
      </div>

      <div class="hex-radio__row">
        <button
          type="button"
          class="hex-radio__key hex-radio__key--icon"
          aria-pressed="false"
          aria-label={dgettext("ui", "Mute")}
          title={dgettext("ui", "Mute")}
          data-radio-toggle="mute"
          phx-click={command("mute")}
          data-testid="hex-radio-mute"
        >
          <Icons.icon_radio_volume class="h-4 w-4" />
        </button>
        <div id="hex-radio-volume-wrap" class="hex-radio__volume" phx-update="ignore">
          <input
            id="hex-radio-volume"
            type="range"
            name="radio-volume"
            min="0"
            max="100"
            value="80"
            class="hex-radio__slider"
            aria-label={dgettext("ui", "Volume")}
            data-radio-volume
            data-testid="hex-radio-volume"
          />
        </div>
        <button
          id="hex-radio-equalizer-toggle"
          type="button"
          class="hex-radio__key hex-radio__key--switch"
          aria-pressed="false"
          phx-click={toggle_panel("#hex-radio-equalizer", "#hex-radio-equalizer-toggle")}
          data-testid="hex-radio-equalizer-toggle"
        >
          {dgettext("ui", "EQ")}
        </button>
        <button
          id="hex-radio-list-toggle"
          type="button"
          class="hex-radio__key hex-radio__key--switch"
          aria-pressed="true"
          phx-click={toggle_panel("#hex-radio-stations", "#hex-radio-list-toggle")}
          data-testid="hex-radio-list-toggle"
        >
          {dgettext("ui", "LIST")}
        </button>
      </div>

      <div class="hex-radio__transport">
        <button
          type="button"
          class="hex-radio__key"
          aria-label={dgettext("ui", "Previous station")}
          title={dgettext("ui", "Previous station")}
          phx-click="radio_step"
          phx-value-by="-1"
          phx-target={@target}
          data-testid="hex-radio-prev"
        >
          <Icons.icon_radio_prev class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="hex-radio__key"
          aria-label={dpgettext("ui", "radio", "Play")}
          title={dpgettext("ui", "radio", "Play")}
          phx-click={play_click(@station, @target)}
          data-testid="hex-radio-play"
        >
          <Icons.icon_radio_play class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="hex-radio__key"
          aria-label={dgettext("ui", "Stop")}
          title={dgettext("ui", "Stop")}
          phx-click={command("stop")}
          data-testid="hex-radio-stop"
        >
          <Icons.icon_radio_stop class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="hex-radio__key"
          aria-label={dgettext("ui", "Next station")}
          title={dgettext("ui", "Next station")}
          phx-click="radio_step"
          phx-value-by="1"
          phx-target={@target}
          data-testid="hex-radio-next"
        >
          <Icons.icon_radio_next class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="hex-radio__key hex-radio__key--star"
          aria-pressed={to_string(@starred?)}
          aria-label={star_label(@starred?)}
          title={star_label(@starred?)}
          disabled={is_nil(@station)}
          phx-click="radio_favorite"
          phx-value-id={@station && @station.id}
          phx-target={@target}
          data-testid="hex-radio-star"
        >
          <Icons.icon_btn_star class="h-4 w-4" />
        </button>
        <span class="hex-radio__badge" aria-hidden="true">
          <Icons.icon_hex_stone class="h-6 w-6" />
        </span>
      </div>
    </section>
    """
  end

  # Play with nothing chosen plays the first station of the list.
  defp play_click(nil, target),
    do: JS.push("radio_step", value: %{by: 1}, target: target)

  defp play_click(_station, _target), do: command("play")

  defp star_label(true), do: dgettext("ui", "Remove from favorites")
  defp star_label(false), do: dgettext("ui", "Add to favorites")

  @doc """
  The equaliser: on and off, flat, the preamp, the ten bands and their curve.
  Shut until EQ opens it; the browser draws the curve and knows whether the
  station lets the sound in.
  """
  @spec radio_equalizer(map()) :: Phoenix.LiveView.Rendered.t()
  def radio_equalizer(assigns) do
    assigns = assign(assigns, bands: @bands)

    ~H"""
    <section
      id="hex-radio-equalizer"
      class="hex-radio__panel"
      data-open="false"
      phx-update="ignore"
      data-testid="hex-radio-equalizer"
    >
      <h3 class="hex-radio__panel-title">{dgettext("ui", "Equalizer")}</h3>
      <div class="hex-radio__eq-head">
        <button
          type="button"
          class="hex-radio__key hex-radio__key--switch"
          aria-pressed="true"
          data-radio-toggle="eq-power"
          phx-click={command("eq-power")}
          data-testid="hex-radio-eq-power"
        >
          {dgettext("ui", "ON")}
        </button>
        <canvas data-radio-curve class="hex-radio__curve" aria-hidden="true"></canvas>
        <button
          type="button"
          class="hex-radio__key"
          phx-click={command("flat")}
          data-testid="hex-radio-eq-flat"
        >
          {dgettext("ui", "Flat")}
        </button>
      </div>
      <div class="hex-radio__bands">
        <label class="hex-radio__band hex-radio__band--preamp">
          <.band_slider name="preamp" label={dgettext("ui", "Preamp")} testid="hex-radio-preamp" />
          <span class="hex-radio__band-label">{dgettext("ui", "PRE")}</span>
        </label>
        <span class="hex-radio__scale" aria-hidden="true">
          <span>+12</span><span>0</span><span>-12</span>
        </span>
        <label :for={{band, index} <- Enum.with_index(@bands)} class="hex-radio__band">
          <.band_slider name={index} label={band_label(band)} testid={"hex-radio-band-#{index}"} />
          <span class="hex-radio__band-label">{band_label(band)}</span>
        </label>
      </div>
      <p class="hex-radio__eq-note" data-radio-field="eq-note"></p>
    </section>
    """
  end

  attr :name, :any, required: true
  attr :label, :string, required: true
  attr :testid, :string, required: true

  # A trackbar turned on its side, inside a box the height an upright one takes.
  defp band_slider(assigns) do
    ~H"""
    <span class="hex-radio__band-track">
      <input
        type="range"
        min="-12"
        max="12"
        step="1"
        value="0"
        class="hex-radio__slider hex-radio__band-slider"
        aria-label={@label}
        data-radio-band={@name}
        data-testid={@testid}
      />
    </span>
    """
  end

  defp band_label(hz) when hz >= 1_000, do: "#{div(hz, 1_000)}K"
  defp band_label(hz), do: Integer.to_string(hz)

  @doc """
  The stations: a numbered list with the playing one lit, and under it the
  lists — the most played, a genre, the favourites — and the search.
  """
  attr :section, :string, required: true
  attr :genres, :list, required: true, doc: "`{tag, label}`"
  attr :query, :string, required: true
  attr :menu, :atom, required: true, doc: "`:genres`, `:search` or nil — what the footer opened"
  attr :stations, :list, required: true
  attr :loading?, :boolean, required: true
  attr :error, :string, default: nil
  attr :playing_id, :string, default: nil
  attr :favorites, :list, required: true
  attr :target, :any, required: true

  @spec radio_browser(map()) :: Phoenix.LiveView.Rendered.t()
  def radio_browser(assigns) do
    ~H"""
    <section
      id="hex-radio-stations"
      class="hex-radio__panel hex-radio__stations"
      data-open="true"
      data-testid="hex-radio-stations"
    >
      <h3 class="hex-radio__panel-title" data-testid="hex-radio-list-title">
        {section_title(@section, @genres, @query)}
      </h3>

      <.form
        :if={@menu == :search}
        for={%{}}
        id="hex-radio-search"
        class="hex-radio__search"
        phx-submit="radio_search"
        phx-target={@target}
      >
        <input
          id="hex-radio-search-input"
          name="q"
          value={@query}
          type="text"
          enterkeyhint="search"
          maxlength="60"
          autocomplete="off"
          phx-mounted={JS.focus()}
          placeholder={dgettext("ui", "Search stations by name")}
          aria-label={dgettext("ui", "Search stations by name")}
          class="hex-radio__field"
          data-testid="hex-radio-search-input"
        />
        <button type="submit" class="hex-radio__key" data-testid="hex-radio-search-submit">
          {dgettext("ui", "Search")}
        </button>
      </.form>

      <div class="hex-radio__list" aria-busy={to_string(@loading?)} data-testid="hex-radio-list">
        <p :if={@loading?} class="hex-radio__empty" data-testid="hex-radio-loading">
          {dgettext("ui", "Tuning in…")}
        </p>
        <p :if={!@loading? && @error} class="hex-radio__empty" data-testid="hex-radio-error">
          {@error}
        </p>
        <p
          :if={!@loading? && !@error && @stations == []}
          class="hex-radio__empty"
          data-testid="hex-radio-empty"
        >
          {empty_text(@section)}
        </p>
        <ol :if={!@loading? && !@error && @stations != []} class="hex-radio__stations-list">
          <li
            :for={{station, index} <- Enum.with_index(@stations, 1)}
            class="hex-radio__station"
            aria-current={to_string(station.id == @playing_id)}
            data-testid="hex-radio-station"
            data-station-id={station.id}
          >
            <button
              type="button"
              class="hex-radio__station-play"
              title={Enum.join(station.tags, ", ")}
              phx-click="radio_play"
              phx-value-id={station.id}
              phx-target={@target}
              data-testid={"hex-radio-station-#{station.id}"}
            >
              <span class="hex-radio__station-name">{index}. {station.name}</span>
              <span class="hex-radio__station-facts">{facts(station)}</span>
            </button>
            <button
              type="button"
              class="hex-radio__station-star"
              aria-pressed={to_string(station.id in @favorites)}
              aria-label={star_label(station.id in @favorites)}
              title={star_label(station.id in @favorites)}
              phx-click="radio_favorite"
              phx-value-id={station.id}
              phx-target={@target}
              data-testid={"hex-radio-star-#{station.id}"}
            >
              <Icons.icon_btn_star class="h-3 w-3" />
            </button>
          </li>
        </ol>

        <div
          :if={@menu == :genres}
          class="hex-radio__genres"
          role="menu"
          aria-label={dgettext("ui", "Genres")}
          data-testid="hex-radio-genres"
        >
          <button
            :for={{tag, label} <- @genres}
            type="button"
            role="menuitem"
            class="hex-radio__genre"
            aria-current={to_string(@section == tag)}
            phx-click="radio_section"
            phx-value-section={tag}
            phx-target={@target}
            data-testid={"hex-radio-section-#{tag}"}
          >
            {label}
          </button>
        </div>
      </div>

      <footer class="hex-radio__foot">
        <.foot_key
          label={dgettext("ui", "TOP")}
          title={dgettext("ui", "Most played")}
          pressed={@section == "top"}
          click="radio_section"
          value="top"
          target={@target}
          testid="hex-radio-section-top"
        />
        <.foot_key
          label={dgettext("ui", "GENRE")}
          title={dgettext("ui", "Genres")}
          pressed={@menu == :genres or @section in Enum.map(@genres, &elem(&1, 0))}
          click="radio_menu"
          value="genres"
          target={@target}
          testid="hex-radio-genre-menu"
          menu
        />
        <.foot_key
          label={dgettext("ui", "FAV")}
          title={dgettext("ui", "Favorites")}
          pressed={@section == "favorites"}
          click="radio_section"
          value="favorites"
          target={@target}
          testid="hex-radio-section-favorites"
        />
        <.foot_key
          label={dgettext("ui", "FIND")}
          title={dgettext("ui", "Search stations by name")}
          pressed={@menu == :search or @section == "search"}
          click="radio_menu"
          value="search"
          target={@target}
          testid="hex-radio-find"
        />
        <span class="hex-radio__count" data-testid="hex-radio-count">
          {length(@stations)}
        </span>
      </footer>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :title, :string, required: true
  attr :pressed, :boolean, required: true
  attr :click, :string, required: true
  attr :value, :string, required: true
  attr :target, :any, required: true
  attr :testid, :string, required: true
  attr :menu, :boolean, default: false

  defp foot_key(assigns) do
    ~H"""
    <button
      type="button"
      class="hex-radio__key hex-radio__key--foot"
      aria-pressed={to_string(@pressed)}
      aria-haspopup={@menu && "menu"}
      title={@title}
      phx-click={@click}
      phx-value-section={@click == "radio_section" && @value}
      phx-value-menu={@click == "radio_menu" && @value}
      phx-target={@target}
      data-testid={@testid}
    >
      {@label}<span :if={@menu} aria-hidden="true">▾</span>
    </button>
    """
  end

  defp facts(%Station{} = station) do
    [station.bitrate && "#{station.bitrate}k", station.country]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp section_title("top", _genres, _query), do: dgettext("ui", "Most played")
  defp section_title("favorites", _genres, _query), do: dgettext("ui", "Favorites")

  defp section_title("search", _genres, query),
    do: dgettext("ui", "Search: %{text}", text: query)

  defp section_title(tag, genres, _query) do
    case List.keyfind(genres, tag, 0) do
      {_tag, label} -> label
      nil -> dgettext("ui", "Stations")
    end
  end

  defp empty_text("favorites"),
    do: dgettext("ui", "No favorites yet. Press the star beside a station to keep it here.")

  defp empty_text("search"), do: dgettext("ui", "No station has that name.")
  defp empty_text(_section), do: dgettext("ui", "No station is on the air here right now.")

  @doc "The genres the window lists, as `{tag, label}`, in the catalog's order."
  @spec genres() :: [{String.t(), String.t()}]
  def genres do
    for tag <- RetroHexChat.Radio.genres(), do: {tag, genre_label(tag)}
  end

  defp genre_label("chiptune"), do: dgettext("ui", "Chiptune")
  defp genre_label("synthwave"), do: dgettext("ui", "Synthwave")
  defp genre_label("80s"), do: dgettext("ui", "80s")
  defp genre_label("90s"), do: dgettext("ui", "90s")
  defp genre_label("lofi"), do: dgettext("ui", "Lo-fi")
  defp genre_label("jazz"), do: dgettext("ui", "Jazz")
  defp genre_label("rock"), do: dgettext("ui", "Rock")
  defp genre_label("pop"), do: dgettext("ui", "Pop")
  defp genre_label("electronic"), do: dgettext("ui", "Electronic")
  defp genre_label("classical"), do: dgettext("ui", "Classical")
  defp genre_label("ambient"), do: dgettext("ui", "Ambient")
  defp genre_label("metal"), do: dgettext("ui", "Metal")
  defp genre_label("reggae"), do: dgettext("ui", "Reggae")
  defp genre_label("news"), do: dgettext("ui", "News")
  defp genre_label(tag), do: tag
end
