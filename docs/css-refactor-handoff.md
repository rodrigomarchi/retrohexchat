# CSS Refactoring Handoff — RetroHexChat

**Branch**: `refac-css`
**Date**: 2026-02-14
**Status**: ~80% complete — 4 tarefas restantes
**Plan file**: `/Users/rodrigo/.claude/plans/groovy-snuggling-hennessy.md`

---

## 1. Objetivo do Trabalho

Centralizar **todos** os design tokens e estilos em CSS, removendo inline styles dos templates Elixir/HEEx. O projeto começou com **~715 inline styles** em 39 componentes LiveView. A meta é reduzir para apenas estilos dinâmicos (com interpolação `#{...}`), atingindo ~94% de redução.

**Regra absoluta do usuário**: "nao pode haver excessao" — estamos criando um padrão, zero tolerância para inline styles estáticos.

---

## 2. O Que Foi Feito

### Arquivos CSS Criados (4 novos)

| Arquivo | Linhas | Descrição |
|---------|--------|-----------|
| `tokens.css` | 67 | Design tokens `:root` — cores, espaçamento, tipografia, z-index |
| `utilities.css` | 114 | Classes utilitárias prefixo `u-` (flex, gap, text, padding, margin, etc.) |
| `tables.css` | 72 | Padrões de tabela (`.table-standard`, `.table-row--selected`, etc.) |
| `forms.css` | 146 | Padrões de formulário (`.form-row`, `.form-label`, `.toolbar-row`, etc.) |

### Arquivos CSS Expandidos

| Arquivo | Linhas | O que foi adicionado |
|---------|--------|---------------------|
| `app.css` | 24 | Imports dos 4 novos arquivos |
| `dialogs.css` | 657 | Overlay genérico, tamanhos de janela (--sm/md/lg/xl + específicos), tabs, seções |
| `components.css` | 571 | Autocomplete dropdown/list, search bar floating, menu helpers, tab reset |

### Scripts de Auditoria

| Arquivo | Descrição |
|---------|-----------|
| `scripts/lint_inline_styles.sh` | Escaneia `.ex` para `style=`, classifica dinâmico vs estático, verifica allowlist |
| `scripts/inline_style_allowlist.txt` | 5 entradas para `nicklist.ex` (nick_style/2 é dinâmico mas lint não detecta `#{`) |

### Componentes Migrados (~30 arquivos)

Todos os componentes em `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/` foram migrados:

- **Tier 1** (simples): paste_confirm_dialog, invite_dialog, favorite_dialog, ctcp_settings_dialog, sound_settings_dialog, cheatsheet_dialog, flood_protection_dialog, highlight_dialog, ignore_list_dialog
- **Tier 2** (médios): alias_dialog, auto_respond_dialog, custom_menus_dialog, organize_favorites_dialog, perform_dialog, log_viewer_dialog, notify_list_window, url_catcher_window, search_bar, autocomplete_dropdown, context_menu, chat_context_menu, treebar_context_menu
- **Tier 3** (maiores): address_book_dialog, channel_central_dialog, channel_list_live
- **Batch A** (restantes): dialog, help_dialog, menu_bar, scroll_loader, status_bar, history_search, formatting_toolbar, options_dialog

### Padrão Principal de Migração

**Antes** (inline style + helper Elixir):
```elixir
defp row_style(name, selected) do
  base = "padding: 4px 8px; cursor: pointer;"
  if name == selected, do: base <> "background: navy; color: white;", else: base
end

# No template:
<tr style={row_style(entry.name, @selected)}>
```

**Depois** (CSS class):
```elixir
# No template:
<tr class={["table-row--selectable", entry.name == @selected && "table-row--selected"]}>
```

---

## 3. Estado Atual — Lint Report

```
Total inline styles found: 30
Dynamic (allowed):         21
Allowlisted:               5
Static (violations):       4
```

### As 4 Violações Restantes

Todas são **falsos positivos** — chamam helpers Elixir que retornam valores dinâmicos, mas o lint não consegue detectar isso porque a interpolação `#{` está dentro da função, não no template:

1. **`highlight_dialog.ex:78`** — `style={color_swatch_style(entry.bg_color)}`
   Helper `color_swatch_style/1` retorna background-color dinâmica baseada em índice de cor. É genuinamente dinâmico.

2. **`log_viewer_dialog.ex:342`** — `style={@color}`
   Assign `@color` vem do parser de logs, cor dinâmica por nick.

3. **`log_viewer_dialog.ex:351`** — `style={@color}`
   Mesmo caso acima, outro tipo de mensagem.

4. **`notify_list_window.ex:104`** — `style={notify_nick_style(@nick_color_fn, entry.tracked_nickname)}`
   Helper `notify_nick_style/2` é idêntico ao `nick_style/2` já allowlisted no nicklist.

**Ação necessária**: Adicionar estas 4 entradas ao `scripts/inline_style_allowlist.txt` para zerar as violações. Todas são dinâmicas.

### 6 Style Helpers Flagged

Todos são dinâmicos e legítimos:
- `color_swatch_style/1` (highlight_dialog.ex:237,241) — cor de swatch por índice
- `nick_style/2` (nicklist.ex:77,78) — cor de nick via função assign ✓ já allowlisted
- `notify_nick_style/2` (notify_list_window.ex:248,249) — mesmo padrão do nick_style

---

## 4. Tarefas Pendentes

### Tarefa A: Allowlist das 4 Violações Restantes

Adicionar ao `scripts/inline_style_allowlist.txt`:

```
# Highlight dialog: color_swatch_style/1 returns dynamic background-color by index
retro_hex_chat_web/components/highlight_dialog.ex:78

# Log viewer: @color assign is dynamic per-nick color from log parser
retro_hex_chat_web/components/log_viewer_dialog.ex:342
retro_hex_chat_web/components/log_viewer_dialog.ex:351

# Notify list: notify_nick_style/2 returns dynamic color from nick_color_fn assign
retro_hex_chat_web/components/notify_list_window.ex:104
```

Depois rodar `bash scripts/lint_inline_styles.sh` e confirmar zero violações.

### Tarefa B: Refatorar CSS Existente para Usar Tokens

Os 6 arquivos CSS que existiam antes do refactor ainda usam valores hardcoded. Precisam ser atualizados para usar os tokens de `tokens.css`. **3 arquivos novos (tables, forms, utilities) já usam tokens.**

**Mapeamento de substituições por arquivo:**

#### `layout.css` (~8 substituições)
- `silver` → `var(--color-surface)`
- `navy` → `var(--color-selection-bg)` (4 ocorrências)
- `#808080` → `var(--color-border)` ou `var(--color-gray-500)`
- `#ffffff` → `var(--color-white)`, `#000000` → `var(--color-black)`
- `#dfdfdf` → `var(--color-gray-200)`

#### `chat.css` (~15 substituições com token existente)
- `#808080` → `var(--color-muted)` ou `var(--color-border)` (~8 ocorrências)
- `#cc0000` → `var(--color-error)` (2 ocorrências)
- `#cc8800` → `var(--color-warning-alt)`
- `#000080` → `var(--color-selection-bg)` (2 ocorrências)
- `rgba(0, 0, 0, 0.3)` → `var(--color-overlay-bg)`
- `#000000` → `var(--color-black)`
- **SKIP**: #996600, #cc6699, #ffffd0, #0066cc, #0044aa, #551a8b, #006600, #404040 — cores custom sem token

#### `components.css` (~12 substituições com token existente)
- `navy` → `var(--color-selection-bg)` (3 ocorrências)
- `#808080` → `var(--color-muted)` (~6 ocorrências)
- `#cc0000` → `var(--color-error)`
- `#009900` → `var(--color-success)`
- `#0000cc` → `var(--color-link)`
- `#c0c0c0` → `var(--color-surface)`
- `#000000` → `var(--color-black)`
- **SKIP**: #990099, #ff4444, #ffff00, #ff9632, #ff6400, #a0a0a0 — cores custom sem token

#### `dialogs.css` (~18 substituições com token existente)
- `navy` → `var(--color-selection-bg)` (4 ocorrências)
- `#808080` → `var(--color-border)` (~7 ocorrências)
- `rgba(0, 0, 0, 0.5)` → `var(--color-overlay-bg-dark)`
- `#f0f0f0` → `var(--color-gray-100)`
- `#606060` → `var(--color-gray-600)`
- `#cc0000` → `var(--color-error)`
- `#0000cc` → `var(--color-link)`
- `white`/`black` → `var(--color-white)`/`var(--color-black)` (4+2 ocorrências)
- **SKIP**: #e0e0e0, rgba(0,0,0,0.25) — sem token correspondente

#### `formatting.css` (~6 substituições com token existente)
- `#808080` → `var(--color-border)` (2 ocorrências)
- `#dfdfdf` → `var(--color-gray-200)` (2 ocorrências)
- `#d4d0c8` → `var(--color-gray-300)`
- `silver` → `var(--color-surface)`
- `#000000` → `var(--color-black)`
- **SKIP**: #222, #e8e4dc, #d2d2d2 — sem token correspondente
- **NÃO MEXER**: Linhas 95-128 são a paleta mIRC (16 cores padrão IRC), devem ficar hardcoded

#### `status-messages.css` (~3 substituições)
- `#009300` → `var(--color-success)`
- `#808080` → `var(--color-muted)`
- `#cc0000` → `var(--color-error)`
- **SKIP**: #009393 — cor custom de channel event sem token

**Decisão sobre cores sem token**: Cores como #996600, #cc6699, #ffffd0, #990099 são específicas de domínio (IRC message types, nick mode colors, highlight backgrounds). Duas opções:
1. Criar tokens adicionais para elas (ex: `--color-notice`, `--color-service`, `--color-nick-owner`)
2. Deixar hardcoded nos arquivos CSS (não são inline — já estão centralizadas)

**Recomendação**: Opção 1 é melhor para consistência total, mas opção 2 é aceitável porque os valores já estão centralizados em CSS, não espalhados nos templates.

### Tarefa C: Adicionar Target no Makefile

Adicionar ao `Makefile`:

```makefile
lint.css: ## Audit inline styles in LiveView (zero static styles allowed)
	@bash scripts/lint_inline_styles.sh
```

### Tarefa D: Validação Final (CI completo)

Rodar todos os 8 checks do CI:

```bash
# 1. Compilação (primeiro, os outros dependem)
mix compile --warnings-as-errors

# 2-7. Em paralelo:
mix format --check-formatted
mix credo --strict
make lint.js
npm test --prefix apps/retro_hex_chat_web/assets
mix test --include e2e
mix dialyzer

# 8. Lint CSS
make lint.css  # deve dar zero violações
```

---

## 5. Convenções Estabelecidas

### Nomenclatura CSS

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Componente | Nome semântico | `.dialog-overlay`, `.table-standard`, `.form-row` |
| Modificador | `--sufixo` | `--sm`, `--selected`, `--active`, `--w80` |
| Utilitário | `u-` prefixo | `.u-flex`, `.u-text-sm`, `.u-gap-4` |
| Token | `--categoria-*` | `--color-*`, `--text-*`, `--z-*`, `--font-*` |

### O Que Fica Inline (e só isso)

Apenas valores **dinâmicos calculados em runtime Elixir**:
- Coordenadas de posição: `style={"left: #{@x}px; top: #{@y}px"}` (context menus)
- Cores de nick: `style={"color: #{color_fn.(nickname)}"}` (via assign function)
- Swatches de cor: `style={"background: #{hex}"}` (paleta dinâmica)
- Assigns dinâmicos: `style={@color}` (valor vindo do server)

### Padrão LiveView para Classes Condicionais

```elixir
# Simples: sempre aplica
class="table-row--selectable"

# Condicional: aplica se condição for true
class={["table-row--selectable", @condition && "table-row--selected"]}

# Múltiplas condicionais:
class={[
  "base-class",
  @active && "base-class--active",
  @disabled && "base-class--disabled"
]}
```

---

## 6. Estrutura de Arquivos CSS

```
assets/css/
├── app.css              # Entry point (imports) — 24 linhas
├── tokens.css           # NOVO — Design tokens (:root) — 67 linhas
├── utilities.css        # NOVO — Classes u-* — 114 linhas
├── layout.css           # MDI, treebar, compact mode — 196 linhas
├── chat.css             # Mensagens, input, links — 338 linhas
├── components.css       # Nicklist, tabs, menus, etc. — 571 linhas
├── dialogs.css          # Overlays, janelas, dialogs — 657 linhas
├── tables.css           # NOVO — Tabelas — 72 linhas
├── forms.css            # NOVO — Formulários — 146 linhas
├── formatting.css       # IRC colors, toolbar — 128 linhas
└── status-messages.css  # Status messages — 30 linhas
                         # Total: 2,343 linhas
```

---

## 7. Ferramentas de Verificação

### Lint Script

```bash
# Rodar auditoria de inline styles
bash scripts/lint_inline_styles.sh

# Output esperado quando tudo estiver ok:
# Total inline styles found: 30
# Dynamic (allowed):         21
# Allowlisted:               9  (5 existentes + 4 novas)
# Static (violations):       0
```

### Allowlist

Arquivo: `scripts/inline_style_allowlist.txt`
Formato: `relative/path/from/web_lib:line_number`
Usa-se para estilos que são dinâmicos mas o lint não consegue detectar (helper functions sem `#{` visível no template).

---

## 8. Resumo de Progresso

| Métrica | Antes | Agora | Meta |
|---------|-------|-------|------|
| Inline styles totais | ~715 | 30 | 30 (apenas dinâmicos) |
| Inline styles estáticos | ~694 | 4* | 0 |
| Arquivos CSS | 7 (1,564 linhas) | 11 (2,343 linhas) | 11 |
| Componentes migrados | 0 | ~30 | ~30 ✓ |
| Design tokens | 0 | 67 linhas | ✓ |
| Utility classes | 0 | 114 linhas | ✓ |

*Os 4 "estáticos" são falsos positivos — helpers dinâmicos que precisam de allowlist.

---

## 9. Checklist para Conclusão

- [ ] Adicionar 4 entradas ao allowlist → zero violações
- [ ] Refatorar `layout.css` para tokens (~8 substituições)
- [ ] Refatorar `chat.css` para tokens (~15 substituições)
- [ ] Refatorar `components.css` para tokens (~12 substituições)
- [ ] Refatorar `dialogs.css` para tokens (~18 substituições)
- [ ] Refatorar `formatting.css` para tokens (~6 substituições)
- [ ] Refatorar `status-messages.css` para tokens (~3 substituições)
- [ ] Decidir: criar tokens extras para cores custom ou manter hardcoded em CSS
- [ ] Adicionar `lint.css` target ao Makefile
- [ ] Rodar CI completo (8 checks) — tudo verde
- [ ] Verificação visual manual (comparar antes/depois)
