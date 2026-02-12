# Domain Module Contracts: Scripting & Aliases

**Feature**: 018-scripting-aliases
**Date**: 2026-02-12

## 1. RetroHexChat.Chat.AliasExpander

Pure variable expansion engine shared by all subsystems.

```
AliasExpander.expand(template, args, context) :: String.t()
  - template: String.t() — expansion string with $variables
  - args: [String.t()] — positional arguments ($1, $2, ...)
  - context: %{nick: String.t(), chan: String.t() | nil}
  - Returns: expanded string with all variables substituted

AliasExpander.validate_expansion(expansion) :: :ok | {:error, String.t()}
  - Checks for command chaining characters (|, &&, ;, \n)
  - Returns :ok or error with human-readable message

AliasExpander.contains_chaining?(expansion) :: boolean()
  - Returns true if expansion contains |, &&, ;, or newline
```

## 2. RetroHexChat.Chat.AliasList

Domain module for alias CRUD. Follows PerformList/Favorites pattern.

```
AliasList.new() :: map()
  - Returns: %{entries: []}

AliasList.add_entry(list, name, expansion) :: {:ok, map()} | {:error, atom()}
  - Errors: :list_full, :invalid_name, :duplicate_name, :expansion_too_long, :command_chaining
  - On success: returns updated list with new AliasEntry appended

AliasList.remove_entry(list, name) :: {:ok, map()} | {:error, :not_found}
  - Removes alias by name (case-insensitive match)

AliasList.update_entry(list, name, new_expansion) :: {:ok, map()} | {:error, atom()}
  - Errors: :not_found, :expansion_too_long, :command_chaining

AliasList.find_entry(list, name) :: AliasEntry.t() | nil
  - Case-insensitive name lookup

AliasList.entries(list) :: [AliasEntry.t()]
  - Returns all entries ordered by position

AliasList.shadows_builtin?(name) :: boolean()
  - Checks if name matches a key in Commands.Registry

AliasList.save(owner, list) :: :ok | {:error, term()}
  - Persists to DB (delete all + insert all in transaction)

AliasList.load(owner) :: {:ok, map()} | {:error, :not_found}
  - Loads from DB, returns domain map
```

## 3. RetroHexChat.Chat.AliasEntry

Value object for a single alias.

```
AliasEntry.new(opts) :: AliasEntry.t()
  - opts: [name: String.t(), expansion: String.t(), position: integer()]

Fields:
  - name: String.t()       # without "/" prefix, e.g. "hi"
  - expansion: String.t()  # e.g. "/me says hello!"
  - position: integer()    # ordering in editor list
```

## 4. RetroHexChat.Chat.CustomMenus

Domain module for custom popup menu items.

```
CustomMenus.new() :: map()
  - Returns: %{entries: []}

CustomMenus.add_entry(menus, menu_type, label, command) :: {:ok, map()} | {:error, atom()}
  - menu_type: :nicklist | :channel
  - Errors: :menu_full, :invalid_label, :duplicate_label, :command_too_long
  - Max 10 entries per menu_type

CustomMenus.remove_entry(menus, menu_type, label) :: {:ok, map()} | {:error, :not_found}

CustomMenus.update_entry(menus, menu_type, old_label, new_label, new_command) :: {:ok, map()} | {:error, atom()}

CustomMenus.entries_for(menus, menu_type) :: [CustomMenuItem.t()]
  - Returns entries filtered by menu_type, ordered by position

CustomMenus.save(owner, menus) :: :ok | {:error, term()}
CustomMenus.load(owner) :: {:ok, map()} | {:error, :not_found}
```

## 5. RetroHexChat.Chat.CustomMenuItem

Value object for a single custom menu item.

```
CustomMenuItem.new(opts) :: CustomMenuItem.t()
  - opts: [menu_type: atom(), label: String.t(), command: String.t(), position: integer()]

Fields:
  - menu_type: :nicklist | :channel
  - label: String.t()
  - command: String.t()
  - position: integer()
```

## 6. RetroHexChat.Chat.AutoRespondRules

Domain module for auto-respond rules.

```
AutoRespondRules.new() :: map()
  - Returns: %{entries: []}

AutoRespondRules.add_entry(rules, trigger_event, channel_filter, command) :: {:ok, map()} | {:error, atom()}
  - trigger_event: :on_join | :on_part | :on_nick_change
  - channel_filter: String.t() | nil
  - Errors: :list_full, :invalid_trigger, :command_too_long

AutoRespondRules.remove_entry(rules, position) :: {:ok, map()} | {:error, :not_found}

AutoRespondRules.update_entry(rules, position, attrs) :: {:ok, map()} | {:error, atom()}

AutoRespondRules.toggle_entry(rules, position) :: {:ok, map()} | {:error, :not_found}
  - Toggles enabled flag

AutoRespondRules.matching_rules(rules, event_type, channel) :: [AutoRespondRule.t()]
  - Returns enabled rules matching the event type and channel filter

AutoRespondRules.entries(rules) :: [AutoRespondRule.t()]

AutoRespondRules.save(owner, rules) :: :ok | {:error, term()}
AutoRespondRules.load(owner) :: {:ok, map()} | {:error, :not_found}
```

## 7. RetroHexChat.Chat.AutoRespondRule

Value object for a single auto-respond rule.

```
AutoRespondRule.new(opts) :: AutoRespondRule.t()

Fields:
  - id: integer()                    # local identifier for rate limit tracking
  - trigger_event: atom()            # :on_join | :on_part | :on_nick_change
  - channel_filter: String.t() | nil # nil = all channels
  - command: String.t()              # expansion string
  - enabled: boolean()               # default true
  - position: integer()              # ordering in editor
```

## 8. RetroHexChat.Chat.TimerManager

Pure functions for timer validation and state management. Timer refs are managed by the LiveView process.

```
TimerManager.validate_create(timers_map, name, type, interval, command) :: :ok | {:error, String.t()}
  - Validates name format, interval bounds, timer count limit
  - type: :once | :repeat
  - Returns human-readable error strings (displayed directly to user)

TimerManager.clamp_interval(type, interval) :: {integer(), String.t() | nil}
  - Clamps interval to valid range
  - Returns {clamped_interval, notice_message_or_nil}

TimerManager.format_timer_list(timers_map) :: String.t()
  - Formats active timers for /timer list display

TimerManager.parse_timer_args(args) :: {:ok, parsed} | {:error, String.t()}
  - Parses /timer command arguments into structured data
  - parsed: %{name, type, interval, command} | :list | {:stop, name}
```

## 9. Command Handlers

### RetroHexChat.Commands.Handlers.Alias

Implements `Handler` behaviour for `/alias` command.

```
execute([], context) → {:ok, :ui_action, :open_alias_dialog, %{}}
execute(["add", name | expansion_parts], context) → {:ok, :ui_action, :alias_added, %{...}} | {:error, msg}
execute(["remove", name], context) → {:ok, :ui_action, :alias_removed, %{...}} | {:error, msg}
execute(["list"], context) → {:ok, :system, %{content: formatted_list}}
validate(raw_args) → :ok
help() → %{name, syntax, description, examples}
```

### RetroHexChat.Commands.Handlers.Timer

Implements `Handler` behaviour for `/timer` command.

```
execute([], context) → {:ok, :system, %{content: usage_help}}
execute(["list"], context) → {:ok, :ui_action, :timer_list, %{}}
execute(["stop", name], context) → {:ok, :ui_action, :timer_stop, %{name: name}}
execute([name | rest], context) → {:ok, :ui_action, :timer_create, %{name, type, interval, command}}
validate(raw_args) → :ok
help() → %{name, syntax, description, examples}
```

### RetroHexChat.Commands.Handlers.Popups

Implements `Handler` behaviour for `/popups` command.

```
execute([], context) → {:ok, :ui_action, :open_custom_menus_dialog, %{}}
validate(raw_args) → :ok
help() → %{name, syntax, description, examples}
```

### RetroHexChat.Commands.Handlers.AutoRespond

Implements `Handler` behaviour for `/autorespond` command.

```
execute([], context) → {:ok, :ui_action, :open_autorespond_dialog, %{}}
execute(["add" | rest], context) → {:ok, :ui_action, :autorespond_added, %{...}} | {:error, msg}
execute(["remove", position], context) → {:ok, :ui_action, :autorespond_removed, %{...}} | {:error, msg}
execute(["list"], context) → {:ok, :system, %{content: formatted_list}}
validate(raw_args) → :ok
help() → %{name, syntax, description, examples}
```

## 10. Ecto Schemas

### RetroHexChat.Chat.Schemas.AliasEntry
```
Table: aliases
Fields: id, owner_nickname, name, expansion, position, inserted_at, updated_at
Changeset: validates required [:owner_nickname, :name, :expansion, :position]
           validates length :name max 30, :expansion max 500
```

### RetroHexChat.Chat.Schemas.CustomMenuItem
```
Table: custom_menu_items
Fields: id, owner_nickname, menu_type, label, command, position, inserted_at, updated_at
Changeset: validates required [:owner_nickname, :menu_type, :label, :command, :position]
           validates inclusion :menu_type in ["nicklist", "channel"]
           validates length :label max 50, :command max 500
```

### RetroHexChat.Chat.Schemas.AutoRespondRule
```
Table: autorespond_rules
Fields: id, owner_nickname, trigger_event, channel_filter, command, enabled, position, inserted_at, updated_at
Changeset: validates required [:owner_nickname, :trigger_event, :command, :position]
           validates inclusion :trigger_event in ["on_join", "on_part", "on_nick_change"]
           validates length :channel_filter max 50, :command max 500
```

## 11. LiveView Components

### RetroHexChatWeb.Components.AliasDialog
```
Props: visible, aliases (list), selected_alias, editing_mode, draft_name, draft_expansion, warning_message, error_message
Events: open_alias_dialog, close_alias_dialog, alias_select, alias_add, alias_edit, alias_save, alias_delete
```

### RetroHexChatWeb.Components.CustomMenusDialog
```
Props: visible, custom_menus (map), active_tab (:nicklist/:channel), selected_item, editing_mode, draft_label, draft_command, error_message
Events: open_custom_menus_dialog, close_custom_menus_dialog, custom_menu_tab, custom_menu_select, custom_menu_add, custom_menu_edit, custom_menu_save, custom_menu_delete
```

### RetroHexChatWeb.Components.AutoRespondDialog
```
Props: visible, autorespond_rules (list), selected_rule, editing_mode, draft_trigger, draft_channel, draft_command, error_message
Events: open_autorespond_dialog, close_autorespond_dialog, autorespond_select, autorespond_add, autorespond_edit, autorespond_save, autorespond_delete, autorespond_toggle
```
