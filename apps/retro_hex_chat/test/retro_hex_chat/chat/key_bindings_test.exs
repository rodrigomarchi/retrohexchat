defmodule RetroHexChat.Chat.KeyBindingsTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Chat.KeyBindings

  describe "defaults/0" do
    @tag :unit
    test "returns 9 default bindings" do
      bindings = KeyBindings.defaults()
      assert map_size(bindings) == 9
    end

    @tag :unit
    test "includes all expected actions" do
      bindings = KeyBindings.defaults()

      assert Map.has_key?(bindings, :toggle_search)
      assert Map.has_key?(bindings, :toggle_address_book)
      assert Map.has_key?(bindings, :toggle_ignore_dialog)
      assert Map.has_key?(bindings, :toggle_highlight_dialog)
      assert Map.has_key?(bindings, :toggle_url_catcher)
      assert Map.has_key?(bindings, :toggle_log_viewer)
      assert Map.has_key?(bindings, :toggle_perform_dialog)
      assert Map.has_key?(bindings, :toggle_options_dialog)
      assert Map.has_key?(bindings, :open_help)
    end

    @tag :unit
    test "search is Ctrl+Shift+F" do
      bindings = KeyBindings.defaults()
      assert bindings.toggle_search == %{key: "f", modifiers: [:ctrl, :shift]}
    end

    @tag :unit
    test "help is Ctrl+Shift+/" do
      bindings = KeyBindings.defaults()
      assert bindings.open_help == %{key: "/", modifiers: [:ctrl, :shift]}
    end
  end

  describe "actions/0" do
    @tag :unit
    test "returns sorted list of action-label pairs" do
      actions = KeyBindings.actions()
      assert is_list(actions)
      assert length(actions) == 9

      labels = Enum.map(actions, fn {_action, label} -> label end)
      assert labels == Enum.sort(labels)
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
    test "finds Ctrl+Shift+/ action for help" do
      bindings = KeyBindings.defaults()

      params = %{"key" => "/", "altKey" => false, "ctrlKey" => true, "shiftKey" => true}
      assert KeyBindings.find_action(bindings, params) == :open_help
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
    test "from_persisted with empty map returns defaults" do
      assert KeyBindings.from_persisted(%{}) == KeyBindings.defaults()
    end
  end
end
