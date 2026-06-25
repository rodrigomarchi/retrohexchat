# Fase 2 — Replicar o padrão nos demais diálogos

Com o molde validado na Fase 1, replicamos a extração para os diálogos
restantes. Cada um é uma sub-tarefa independente e isolável (um PR/commit por
diálogo é recomendado), o que mantém os passos pequenos e reversíveis.

## Ordem sugerida (maior ganho primeiro)

| Ordem | Diálogo | Assigns a remover do raiz | Módulo de eventos atual | Apresentação atual |
|------:|---------|---------------------------:|--------------------------|--------------------|
| 1 | **Channel Central** | ~17 (`channel_central_*`) | `live/chat_live/channel_central_events.ex` (840 ln) | `components/ui/dialogs/channel_central_dialog.ex` |
| 2 | **Account** | ~10 (`account_*`) | `live/chat_live/account_events.ex` (396 ln) | `components/ui/dialogs/` |
| 3 | **Address Book** | contatos + abas (`address_book_*`, `contacts_*`) | `live/chat_live/address_book_events.ex` (445 ln) | `components/ui/dialogs/address_book_page.*` |
| 4 | **Timers** | ~7 (`timers_dialog_*`) | `live/chat_live/timer_events.ex` (223 ln) | `components/ui/dialogs/` |
| 5 | **Alias** | ~6 (`alias_dialog_*`) | `live/chat_live/alias_events.ex` (192 ln) | `components/ui/dialogs/alias_dialog_page.*` |
| 6 | **Custom Menus** | ~6 (`custom_menus_dialog_*`) | `live/chat_live/custom_menus_events.ex` (235 ln) | `components/ui/dialogs/custom_menus_dialog_page.*` |
| 7 | **Autorespond** | ~7 (`autorespond_dialog_*`) | `live/chat_live/autorespond_events.ex` (185 ln) | `components/ui/dialogs/auto_respond_dialog_page.*` |
| 8 | **URL Catcher** | ~5 (`url_catcher_*`) | `live/chat_live/url_catcher_events.ex` | `components/ui/dialogs/url_catcher_page.*` |
| 9 | **Highlight / Notify / Perform / Autojoin** | ~4–6 cada | respectivos `*_events.ex` | `components/ui/dialogs/` |

> Estimativa acumulada de assigns removidos do socket raiz nesta fase:
> **~70–90**, somados aos ~32 da Fase 1.

## Receita por diálogo (idêntica à Fase 1)

Para cada diálogo, repetir o procedimento de
[03-fase-1-prova-de-conceito-admin-console.md](./03-fase-1-prova-de-conceito-admin-console.md):

1. **Criar** `live/chat_live/components/<nome>_component.ex` com
   `use ..., :live_component`, `update/2` (com `assign_new` para defaults de
   UI), `handle_event/3` (UI com `phx-target={@myself}`; domínio chamando
   contexto) e `render/1` reaproveitando o function component de apresentação.
2. **Adaptar** o function component de apresentação para aceitar `myself` e
   rotear eventos via `phx-target`.
3. **Trocar** a chamada no template para
   `<.live_component :if={@show_<nome>} module={...} id="<nome>" ... />`.
4. **Remover** os assigns `<nome>_*` de `assign_defaults/1`
   (`live/app/chat_live.ex:622`), mantendo só o `show_<nome>`.
5. **Encolher** o `*_events.ex` correspondente: manter só abrir/fechar; remover
   o hook da lista `@event_hook_fns` (`live/app/chat_live.ex:516`) e de
   `attach_all_hooks/1` (`live/app/chat_live.ex:569`) quando o módulo virar
   trivial.
6. **Empurrar** lógica de domínio remanescente para o contexto adequado
   (`RetroHexChat.Channels`, `RetroHexChat.Accounts`, etc.).
7. **Testes** + `make ci` verde.

## Casos especiais a observar

- **Channel Central** é o mais pesado depois do Admin Console (~17 assigns +
  sub-abas `access_tab`, `cs_*`, `ban_*`). É grande, mas o ganho é alto e o
  diálogo é bem delimitado. Atenção às múltiplas sub-abas: cada uma vira estado
  interno do componente (`access_tab`, `ban_selected`, etc.).
- **Address Book** mistura UI (aba ativa, item selecionado, rascunho de nota)
  com **dados de domínio** (lista de contatos vive na `session`). Manter os
  contatos no pai/contexto e passar como atributo; só a UI migra.
- **Diálogos que disparam efeitos globais** (ex.: ações que enviam comando ao
  servidor de chat) usam a via "componente → `send(self(), {...})` →
  `handle_info` do `ChatLive`" descrita em
  [02-arquitetura-alvo.md](./02-arquitetura-alvo.md).

## Context menus (avaliar, não obrigatório)

Os menus de contexto (`chat_context_menu`, `context_menu`,
`conversations_context_menu` — mapas com `visible/x/y/target_*`) também são
estado de UI. Eles são mais simples e de alta frequência; podem permanecer no
pai **ou** migrar para um pequeno componente. Recomendação: avaliar custo/ganho
após os diálogos; provavelmente manter no pai agrupados em um sub-mapa (Fase 3).

## Critérios de pronto (Fase 2)

- [ ] Cada diálogo da tabela tem seu `LiveComponent`.
- [ ] `assign_defaults/1` reduzido a ~80–100 chaves.
- [ ] Lista `@event_hook_fns` reduzida proporcionalmente.
- [ ] Nenhuma mudança visual perceptível.
- [ ] `make ci` verde a cada diálogo migrado.
