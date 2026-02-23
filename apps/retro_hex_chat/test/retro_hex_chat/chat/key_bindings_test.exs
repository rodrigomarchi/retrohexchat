defmodule RetroHexChat.Chat.KeyBindingsTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.KeyBindings

  describe "defaults/0" do
    @tag :unit
    test "returns 20 default bindings" do
      bindings = KeyBindings.defaults()
      assert map_size(bindings) == 20
    end

    @tag :unit
    test "includes all original actions" do
      bindings = KeyBindings.defaults()

      assert Map.has_key?(bindings, :toggle_search)
      assert Map.has_key?(bindings, :toggle_address_book)
      assert Map.has_key?(bindings, :toggle_ignore_dialog)
      assert Map.has_key?(bindings, :toggle_highlight_dialog)
      assert Map.has_key?(bindings, :toggle_url_catcher)
      assert Map.has_key?(bindings, :toggle_perform_dialog)
      assert Map.has_key?(bindings, :toggle_options_dialog)
      assert Map.has_key?(bindings, :open_help)
    end

    @tag :unit
    test "includes all new actions" do
      bindings = KeyBindings.defaults()

      assert Map.has_key?(bindings, :toggle_cheatsheet)
      assert Map.has_key?(bindings, :window_next)
      assert Map.has_key?(bindings, :window_prev)

      for n <- 1..9 do
        assert Map.has_key?(bindings, :"window_#{n}")
      end
    end

    @tag :unit
    test "search is Ctrl+Shift+F" do
      bindings = KeyBindings.defaults()
      assert bindings.toggle_search == %{key: "f", modifiers: [:ctrl, :shift]}
    end

    @tag :unit
    test "open_help has no keyboard binding (menu only)" do
      bindings = KeyBindings.defaults()
      assert bindings.open_help == nil
    end

    @tag :unit
    test "cheatsheet is Ctrl+Shift+/ (replaces open_help)" do
      bindings = KeyBindings.defaults()
      assert bindings.toggle_cheatsheet == %{key: "/", modifiers: [:ctrl, :shift]}
    end

    @tag :unit
    test "window_next is Ctrl+Shift+]" do
      bindings = KeyBindings.defaults()
      assert bindings.window_next == %{key: "]", modifiers: [:ctrl, :shift]}
    end

    @tag :unit
    test "window_prev is Ctrl+Shift+[" do
      bindings = KeyBindings.defaults()
      assert bindings.window_prev == %{key: "[", modifiers: [:ctrl, :shift]}
    end

    @tag :unit
    test "window_1..9 are Ctrl+Shift+1..9" do
      bindings = KeyBindings.defaults()

      for n <- 1..9 do
        action = :"window_#{n}"
        assert bindings[action] == %{key: "#{n}", modifiers: [:ctrl, :shift]}
      end
    end
  end

  describe "actions/0" do
    @tag :unit
    test "returns sorted list of action-label pairs for all 20 actions" do
      actions = KeyBindings.actions()
      assert is_list(actions)
      assert length(actions) == 20

      labels = Enum.map(actions, fn {_action, label} -> label end)
      assert labels == Enum.sort(labels)
    end
  end

  describe "registry/1" do
    @tag :unit
    test "returns entries with all required fields" do
      entries = KeyBindings.registry(KeyBindings.defaults())

      for entry <- entries do
        assert Map.has_key?(entry, :action)
        assert Map.has_key?(entry, :category)
        assert Map.has_key?(entry, :label)
        assert Map.has_key?(entry, :description)
        assert Map.has_key?(entry, :binding)
        assert Map.has_key?(entry, :default_binding)
        assert Map.has_key?(entry, :customizable)
      end
    end

    @tag :unit
    test "returns 20 entries for default bindings" do
      entries = KeyBindings.registry(KeyBindings.defaults())
      assert length(entries) == 20
    end

    @tag :unit
    test "entries are sorted by category then label" do
      entries = KeyBindings.registry(KeyBindings.defaults())
      categories = Enum.map(entries, & &1.category)

      # Navigation should come before Chat, Chat before Formatting, Formatting before System
      nav_idx = Enum.find_index(categories, &(&1 == :navigation))
      sys_idx = Enum.find_index(categories, &(&1 == :system))
      assert nav_idx < sys_idx
    end

    @tag :unit
    test "reflects custom bindings" do
      custom =
        Map.put(KeyBindings.defaults(), :toggle_search, %{key: "q", modifiers: [:ctrl, :shift]})

      entries = KeyBindings.registry(custom)
      search_entry = Enum.find(entries, &(&1.action == :toggle_search))

      assert search_entry.binding == %{key: "q", modifiers: [:ctrl, :shift]}
      assert search_entry.default_binding == %{key: "f", modifiers: [:ctrl, :shift]}
    end

    @tag :unit
    test "open_help has nil binding and nil default_binding" do
      entries = KeyBindings.registry(KeyBindings.defaults())
      help_entry = Enum.find(entries, &(&1.action == :open_help))

      assert help_entry.binding == nil
      assert help_entry.default_binding == nil
    end

    @tag :unit
    test "window_1..9 are not customizable" do
      entries = KeyBindings.registry(KeyBindings.defaults())

      for n <- 1..9 do
        entry = Enum.find(entries, &(&1.action == :"window_#{n}"))
        refute entry.customizable
      end
    end

    @tag :unit
    test "toggle_cheatsheet is customizable" do
      entries = KeyBindings.registry(KeyBindings.defaults())
      entry = Enum.find(entries, &(&1.action == :toggle_cheatsheet))
      assert entry.customizable
    end
  end

  describe "categories/1" do
    @tag :unit
    test "returns 4 categories" do
      cats = KeyBindings.categories(KeyBindings.defaults())
      cat_names = Enum.map(cats, fn {cat, _} -> cat end)

      assert :navigation in cat_names
      assert :system in cat_names
    end

    @tag :unit
    test "categories are in display order" do
      cats = KeyBindings.categories(KeyBindings.defaults())
      cat_names = Enum.map(cats, fn {cat, _} -> cat end)

      # Navigation first, system last
      nav_idx = Enum.find_index(cat_names, &(&1 == :navigation))
      sys_idx = Enum.find_index(cat_names, &(&1 == :system))
      assert nav_idx < sys_idx
    end

    @tag :unit
    test "navigation category includes window actions" do
      cats = KeyBindings.categories(KeyBindings.defaults())
      {_, nav_entries} = Enum.find(cats, fn {cat, _} -> cat == :navigation end)
      nav_actions = Enum.map(nav_entries, & &1.action)

      assert :window_next in nav_actions
      assert :window_prev in nav_actions
      assert :window_1 in nav_actions
    end

    @tag :unit
    test "system category includes cheatsheet and search" do
      cats = KeyBindings.categories(KeyBindings.defaults())
      {_, sys_entries} = Enum.find(cats, fn {cat, _} -> cat == :system end)
      sys_actions = Enum.map(sys_entries, & &1.action)

      assert :toggle_cheatsheet in sys_actions
      assert :toggle_search in sys_actions
    end
  end

  describe "find_action/2" do
    @tag :unit
    test "finds action by matching key and modifiers" do
      bindings = KeyBindings.defaults()

      params = %{"key" => "a", "altKey" => false, "ctrlKey" => true, "shiftKey" => true}
      assert KeyBindings.find_action(bindings, params) == :toggle_address_book
    end

    @tag :unit
    test "finds Ctrl+Shift+/ action for cheatsheet" do
      bindings = KeyBindings.defaults()

      params = %{"key" => "/", "altKey" => false, "ctrlKey" => true, "shiftKey" => true}
      assert KeyBindings.find_action(bindings, params) == :toggle_cheatsheet
    end

    @tag :unit
    test "returns nil for unbound combination" do
      bindings = KeyBindings.defaults()

      params = %{"key" => "z", "altKey" => false, "ctrlKey" => true, "shiftKey" => true}
      assert KeyBindings.find_action(bindings, params) == nil
    end

    @tag :unit
    test "is case-insensitive for single letter keys" do
      bindings = KeyBindings.defaults()

      params = %{"key" => "A", "altKey" => false, "ctrlKey" => true, "shiftKey" => true}
      assert KeyBindings.find_action(bindings, params) == :toggle_address_book
    end

    @tag :unit
    test "does not match when extra modifiers are present" do
      bindings = KeyBindings.defaults()

      # Alt+Ctrl+Shift+A should NOT match Ctrl+Shift+A
      params = %{"key" => "a", "altKey" => true, "ctrlKey" => true, "shiftKey" => true}
      assert KeyBindings.find_action(bindings, params) == nil
    end
  end

  describe "conflict?/3" do
    @tag :unit
    test "detects conflict with another action" do
      bindings = KeyBindings.defaults()
      # Try to bind toggle_search to Ctrl+Shift+A (already toggle_address_book)
      new_binding = %{key: "a", modifiers: [:ctrl, :shift]}
      assert KeyBindings.conflict?(bindings, :toggle_search, new_binding) == :toggle_address_book
    end

    @tag :unit
    test "returns nil when binding the same action (no conflict with self)" do
      bindings = KeyBindings.defaults()
      same_binding = %{key: "a", modifiers: [:ctrl, :shift]}
      assert KeyBindings.conflict?(bindings, :toggle_address_book, same_binding) == nil
    end

    @tag :unit
    test "returns nil for a free combination" do
      bindings = KeyBindings.defaults()
      new_binding = %{key: "z", modifiers: [:ctrl, :shift]}
      assert KeyBindings.conflict?(bindings, :toggle_search, new_binding) == nil
    end
  end

  describe "reserved?/1" do
    @tag :unit
    test "Ctrl+W is reserved" do
      assert KeyBindings.reserved?(%{key: "w", modifiers: [:ctrl]})
    end

    @tag :unit
    test "Ctrl+T is reserved" do
      assert KeyBindings.reserved?(%{key: "t", modifiers: [:ctrl]})
    end

    @tag :unit
    test "Ctrl+N is reserved" do
      assert KeyBindings.reserved?(%{key: "n", modifiers: [:ctrl]})
    end

    @tag :unit
    test "Ctrl+Tab is reserved" do
      assert KeyBindings.reserved?(%{key: "Tab", modifiers: [:ctrl]})
    end

    @tag :unit
    test "Ctrl+H is reserved (browser history)" do
      assert KeyBindings.reserved?(%{key: "h", modifiers: [:ctrl]})
    end

    @tag :unit
    test "Ctrl+D is reserved (bookmark)" do
      assert KeyBindings.reserved?(%{key: "d", modifiers: [:ctrl]})
    end

    @tag :unit
    test "Alt+B IS reserved (all Alt+letter combos are reserved)" do
      assert KeyBindings.reserved?(%{key: "b", modifiers: [:alt]})
    end

    @tag :unit
    test "F1 with no modifiers IS reserved" do
      assert KeyBindings.reserved?(%{key: "F1", modifiers: []})
    end

    @tag :unit
    test "Ctrl+Shift+I is reserved (DevTools)" do
      assert KeyBindings.reserved?(%{key: "i", modifiers: [:ctrl, :shift]})
    end

    @tag :unit
    test "formatting key Ctrl+Shift+B is reserved" do
      assert KeyBindings.reserved?(%{key: "b", modifiers: [:ctrl, :shift]})
    end

    @tag :unit
    test "Ctrl+Shift+Q is NOT reserved" do
      refute KeyBindings.reserved?(%{key: "q", modifiers: [:ctrl, :shift]})
    end
  end

  describe "to_display_string/1" do
    @tag :unit
    test "formats Ctrl+Shift+A" do
      assert KeyBindings.to_display_string(%{key: "a", modifiers: [:ctrl, :shift]}) ==
               "Ctrl+Shift+A"
    end

    @tag :unit
    test "formats Ctrl+Shift+F" do
      assert KeyBindings.to_display_string(%{key: "f", modifiers: [:ctrl, :shift]}) ==
               "Ctrl+Shift+F"
    end

    @tag :unit
    test "formats Ctrl+Shift+Tab" do
      assert KeyBindings.to_display_string(%{key: "Tab", modifiers: [:ctrl, :shift]}) ==
               "Ctrl+Shift+Tab"
    end

    @tag :unit
    test "formats Ctrl+Shift+/" do
      assert KeyBindings.to_display_string(%{key: "/", modifiers: [:ctrl, :shift]}) ==
               "Ctrl+Shift+/"
    end
  end

  describe "validate/1" do
    @tag :unit
    test "passes for default bindings" do
      assert :ok == KeyBindings.validate(KeyBindings.defaults())
    end

    @tag :unit
    test "fails for conflicting bindings" do
      bindings =
        KeyBindings.defaults()
        |> Map.put(:toggle_search, %{key: "a", modifiers: [:ctrl, :shift]})

      assert {:error, message} = KeyBindings.validate(bindings)
      assert message =~ "Conflict"
    end
  end

  describe "action_label/1" do
    @tag :unit
    test "returns human-readable label for known action" do
      assert KeyBindings.action_label(:toggle_search) == "Toggle Search"
    end

    @tag :unit
    test "returns stringified atom for unknown action" do
      assert KeyBindings.action_label(:unknown_action) == "unknown_action"
    end
  end

  describe "to_persistable/1 and from_persisted/1" do
    @tag :unit
    test "round-trip preserves bindings" do
      original = KeyBindings.defaults()
      persisted = KeyBindings.to_persistable(original)
      restored = KeyBindings.from_persisted(persisted)

      assert restored == original
    end

    @tag :unit
    test "to_persistable excludes nil bindings" do
      persisted = KeyBindings.to_persistable(KeyBindings.defaults())
      refute Map.has_key?(persisted, "open_help")
    end

    @tag :unit
    test "from_persisted with empty map returns defaults" do
      assert KeyBindings.from_persisted(%{}) == KeyBindings.defaults()
    end

    @tag :unit
    test "from_persisted merges new actions into old persisted data" do
      # Simulate old persisted data that doesn't have new actions
      old_data = %{
        "toggle_search" => %{"key" => "f", "modifiers" => ["ctrl", "shift"]}
      }

      restored = KeyBindings.from_persisted(old_data)
      # Should have custom search binding
      assert restored.toggle_search == %{key: "f", modifiers: [:ctrl, :shift]}
      # Should also have new actions from defaults
      assert Map.has_key?(restored, :toggle_cheatsheet)
      assert Map.has_key?(restored, :window_next)
    end
  end
end
