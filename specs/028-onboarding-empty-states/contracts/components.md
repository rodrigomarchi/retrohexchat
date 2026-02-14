# Component Contracts: Onboarding & Empty States

**Feature**: 028-onboarding-empty-states
**Date**: 2026-02-14

## New Components

### WizardDialog

**Module**: `RetroHexChatWeb.Components.WizardDialog`
**File**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/wizard_dialog.ex`

```elixir
attr :visible, :boolean, default: false
attr :step, :atom, values: [:welcome, :server, :channels]
attr :nickname, :string, default: ""
attr :nickname_error, :string, default: nil
attr :server, :string, default: "irc.retro.chat"
attr :port, :integer, default: 6697
attr :ssl, :boolean, default: true
attr :connecting, :boolean, default: false
attr :connect_error, :string, default: nil
attr :channels, :list, default: []           # [{name, user_count}]
attr :selected_channels, :list, default: []
attr :custom_channel, :string, default: ""

@spec wizard_dialog(map()) :: Phoenix.LiveView.Rendered.t()
def wizard_dialog(assigns)
```

**Renders**:
- `.dialog-overlay` with `.wizard-dialog` window
- Title bar: "Assistente de Configuração — RetroHexChat"
- Step indicator (Step 1 of 3, Step 2 of 3, Step 3 of 3)
- Step-specific content (conditionally rendered)
- Button bar: Back (steps 2-3) / Next or Connect (steps 1-2) / Cancel / Entrar! or Pular (step 3)

### OnboardingTipBanner

**Module**: `RetroHexChatWeb.Components.OnboardingTipBanner`
**File**: Inline in ChatLive template (small enough — ~10 lines of HEEx)

```elixir
# Rendered conditionally in chat_live.html.heex:
<div :if={@show_onboarding_tip} class="onboarding-tip-banner" data-testid="onboarding-tip">
  <span>Dica: digite / para ver comandos disponíveis. Use ↑↓ para navegar o histórico.</span>
  <button phx-click="dismiss_onboarding_tip" aria-label="Fechar dica">✕</button>
</div>
```

## Modified Components (Empty States)

### Treebar (existing)

**Module**: `RetroHexChatWeb.Components.Treebar`
**File**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/treebar.ex`

**Addition**: Empty state block when `@channels == []` and `@pm_conversations == []`.

```heex
<div :if={@channels == [] and @pm_conversations == []} class="empty-state treebar-empty-state">
  <p>Nenhum canal — /join #canal para começar</p>
  <button type="button" class="empty-state-action" phx-click="open_channel_list">
    Explorar canais
  </button>
</div>
```

### Nicklist (existing)

**Module**: `RetroHexChatWeb.Components.Nicklist`
**File**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/nicklist.ex`

**Addition**: Empty state when `@users == []`.

```heex
<div :if={@users == []} class="empty-state nicklist-empty-state">
  <p>Ninguém aqui — Você é o(a) primeiro(a)!</p>
</div>
```

### Chat Area (in ChatLive template)

**File**: `apps/retro_hex_chat_web/live/chat_live.html.heex`

**Addition**: Empty state inside message container when stream is empty.

```heex
<div :if={stream_empty?(@messages)} class="empty-state channel-empty-state">
  <p>Bem-vindo ao #{@active_channel}!</p>
  <p>Este é o início do canal. Diga oi!</p>
  <p class="empty-state-tip">Dica: /topic para ver o tópico</p>
</div>
```

### URL Catcher Window (existing)

**Module**: `RetroHexChatWeb.Components.UrlCatcherWindow`
**File**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/url_catcher_window.ex`

**Addition**: Empty state when URL list is empty.

```heex
<div :if={@urls == []} class="empty-state url-catcher-empty-state">
  <p>Nenhuma URL capturada.</p>
  <p>URLs mencionadas no chat aparecerão aqui.</p>
</div>
```

## CSS Classes

### New File: `empty-state.css`

```css
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 16px;
  color: var(--color-muted);
  font-size: var(--text-sm);
  text-align: center;
  user-select: none;
  flex: 1;
}

.empty-state-action { /* Button inside empty state */ }
.empty-state-tip { font-style: italic; }
```

### New File: `wizard-dialog.css`

```css
.wizard-dialog { /* Window sizing and layout */ }
.wizard-step-indicator { /* Step 1 of 3 progress */ }
.wizard-content { /* Step content area */ }
.wizard-logo { /* ASCII art logo */ }
.wizard-tip { /* Tip text styling */ }
.wizard-channel-list { /* Channel checkboxes */ }
.wizard-button-bar { /* Navigation buttons */ }
```
