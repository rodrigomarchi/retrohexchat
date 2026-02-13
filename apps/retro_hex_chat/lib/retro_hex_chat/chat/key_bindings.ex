defmodule RetroHexChat.Chat.KeyBindings do
  @moduledoc """
  Domain module for keyboard shortcut bindings.

  Provides default bindings, validation, lookup by key+modifiers,
  conflict detection, browser-reserved shortcut checking, and
  human-readable display formatting.
  """

  @type binding :: %{key: String.t(), modifiers: [atom()]}
  @type bindings_map :: %{atom() => binding()}

  @default_bindings %{
    toggle_search: %{key: "f", modifiers: [:ctrl, :shift]},
    toggle_address_book: %{key: "a", modifiers: [:ctrl, :shift]},
    toggle_ignore_dialog: %{key: "g", modifiers: [:ctrl, :shift]},
    toggle_highlight_dialog: %{key: "h", modifiers: [:ctrl, :shift]},
    toggle_url_catcher: %{key: "s", modifiers: [:ctrl, :shift]},
    toggle_log_viewer: %{key: "l", modifiers: [:ctrl, :shift]},
    toggle_perform_dialog: %{key: "e", modifiers: [:ctrl, :shift]},
    toggle_options_dialog: %{key: "o", modifiers: [:ctrl, :shift]},
    open_help: %{key: "/", modifiers: [:ctrl, :shift]}
  }

  @action_labels %{
    toggle_search: "Toggle Search",
    toggle_address_book: "Open Address Book",
    toggle_ignore_dialog: "Open Ignore List",
    toggle_highlight_dialog: "Open Highlight Dialog",
    toggle_url_catcher: "Open URL Catcher",
    toggle_log_viewer: "Open Log Viewer",
    toggle_perform_dialog: "Open Perform Dialog",
    toggle_options_dialog: "Open Options",
    open_help: "Open Help"
  }

  # Browser-reserved Ctrl+key combos
  @reserved_ctrl_combos ~w(w t n l h j d r o s p f g e a c v x z)

  # Browser-reserved Ctrl+Shift+key combos (DevTools, bookmarks, etc.)
  @reserved_ctrl_shift_combos ~w(i j c n t w k r p m)

  # Formatting shortcut keys (reserved so users can't rebind dialogs to them)
  @formatting_keys ~w(b y u d v x)

  # Function keys reserved by browsers
  @reserved_fkeys ~w(F1 F3 F5 F6 F11 F12)

  @reserved_combos for(key <- @reserved_ctrl_combos, do: %{key: key, modifiers: [:ctrl]}) ++
                     for(
                       key <- @reserved_ctrl_shift_combos,
                       do: %{key: key, modifiers: [:ctrl, :shift]}
                     ) ++
                     for(key <- @formatting_keys, do: %{key: key, modifiers: [:ctrl, :shift]}) ++
                     for(key <- @reserved_fkeys, do: %{key: key, modifiers: []}) ++
                     [
                       %{key: "Tab", modifiers: [:ctrl]},
                       %{key: "Tab", modifiers: [:ctrl, :shift]},
                       %{key: "Delete", modifiers: [:ctrl, :shift]}
                     ]

  @spec defaults() :: bindings_map()
  def defaults, do: @default_bindings

  @spec actions() :: [{atom(), String.t()}]
  def actions do
    @action_labels
    |> Enum.sort_by(fn {_action, label} -> label end)
  end

  @spec find_action(bindings_map(), map()) :: atom() | nil
  def find_action(bindings, %{"key" => key} = params) do
    modifiers = extract_modifiers(params)

    Enum.find_value(bindings, fn {action, binding} ->
      if matches_binding?(binding, key, modifiers), do: action
    end)
  end

  @spec conflict?(bindings_map(), atom(), binding()) :: atom() | nil
  def conflict?(bindings, action, %{key: key, modifiers: modifiers}) do
    target_mods = MapSet.new(modifiers)

    Enum.find_value(bindings, fn {existing_action, binding} ->
      if existing_action != action and
           normalize_key(binding.key) == normalize_key(key) and
           MapSet.equal?(MapSet.new(binding.modifiers), target_mods) do
        existing_action
      end
    end)
  end

  @spec reserved?(binding()) :: boolean()
  def reserved?(%{key: key, modifiers: modifiers}) do
    target_mods = MapSet.new(modifiers)

    # Block ALL Alt+single-letter combos (macOS produces special chars, Linux opens menus)
    alt_single_letter? =
      MapSet.equal?(target_mods, MapSet.new([:alt])) and
        byte_size(key) == 1 and key =~ ~r/^[a-zA-Z]$/

    alt_single_letter? or
      Enum.any?(@reserved_combos, fn combo ->
        normalize_key(combo.key) == normalize_key(key) and
          MapSet.equal?(MapSet.new(combo.modifiers), target_mods)
      end)
  end

  @spec to_display_string(binding()) :: String.t()
  def to_display_string(%{key: key, modifiers: modifiers}) do
    mod_parts =
      modifiers
      |> Enum.sort()
      |> Enum.map(&modifier_label/1)

    key_label = format_key(key)
    Enum.join(mod_parts ++ [key_label], "+")
  end

  @spec validate(bindings_map()) :: :ok | {:error, String.t()}
  def validate(bindings) do
    seen = %{}

    result =
      Enum.reduce_while(bindings, seen, fn {action, binding}, acc ->
        combo_key = combo_id(binding)

        case Map.get(acc, combo_key) do
          nil ->
            {:cont, Map.put(acc, combo_key, action)}

          existing_action ->
            {:halt, {:conflict, action, existing_action, to_display_string(binding)}}
        end
      end)

    case result do
      {:conflict, a1, a2, combo} ->
        {:error, "Conflict: #{a1} and #{a2} both bound to #{combo}"}

      _map ->
        :ok
    end
  end

  @spec action_label(atom()) :: String.t()
  def action_label(action) do
    Map.get(@action_labels, action, to_string(action))
  end

  @spec to_persistable(bindings_map()) :: map()
  def to_persistable(bindings) do
    Map.new(bindings, fn {action, binding} ->
      {Atom.to_string(action),
       %{
         "key" => binding.key,
         "modifiers" => Enum.map(binding.modifiers, &Atom.to_string/1)
       }}
    end)
  end

  @spec from_persisted(map()) :: bindings_map()
  def from_persisted(data) when data == %{}, do: defaults()

  def from_persisted(data) do
    Map.new(data, fn {action_str, binding_map} ->
      action = String.to_existing_atom(action_str)

      binding = %{
        key: binding_map["key"],
        modifiers: Enum.map(binding_map["modifiers"] || [], &String.to_existing_atom/1)
      }

      {action, binding}
    end)
  rescue
    ArgumentError -> defaults()
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp extract_modifiers(params) do
    []
    |> maybe_add_modifier(params["altKey"], :alt)
    |> maybe_add_modifier(params["ctrlKey"], :ctrl)
    |> maybe_add_modifier(params["shiftKey"], :shift)
    |> MapSet.new()
  end

  defp maybe_add_modifier(list, true, mod), do: [mod | list]
  defp maybe_add_modifier(list, _, _mod), do: list

  defp matches_binding?(binding, key, modifiers) do
    normalize_key(binding.key) == normalize_key(key) and
      MapSet.equal?(MapSet.new(binding.modifiers), modifiers)
  end

  defp normalize_key(key) when byte_size(key) == 1, do: String.downcase(key)
  defp normalize_key(key), do: key

  defp modifier_label(:alt), do: "Alt"
  defp modifier_label(:ctrl), do: "Ctrl"
  defp modifier_label(:shift), do: "Shift"

  defp format_key(key) when byte_size(key) == 1, do: String.upcase(key)
  defp format_key(key), do: key

  defp combo_id(%{key: key, modifiers: modifiers}) do
    mods = modifiers |> Enum.sort() |> Enum.join(",")
    "#{normalize_key(key)}:#{mods}"
  end
end
