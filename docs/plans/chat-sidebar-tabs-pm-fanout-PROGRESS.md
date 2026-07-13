# Chat sidebar/tabs PM fanout - progresso

> Plano base: `docs/plans/chat-sidebar-tabs-pm-fanout.md`.
> Objetivo: implementar a separacao definitiva entre PM conhecida/sidebar e
> PM aberta/tab, com fanout de PM centralizado no dominio e TDD.

## Estado atual

- Status: em andamento.
- Inicio: 2026-07-13.
- Decisao arquitetural: `Chat.Service.send_private_message/5` deve publicar a
  atividade leve de PM; a UI deve abrir tabs somente por acao explicita.

## Diario de execucao

### 2026-07-13 - baseline

- Criado este arquivo de progresso para registrar fases, aprendizados e
  verificacoes.
- Escrito primeiro lote de red tests para o contrato novo:
  - `Chat.Service.send_private_message/5` deve publicar `pm_activity`;
  - `ChatTabs` deve renderizar `pm_tabs`, nao `pm_conversations`;
  - PM restaurada deve aparecer na sidebar sem virar tab;
  - `pm_activity` deve criar/reordenar sidebar sem auto-abrir tab;
  - clicar na PM da sidebar deve abrir tab e limpar unread;
  - fechar tab deve manter a conversa na sidebar.
- Resultado esperado dos red tests confirmado: falhas apontam para fanout
  ausente, `ChatTabs` acoplado a `pm_conversations`, ausencia de handler
  `pm_activity`, restore assinando PM historica e close removendo a conversa.
- Proximo passo: implementar F1, fanout centralizado no dominio.

### 2026-07-13 - F1 fanout no dominio

- `Chat.Service.send_private_message/5` agora publica:
  - evento pesado `%{event: "new_pm"}` no topico `pm:<sorted_ids>`;
  - `{:pm_activity, ...}` em `user:<sender>` com `direction: :outgoing`;
  - `{:pm_activity, ...}` em `user:<recipient>` com `direction: :incoming`.
- `p2p_system` entrou na lista de tipos conhecidos para normalizacao de tipo.
- Verificacao do recorte de dominio passou.
- Proximo passo: introduzir `open_pm_tabs` e separar `ChatTabs` da sidebar.

### 2026-07-13 - F2 a F8 contrato principal

- Introduzido `open_pm_tabs` como estado de UI no `ChatLive`.
- `ChatTabs` agora recebe `pm_tabs={@open_pm_tabs}` e nao consome mais
  `session.pm_conversations`.
- Sidebar continua usando `session.pm_conversations`.
- `switch_pm` abre tab, assina topico pesado, foca PM, carrega historico e
  limpa unread.
- `close_pm_tab` remove somente a tab, desassina o topico pesado e preserva a
  conversa na sidebar.
- `restore_pm_conversations/2` parou de assinar topicos pesados de PMs
  historicas.
- `pm_activity` virou o evento leve da sidebar/unread; `new_pm` pesado deixou
  de ser dono de unread em PM nao ativa.
- Broadcasts manuais de `incoming_pm_notify` foram removidos dos callers.
- Handler legado `incoming_pm_notify` foi removido depois de confirmar que nao
  havia caller interno restante.
- Reconnect agora salva/restaura `open_pm_tabs` e nao abre PM de payload legado
  que traz apenas `active_pm`.
- Navegacao por teclado usa `open_pm_tabs`, nao historico/sidebar.
- Rename de nick atualiza `open_pm_tabs`.
- P2P feature tests passaram explicitamente com `--include liveview_feature`.
- Proximo passo: rodar suite completa e corrigir regressões restantes.

### 2026-07-13 - verificacao ampla

- `mix test` completo passou no conjunto padrao.
- `mix test --only liveview_feature` passou para os testes feature excluidos do
  conjunto padrao.
- Corrigidos testes antigos de som/flash que ainda simulavam PM de fundo via
  `new_pm`; eles agora usam `pm_activity`, refletindo a nova responsabilidade
  dos eventos.
- `mix format` passou.
- `mix precommit` passou.
- Status final: concluido.

## Checklist

- [x] F0 - Caracterizacao e contrato novo em testes.
- [x] F1 - Fanout de PM centralizado no dominio.
- [x] F2 - Estado `open_pm_tabs` separado de `session.pm_conversations`.
- [x] F3 - `ChatTabs` consumindo somente PMs abertas.
- [x] F4 - Handler de atividade leve de PM sem auto-abrir tab.
- [x] F5 - Persistencia/reconnect restaurando tabs abertas, nao historico.
- [x] F6 - Navegacao/timers/comandos usando tabs abertas.
- [x] F7 - P2P, rename e fluxos cruzados validados.
- [x] F8 - Compatibilidade antiga removida.
- [x] Verificacao final com suite/precommit.

## Aprendizados

- O primeiro recorte de testes confirmou que a suite antiga codificava a
  confusao: "auto-open" significava simultaneamente sidebar, tab e assinatura
  PubSub. Os novos seletores separam sidebar (`data-testid="pm-..."`) de tab
  (`[role="tab"][phx-value-type="pm"]`).
- Centralizar activity no dominio foi pequeno e de baixo risco porque o servico
  ja era o dono do broadcast pesado. A UI ainda pode manter handlers antigos
  enquanto migramos, mas o contrato novo ja nao depende de caller manual.
- Separar tabs no LiveView foi suficiente; nao precisamos mover esse estado para
  `Accounts.Session`, porque tabs abertas sao workspace local/reconnect, nao
  historico persistido.
- `new_pm` e `pm_activity` precisam ter responsabilidades distintas: activity
  cuida de sidebar/unread, enquanto `new_pm` cuida do viewport ativo.
- Os testes de notificacao visual foram bons detectores de contrato antigo:
  som/flash dependiam implicitamente de `new_pm` para PM de fundo. No modelo
  novo, isso pertence explicitamente a `pm_activity`.

## Verificacoes

- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_tabs_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs`
  falhou como esperado antes da implementacao: 2 falhas no dominio e 9 no web.
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`
  passou: 29 tests, 0 failures.
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  passou: 23 tests, 0 failures.
- `rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_tabs_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/window_navigation_test.exs`
  passou: 62 tests, 0 failures.
- `rtk mix test` passou:
  - `retro_hex_chat`: 15 properties, 2713 tests, 0 failures.
  - `retro_hex_chat_web`: 757 tests, 0 failures, 254 excluded.
- `rtk mix test --only liveview_feature` passou:
  - `retro_hex_chat_web`: 254 tests, 0 failures.
- `rtk mix format` passou.
- `rtk mix precommit` passou:
  - `retro_hex_chat`: 15 properties, 2713 tests, 0 failures.
  - `retro_hex_chat_web`: 757 tests, 0 failures, 254 excluded.
