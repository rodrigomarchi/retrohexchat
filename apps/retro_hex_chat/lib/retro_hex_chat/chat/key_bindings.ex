defmodule RetroHexChat.Chat.KeyBindings do
  @moduledoc """
  Domain module for keyboard shortcut bindings.

  Provides default bindings, validation, lookup by key+modifiers,
  conflict detection, browser-reserved shortcut checking,
  human-readable display formatting, and a categorized registry
  for the shortcut cheatsheet dialog.
  """

  @type binding :: %{key: String.t(), modifiers: [atom()]}
  @type bindings_map :: %{atom() => binding() | nil}
  @type category :: :navigation | :chat | :formatting | :system
  @type registry_entry :: %{
          action: atom(),
          category: category(),
          label: String.t(),
          description: String.t(),
          binding: binding() | nil,
          default_binding: binding() | nil,
          customizable: boolean()
        }

  @default_bindings %{
    toggle_search: %{key: "f", modifiers: [:ctrl, :shift]},
    toggle_address_book: %{key: "a", modifiers: [:ctrl, :shift]},
    toggle_ignore_dialog: %{key: "g", modifiers: [:ctrl, :shift]},
    toggle_highlight_dialog: %{key: "h", modifiers: [:ctrl, :shift]},
    toggle_url_catcher: %{key: "s", modifiers: [:ctrl, :shift]},
    toggle_log_viewer: %{key: "l", modifiers: [:ctrl, :shift]},
    toggle_perform_dialog: %{key: "e", modifiers: [:ctrl, :shift]},
    toggle_options_dialog: %{key: "o", modifiers: [:ctrl, :shift]},
    open_help: nil,
    toggle_cheatsheet: %{key: "/", modifiers: [:ctrl, :shift]},
    window_next: %{key: "]", modifiers: [:ctrl, :shift]},
    window_prev: %{key: "[", modifiers: [:ctrl, :shift]},
    window_1: %{key: "1", modifiers: [:ctrl, :shift]},
    window_2: %{key: "2", modifiers: [:ctrl, :shift]},
    window_3: %{key: "3", modifiers: [:ctrl, :shift]},
    window_4: %{key: "4", modifiers: [:ctrl, :shift]},
    window_5: %{key: "5", modifiers: [:ctrl, :shift]},
    window_6: %{key: "6", modifiers: [:ctrl, :shift]},
    window_7: %{key: "7", modifiers: [:ctrl, :shift]},
    window_8: %{key: "8", modifiers: [:ctrl, :shift]},
    window_9: %{key: "9", modifiers: [:ctrl, :shift]}
  }

  @action_metadata %{
    # System category
    toggle_search: %{
      category: :system,
      label: "Toggle Search",
      description: "Open/close search bar",
      customizable: true
    },
    toggle_address_book: %{
      category: :system,
      label: "Open Address Book",
      description: "Open/close the address book",
      customizable: true
    },
    toggle_ignore_dialog: %{
      category: :system,
      label: "Open Ignore List",
      description: "Open/close the ignore list",
      customizable: true
    },
    toggle_highlight_dialog: %{
      category: :system,
      label: "Open Highlight Dialog",
      description: "Open/close highlight word settings",
      customizable: true
    },
    toggle_url_catcher: %{
      category: :system,
      label: "Open URL Catcher",
      description: "Open/close the URL catcher",
      customizable: true
    },
    toggle_log_viewer: %{
      category: :system,
      label: "Open Log Viewer",
      description: "Open/close the log viewer",
      customizable: true
    },
    toggle_perform_dialog: %{
      category: :system,
      label: "Open Perform Dialog",
      description: "Open/close auto-perform settings",
      customizable: true
    },
    toggle_options_dialog: %{
      category: :system,
      label: "Open Options",
      description: "Open/close the options dialog",
      customizable: true
    },
    open_help: %{
      category: :system,
      label: "Open Help",
      description: "Open the help dialog (menu only)",
      customizable: true
    },
    toggle_cheatsheet: %{
      category: :system,
      label: "Shortcut Cheatsheet",
      description: "Open/close the keyboard shortcut cheatsheet",
      customizable: true
    },
    # Navigation category
    window_next: %{
      category: :navigation,
      label: "Next Window",
      description: "Switch to the next channel or PM",
      customizable: true
    },
    window_prev: %{
      category: :navigation,
      label: "Previous Window",
      description: "Switch to the previous channel or PM",
      customizable: true
    },
    window_1: %{
      category: :navigation,
      label: "Window 1",
      description: "Switch to window 1",
      customizable: false
    },
    window_2: %{
      category: :navigation,
      label: "Window 2",
      description: "Switch to window 2",
      customizable: false
    },
    window_3: %{
      category: :navigation,
      label: "Window 3",
      description: "Switch to window 3",
      customizable: false
    },
    window_4: %{
      category: :navigation,
      label: "Window 4",
      description: "Switch to window 4",
      customizable: false
    },
    window_5: %{
      category: :navigation,
      label: "Window 5",
      description: "Switch to window 5",
      customizable: false
    },
    window_6: %{
      category: :navigation,
      label: "Window 6",
      description: "Switch to window 6",
      customizable: false
    },
    window_7: %{
      category: :navigation,
      label: "Window 7",
      description: "Switch to window 7",
      customizable: false
    },
    window_8: %{
      category: :navigation,
      label: "Window 8",
      description: "Switch to window 8",
      customizable: false
    },
    window_9: %{
      category: :navigation,
      label: "Window 9",
      description: "Switch to window 9",
      customizable: false
    }
  }

  # Keep @action_labels for backward compatibility with existing code
  @action_labels Map.new(@action_metadata, fn {action, meta} -> {action, meta.label} end)

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

  @doc """
  Returns the full shortcut registry with metadata for each action.

  Accepts a bindings map (defaults or user-customized) and returns a list
  of registry entries with action, category, label, description, current
  binding, default binding, and customizable flag.
  """
  @spec registry(bindings_map()) :: [registry_entry()]
  def registry(bindings) do
    @action_metadata
    |> Enum.map(fn {action, meta} ->
      %{
        action: action,
        category: meta.category,
        label: meta.label,
        description: meta.description,
        binding: Map.get(bindings, action),
        default_binding: Map.get(@default_bindings, action),
        customizable: meta.customizable
      }
    end)
    |> Enum.sort_by(fn entry -> {category_order(entry.category), entry.label} end)
  end

  @doc """
  Returns registry entries grouped by category in display order.
  """
  @spec categories(bindings_map()) :: [{category(), [registry_entry()]}]
  def categories(bindings) do
    bindings
    |> registry()
    |> Enum.group_by(& &1.category)
    |> Enum.sort_by(fn {cat, _} -> category_order(cat) end)
  end

  @spec category_label(category()) :: String.t()
  def category_label(:navigation), do: "Navigation"
  def category_label(:chat), do: "Chat"
  def category_label(:formatting), do: "Formatting"
  def category_label(:system), do: "System"

  defp category_order(:navigation), do: 0
  defp category_order(:chat), do: 1
  defp category_order(:formatting), do: 2
  defp category_order(:system), do: 3

  @spec find_action(bindings_map(), map()) :: atom() | nil
  def find_action(bindings, %{"key" => key} = params) do
    modifiers = extract_modifiers(params)

    Enum.find_value(bindings, fn
      {_action, nil} -> nil
      {action, binding} -> if matches_binding?(binding, key, modifiers), do: action
    end)
  end

  @spec conflict?(bindings_map(), atom(), binding()) :: atom() | nil
  def conflict?(bindings, action, %{key: key, modifiers: modifiers}) do
    target_mods = MapSet.new(modifiers)

    Enum.find_value(bindings, fn
      {_existing_action, nil} ->
        nil

      {existing_action, binding} ->
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
      Enum.reduce_while(bindings, seen, fn
        {_action, nil}, acc ->
          {:cont, acc}

        {action, binding}, acc ->
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
    bindings
    |> Enum.reject(fn {_action, binding} -> is_nil(binding) end)
    |> Map.new(fn {action, binding} ->
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
    persisted =
      Map.new(data, fn {action_str, binding_map} ->
        action = String.to_existing_atom(action_str)

        binding = %{
          key: binding_map["key"],
          modifiers: Enum.map(binding_map["modifiers"] || [], &String.to_existing_atom/1)
        }

        {action, binding}
      end)

    # Merge with defaults so new actions are always present
    Map.merge(defaults(), persisted)
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
