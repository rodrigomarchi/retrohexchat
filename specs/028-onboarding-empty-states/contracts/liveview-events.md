# LiveView Event Contracts: Onboarding & Empty States

**Feature**: 028-onboarding-empty-states
**Date**: 2026-02-14

## ConnectLive Events

### Client → Server (JS Hook → LiveView)

#### `check_onboarding`
Pushed by the onboarding JS hook on mount after checking localStorage.

```elixir
# Payload
%{"first_visit" => boolean()}

# Handler
def handle_event("check_onboarding", %{"first_visit" => true}, socket)
  # → assign(socket, wizard_mode: true, wizard_step: :welcome)

def handle_event("check_onboarding", %{"first_visit" => false}, socket)
  # → assign(socket, wizard_mode: false) — show normal connect form
```

### Server Events (phx-click / phx-submit)

#### `wizard_validate_nickname`
Validates nickname in real-time as user types (Step 1).

```elixir
# Trigger: phx-change on nickname input
# Payload
%{"nickname" => String.t()}

# Response: updates wizard_nickname, nickname_error assigns
```

#### `wizard_next`
Advances wizard to the next step.

```elixir
# Trigger: phx-click on "Próximo" / "Conectar" buttons
# Payload
%{"step" => "welcome" | "server"}

# Step "welcome" → validates nickname, moves to :server
# Step "server" → attempts connection, on success moves to :channels
# On error → sets wizard_connect_error, stays on current step
```

#### `wizard_back`
Returns wizard to the previous step.

```elixir
# Trigger: phx-click on "Voltar" button
# Payload
%{"step" => "server" | "channels"}

# Moves wizard_step back one step
```

#### `wizard_toggle_channel`
Toggles channel selection in Step 3.

```elixir
# Trigger: phx-click on channel checkbox
# Payload
%{"channel" => String.t()}

# Adds/removes channel from wizard_selected_channels
```

#### `wizard_update_custom_channel`
Updates custom channel input in Step 3.

```elixir
# Trigger: phx-change on custom channel text field
# Payload
%{"channel" => String.t()}

# Updates wizard_custom_channel assign
```

#### `wizard_complete`
Completes the wizard and navigates to chat.

```elixir
# Trigger: phx-click on "Entrar!" button
# Payload: none

# Joins selected channels + custom channel (if valid)
# Navigates to /chat?nickname=X&join=ch1,ch2&onboarded=true
```

#### `wizard_skip`
Skips Step 3 (channel selection) and navigates to chat.

```elixir
# Trigger: phx-click on "Pular" button
# Payload: none

# Navigates to /chat?nickname=X&onboarded=true (no channels)
```

#### `wizard_dismiss`
Dismisses the wizard entirely (X button or Esc).

```elixir
# Trigger: phx-click on X button / phx-window-keydown Escape
# Payload: none

# Sets onboarding_complete in localStorage (via JS push)
# Returns to normal connect form or navigates to /chat
```

## ChatLive Events

### Mount-Time Query Parameters

#### `onboarded`
Query parameter passed from ConnectLive after wizard completion.

```elixir
# URL: /chat?nickname=X&join=ch1,ch2&onboarded=true
# Read in: handle_params/3 or mount/3

# Sets show_onboarding_tip: true when "onboarded" == "true"
```

### Server Events

#### `dismiss_onboarding_tip`
Dismisses the post-wizard banner.

```elixir
# Trigger: phx-click on banner dismiss button
# Payload: none

# Sets show_onboarding_tip: false
```

#### `open_channel_list` (existing, reused)
Opens the channel list dialog. Used by the treebar empty state "Explorar canais" button.

```elixir
# Trigger: phx-click on "Explorar canais" button
# Payload: none

# Opens channel list dialog (existing behavior)
```

## JS Hook Contracts

### OnboardingHook

**Element**: Connected to ConnectLive root element.

```javascript
// Hook: OnboardingHook
const OnboardingHook = {
  mounted() {
    const STORAGE_KEY = "retro_hex_chat_onboarding_complete";
    const isComplete = localStorage.getItem(STORAGE_KEY) === "true";
    this.pushEvent("check_onboarding", { first_visit: !isComplete });

    // Listen for server command to mark onboarding complete
    this.handleEvent("mark_onboarding_complete", () => {
      localStorage.setItem(STORAGE_KEY, "true");
    });
  }
};
```

**Server → Client Events**:

| Event | Payload | Action |
|-------|---------|--------|
| `mark_onboarding_complete` | `{}` | Sets localStorage flag |
