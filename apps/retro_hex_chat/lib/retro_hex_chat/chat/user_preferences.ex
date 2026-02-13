defmodule RetroHexChat.Chat.UserPreferences do
  @moduledoc """
  Domain module for centralized user preferences.

  Manages in-memory CRUD for 6 preference categories (display, fonts,
  colors, connect, messages, key_bindings) and persistence for registered users.
  """

  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChat.Chat.Schemas.UserPreference
  alias RetroHexChat.Repo

  @valid_display_keys ~w(show_toolbar show_treebar show_switchbar show_statusbar compact_mode line_shading)a

  @valid_font_areas ~w(chat_messages input_box nicklist treebar)a

  @valid_font_families [
    ~s(Fixedsys, "Courier New", monospace),
    "Consolas, monospace",
    ~s("Lucida Console", monospace),
    ~s("Courier New", monospace),
    "monospace"
  ]

  @valid_color_slots ~w(chat_background default_text own_messages system_messages timestamps error_messages)a

  @valid_routing_types ~w(whois_routing notice_routing pm_routing)a

  @default_nick_palette [
    "#ffffff",
    "#000000",
    "#00007f",
    "#009300",
    "#ff0000",
    "#7f0000",
    "#9c009c",
    "#fc7f00",
    "#ffff00",
    "#00fc00",
    "#009393",
    "#00ffff",
    "#0000fc",
    "#ff00ff",
    "#7f7f7f",
    "#d2d2d2"
  ]

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{
      display: default_display(),
      fonts: default_fonts(),
      colors: default_colors(),
      connect: default_connect(),
      messages: default_messages(),
      key_bindings: KeyBindings.defaults()
    }
  end

  @spec get_display(map()) :: map()
  def get_display(%{display: display}), do: display

  @spec get_fonts(map()) :: map()
  def get_fonts(%{fonts: fonts}), do: fonts

  @spec get_colors(map()) :: map()
  def get_colors(%{colors: colors}), do: colors

  @spec get_connect(map()) :: map()
  def get_connect(%{connect: connect}), do: connect

  @spec get_messages(map()) :: map()
  def get_messages(%{messages: messages}), do: messages

  @spec get_key_bindings(map()) :: map()
  def get_key_bindings(%{key_bindings: bindings}), do: bindings

  @spec set_display(map(), atom(), boolean()) :: map()
  def set_display(prefs, key, value) when key in @valid_display_keys and is_boolean(value) do
    put_in(prefs, [:display, key], value)
  end

  @spec set_font(map(), atom(), map()) :: map()
  def set_font(prefs, area, %{family: family, size: size} = font_setting)
      when area in @valid_font_areas and family in @valid_font_families and
             is_integer(size) and size >= 8 and size <= 24 do
    put_in(prefs, [:fonts, area], font_setting)
  end

  @spec set_color(map(), atom(), String.t()) :: map()
  def set_color(prefs, slot, hex_color)
      when slot in @valid_color_slots and is_binary(hex_color) do
    put_in(prefs, [:colors, slot], hex_color)
  end

  @spec set_nick_palette_color(map(), non_neg_integer(), String.t()) :: map()
  def set_nick_palette_color(prefs, index, hex_color)
      when is_integer(index) and index >= 0 and index <= 15 and is_binary(hex_color) do
    palette = prefs.colors.nick_palette
    new_palette = List.replace_at(palette, index, hex_color)
    put_in(prefs, [:colors, :nick_palette], new_palette)
  end

  @spec set_connect(map(), atom(), term()) :: map()
  def set_connect(prefs, :auto_reconnect_enabled, value) when is_boolean(value) do
    put_in(prefs, [:connect, :auto_reconnect_enabled], value)
  end

  def set_connect(prefs, :retry_interval, value)
      when is_integer(value) and value >= 1 and value <= 60 do
    put_in(prefs, [:connect, :retry_interval], value)
  end

  def set_connect(prefs, :max_retries, value)
      when is_integer(value) and value >= 1 and value <= 100 do
    put_in(prefs, [:connect, :max_retries], value)
  end

  def set_connect(prefs, :connection_timeout, value)
      when is_integer(value) and value >= 5 and value <= 120 do
    put_in(prefs, [:connect, :connection_timeout], value)
  end

  @spec set_routing(map(), atom(), atom()) :: map()
  def set_routing(prefs, :whois_routing, value) when value in [:active, :dialog] do
    put_in(prefs, [:messages, :whois_routing], value)
  end

  def set_routing(prefs, :notice_routing, value) when value in [:active, :status, :sender] do
    put_in(prefs, [:messages, :notice_routing], value)
  end

  def set_routing(prefs, :pm_routing, value) when value in [:new_tab, :active] do
    put_in(prefs, [:messages, :pm_routing], value)
  end

  @spec set_key_binding(map(), atom(), KeyBindings.binding() | nil) :: map()
  def set_key_binding(prefs, action, binding) do
    put_in(prefs, [:key_bindings, action], binding)
  end

  @spec set_key_bindings(map(), KeyBindings.bindings_map()) :: map()
  def set_key_bindings(prefs, bindings) do
    %{prefs | key_bindings: bindings}
  end

  # ---------------------------------------------------------------------------
  # CSS Custom Properties
  # ---------------------------------------------------------------------------

  @spec to_css_styles(map()) :: %{String.t() => String.t()}
  def to_css_styles(prefs) do
    font_styles(prefs.fonts)
    |> Map.merge(color_styles(prefs.colors))
  end

  # ---------------------------------------------------------------------------
  # Validation Helpers
  # ---------------------------------------------------------------------------

  @spec valid_font_families() :: [String.t()]
  def valid_font_families, do: @valid_font_families

  @spec valid_routing_types() :: [atom()]
  def valid_routing_types, do: @valid_routing_types

  @spec default_nick_palette() :: [String.t()]
  def default_nick_palette, do: @default_nick_palette

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, prefs) do
    attrs = %{
      owner_nickname: owner,
      display_settings: stringify_map(prefs.display),
      font_settings: stringify_fonts(prefs.fonts),
      color_settings: stringify_colors(prefs.colors),
      connect_settings: stringify_map(prefs.connect),
      message_settings: stringify_map(prefs.messages),
      key_bindings: KeyBindings.to_persistable(prefs.key_bindings)
    }

    case Repo.get(UserPreference, owner) do
      nil ->
        %UserPreference{}
        |> UserPreference.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> UserPreference.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    case Repo.get(UserPreference, owner) do
      nil ->
        {:error, :not_found}

      db_entry ->
        {:ok, from_persisted(db_entry)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Defaults
  # ---------------------------------------------------------------------------

  defp default_display do
    %{
      show_toolbar: true,
      show_treebar: true,
      show_switchbar: true,
      show_statusbar: true,
      compact_mode: false,
      line_shading: false
    }
  end

  defp default_fonts do
    %{
      chat_messages: %{family: ~s(Fixedsys, "Courier New", monospace), size: 13},
      input_box: %{family: ~s(Fixedsys, "Courier New", monospace), size: 13},
      nicklist: %{family: ~s(Fixedsys, "Courier New", monospace), size: 12},
      treebar: %{family: ~s("MS Sans Serif", Tahoma, sans-serif), size: 12}
    }
  end

  defp default_colors do
    %{
      chat_background: "#ffffff",
      default_text: "#000000",
      own_messages: "#000000",
      system_messages: "#808080",
      timestamps: "#808080",
      error_messages: "#cc0000",
      nick_palette: @default_nick_palette
    }
  end

  defp default_connect do
    %{
      auto_reconnect_enabled: true,
      retry_interval: 5,
      max_retries: 10,
      connection_timeout: 30
    }
  end

  defp default_messages do
    %{
      whois_routing: :active,
      notice_routing: :active,
      pm_routing: :new_tab
    }
  end

  # ---------------------------------------------------------------------------
  # Private: CSS styles
  # ---------------------------------------------------------------------------

  defp font_styles(fonts) do
    %{
      "--chat-font-family" => fonts.chat_messages.family,
      "--chat-font-size" => "#{fonts.chat_messages.size}px",
      "--input-font-family" => fonts.input_box.family,
      "--input-font-size" => "#{fonts.input_box.size}px",
      "--nicklist-font-family" => fonts.nicklist.family,
      "--nicklist-font-size" => "#{fonts.nicklist.size}px",
      "--treebar-font-family" => fonts.treebar.family,
      "--treebar-font-size" => "#{fonts.treebar.size}px"
    }
  end

  defp color_styles(colors) do
    base = %{
      "--chat-bg-color" => colors.chat_background,
      "--default-text-color" => colors.default_text,
      "--own-messages-color" => colors.own_messages,
      "--system-messages-color" => colors.system_messages,
      "--timestamps-color" => colors.timestamps,
      "--error-messages-color" => colors.error_messages
    }

    palette_styles =
      colors.nick_palette
      |> Enum.with_index()
      |> Map.new(fn {color, idx} -> {"--irc-color-#{idx}", color} end)

    Map.merge(base, palette_styles)
  end

  # ---------------------------------------------------------------------------
  # Private: Serialization
  # ---------------------------------------------------------------------------

  defp stringify_map(map) do
    Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end)
  end

  defp stringify_fonts(fonts) do
    Map.new(fonts, fn {area, setting} ->
      {Atom.to_string(area), %{"family" => setting.family, "size" => setting.size}}
    end)
  end

  defp stringify_colors(colors) do
    Map.new(colors, fn
      {:nick_palette, palette} -> {"nick_palette", palette}
      {k, v} -> {Atom.to_string(k), v}
    end)
  end

  defp from_persisted(db_entry) do
    %{
      display: atomize_display(db_entry.display_settings),
      fonts: atomize_fonts(db_entry.font_settings),
      colors: atomize_colors(db_entry.color_settings),
      connect: atomize_connect(db_entry.connect_settings),
      messages: atomize_messages(db_entry.message_settings),
      key_bindings: KeyBindings.from_persisted(db_entry.key_bindings)
    }
  end

  defp atomize_display(data) when data == %{}, do: default_display()

  defp atomize_display(data) do
    defaults = default_display()

    Map.new(defaults, fn {key, default_val} ->
      str_key = Atom.to_string(key)
      {key, Map.get(data, str_key, default_val)}
    end)
  end

  defp atomize_fonts(data) when data == %{}, do: default_fonts()

  defp atomize_fonts(data) do
    defaults = default_fonts()

    Map.new(defaults, fn {area, default_setting} ->
      str_area = Atom.to_string(area)

      case Map.get(data, str_area) do
        %{"family" => family, "size" => size} ->
          {area, %{family: family, size: size}}

        _ ->
          {area, default_setting}
      end
    end)
  end

  defp atomize_colors(data) when data == %{}, do: default_colors()

  defp atomize_colors(data) do
    defaults = default_colors()

    base =
      Map.new(defaults, fn
        {:nick_palette, default_palette} ->
          {:nick_palette, Map.get(data, "nick_palette", default_palette)}

        {key, default_val} ->
          str_key = Atom.to_string(key)
          {key, Map.get(data, str_key, default_val)}
      end)

    base
  end

  defp atomize_connect(data) when data == %{}, do: default_connect()

  defp atomize_connect(data) do
    defaults = default_connect()

    Map.new(defaults, fn {key, default_val} ->
      str_key = Atom.to_string(key)
      {key, Map.get(data, str_key, default_val)}
    end)
  end

  defp atomize_messages(data) when data == %{}, do: default_messages()

  defp atomize_messages(data) do
    defaults = default_messages()

    Map.new(defaults, fn {key, default_val} ->
      str_key = Atom.to_string(key)
      raw = Map.get(data, str_key)

      value =
        if is_binary(raw) do
          String.to_existing_atom(raw)
        else
          raw || default_val
        end

      {key, value}
    end)
  end
end
