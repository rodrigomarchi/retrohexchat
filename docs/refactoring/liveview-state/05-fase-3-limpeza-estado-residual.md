# Fase 3 — Limpeza do estado residual

Após extrair os diálogos (Fases 1–2), o socket raiz do `ChatLive` cai de ~260
para ~80–100 assigns. Esta fase faz o "acabamento": agrupar o que sobra,
remover estado morto e revisar o god-object `Session`.

## 3.1 Remover estado morto

Itens identificados no diagnóstico como provavelmente vestigiais:

- **`messages: %{}`** em `assign_defaults/1` (`live/app/chat_live.ex:622`).
  O `ChatLive` renderiza mensagens via `streams`
  (`live/app/chat_live.html.heex:219`, `@streams.chat_messages`), e não há
  leitura de `@messages` no template. **Ação:** confirmar com busca
  (`grep -rn "assigns.messages\|@messages" live/`) e remover se não houver
  leitor. Rodar `make ci` para garantir.

> Por que importa: cada assign vivo no socket raiz é replicado por cliente
> conectado e participa do cálculo de diff. Estado morto é puro custo.

## 3.2 Agrupar assigns relacionados em sub-mapas

O que **não** vira componente (estado de UI de alta frequência que vive no
input/janela principal) deve ser **agrupado** em vez de continuar como dezenas
de chaves planas. Recomendação da comunidade: achatar/estruturar assigns para
clarear ownership.

Candidatos a agrupamento (continuam no pai):

| Grupo proposto | Chaves planas hoje |
|---|---|
| `assigns.autocomplete` | `autocomplete_command`, `autocomplete_filter`, `autocomplete_mode`, `autocomplete_results`, `autocomplete_selected`, `autocomplete_visible` |
| `assigns.search` | `search_query`, `search_results`, `search_current_index`, `search_case_sensitive`, `search_regex`, `search_visible`, ... |
| `assigns.context_menus` | `chat_context_menu`, `context_menu`, `conversations_context_menu` |
| `assigns.input` | `input`, `input_error`, `action_mode`, `notice_target`, `command_history`, `history_index` |

> **Cuidado com `streams` e change tracking:** sub-mapas grandes podem reduzir a
> granularidade do diff (o LiveView re-renderiza o que depende do mapa inteiro).
> Por isso **só agrupar estado coeso e de baixa frequência de mudança
> independente**. Estado de busca/autocomplete muda em bloco — bom candidato.
> Não agrupar coisas que mudam isoladamente em caminhos quentes.

Aplicar de forma incremental, um grupo por commit, medindo regressão.

## 3.3 Revisar a struct `Session` (god-object de 28 campos)

`apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex:50` define a struct
com 28 campos misturando naturezas diferentes:

```elixir
# accounts/session.ex:50
defstruct [
  :nickname,
  channels: [], active_channel: nil, pm_conversations: [], active_pm: nil,
  identified: false, connected_at: nil, away: false, away_message: nil,
  strip_formatting: false, notify_list: nil, contacts: nil, nick_colors: nil,
  highlight_words: nil, ignore_list: nil, perform_list: nil, autojoin_list: nil,
  auto_join_on_invite: false, notice_routing: :active, flood_protection: nil,
  sound_settings: nil, aliases: nil, custom_menus: nil, autorespond_rules: nil,
  bio: nil, last_message_at: nil, user_modes: nil, welcomed_channels: nil
]
```

Há **dois tipos de coisa** aqui:

1. **Estado de conexão/sessão** (efêmero): `channels`, `active_channel`,
   `pm_conversations`, `active_pm`, `away`, `away_message`, `connected_at`,
   `last_message_at`, `user_modes`, `welcomed_channels`, `identified`.
2. **Preferências do usuário** (persistentes / configuráveis): `notify_list`,
   `contacts`, `nick_colors`, `highlight_words`, `ignore_list`, `perform_list`,
   `autojoin_list`, `flood_protection`, `sound_settings`, `aliases`,
   `custom_menus`, `autorespond_rules`, `strip_formatting`, `bio`,
   `notice_routing`, `auto_join_on_invite`.

**Proposta (incremental, baixo risco):** introduzir uma sub-struct
`Session.Preferences` agregando o grupo (2), deixando `Session` com o grupo (1)
+ `:preferences`. Benefícios:

- Reduz a superfície da struct principal e clarifica o que é conexão vs.
  preferência.
- Facilita persistir/restaurar preferências como uma unidade (já há
  `save_reconnect_state` em `live/chat_live/helpers/session.ex:271`).
- Os `LiveComponent`s de diálogo (Address Book, Alias, etc.) passam a receber
  `session.preferences.<x>` em vez de a sessão inteira.

> Esta sub-tarefa é a mais invasiva da fase (mexe no domínio e em muitos
> chamadores). Fazer **por último**, com refatoração mecânica auxiliada por
> compilador/dialyzer, e um commit dedicado. Pode ser adiada para um PR próprio
> se o risco for considerado alto no momento.

## 3.4 Encolher a lista de hooks

Com os diálogos migrados, vários `*_events.ex` viraram triviais (só
abrir/fechar). Consolidar:

- Remover da lista `@event_hook_fns` (`live/app/chat_live.ex:516`) e de
  `attach_all_hooks/1` (`live/app/chat_live.ex:569`) os módulos esvaziados.
- Opcional: criar um único `DialogVisibilityEvents` que trate todos os
  `open_<x>`/`close_<x>` genericamente, substituindo ~8 módulos triviais por 1.

## Critérios de pronto (Fase 3)

- [ ] Estado morto removido (confirmado por busca + `make ci`).
- [ ] Pelo menos `autocomplete` e `search` agrupados em sub-mapas.
- [ ] Decisão registrada sobre context menus (agrupar vs. componente).
- [ ] `Session` revisada (ou tarefa de `Session.Preferences` agendada como PR
      próprio, se adiada).
- [ ] Lista `@event_hook_fns` reduzida.
- [ ] `make ci` verde.
