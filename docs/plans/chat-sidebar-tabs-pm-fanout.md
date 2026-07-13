# Chat: sidebar, tabs e fanout de PM

> Criado em 2026-07-13. Escopo: separar definitivamente "conversa conhecida"
> de "buffer/tab aberto" no chat, corrigir o fanout de mensagens privadas no
> dominio e deixar o comportamento de PM previsivel, testado e sustentavel.

## 1. Decisao

Vamos seguir a opcao **C como arquitetura** e **B como semantica de produto**.

- **C - fanout centralizado no dominio**: `Chat.Service.send_private_message/5`
  passa a publicar todos os eventos necessarios de PM. Quem persiste a mensagem
  tambem emite o evento pesado da conversa e o evento leve de atividade do
  usuario. Callers deixam de espalhar `incoming_pm_notify`.
- **B - UI sem auto-abrir tabs**: a sidebar mostra conversas conhecidas e
  atividade recente; a tab bar mostra somente buffers abertos. PM recebida
  atualiza sidebar/unread/flash, mas nao abre tab automaticamente.

Essa e a solucao definitiva porque corrige a raiz do problema, nao apenas a
aparencia. Hoje a LiveView mistura historico, inscricao PubSub, sidebar e tab
em `session.pm_conversations`; se apenas escondermos tabs no componente, o
modelo continua errado e a proxima feature volta a depender de acidente de UI.

## 2. Problema atual

O usuario ve uma sidebar com canais e PMs, e tambem uma barra de tabs. A
intencao visual parece ser:

- sidebar = mapa de conversas disponiveis;
- tabs = conversas abertas agora;
- viewport = conversa focada;
- status tab = buffer de notices/status.

Mas o codigo atual nao modela isso. PMs usam uma unica lista,
`session.pm_conversations`, para quatro papeis diferentes:

1. historico restaurado do banco;
2. item visivel na sidebar;
3. tab aberta na barra superior;
4. indicacao indireta de assinatura no topico `pm:<sorted_ids>`.

Consequencias:

- ao logar, PMs historicas restauradas viram tabs imediatamente;
- uma PM recebida de contato novo aparece na sidebar e tambem vira tab;
- fechar tab de PM remove a conversa da sidebar e desassina o topico;
- tests atuais validam esse comportamento antigo, entao precisam ser
  reescritos para o contrato novo;
- a navegacao por teclado usa `pm_conversations`, logo navega por historico,
  nao por tabs abertas;
- o fanout leve de PM (`incoming_pm_notify`) esta espalhado em callers, e nao
  no dominio que cria a mensagem.

## 3. Mapa do que temos hoje

### 3.1 Estado de sessao

Arquivo principal:

- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`

Campos relevantes:

- `channels`: canais joined. Hoje tambem sao tabs, mas isso e aceitavel porque
  canal joined tem custo/semantica de membership.
- `active_channel`: canal focado.
- `pm_conversations`: lista de PMs conhecidas. Na pratica tambem e lista de
  tabs abertas.
- `active_pm`: PM focada.

Funcoes relevantes:

- `Session.add_pm_conversation/2`: insere ou move a PM para o inicio.
- `Session.move_pm_to_front/2`: reordena por recencia quando ja existe.
- `Session.remove_pm_conversation/2`: remove PM e ajusta `active_pm`.
- `Session.rename_pm_conversation/3`: renomeia PM em rename de nick.
- `Session.set_active_pm/2`: foca PM e limpa `active_channel`.

Leitura arquitetural: `Session` hoje sabe sobre conversas conhecidas, mas nao
sabe sobre buffers abertos. O novo estado de tabs pode ficar no LiveView como
`open_pm_tabs`, porque e estado de UI da sessao de browser, nao historico do
dominio.

### 3.2 Template principal

Arquivo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`

Hoje:

- `Conversations` recebe `pm_conversations={@session.pm_conversations}`;
- `<.chat_tabs>` tambem recebe `pm_conversations={@session.pm_conversations}`;
- `MessageViewport` renderiza a conversa ativa;
- `StatusViewport` renderiza o buffer de status;
- `conversation_space/2` decide se ha canvas de space para canal/PM.

Leitura arquitetural: sidebar e tab bar compartilham a mesma fonte. A correcao
visual passa por dar fontes diferentes a esses dois componentes.

### 3.3 Tab bar

Arquivo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/chat_tabs.ex`

Hoje:

- `build_tabs/1` sempre cria `status_tab`;
- depois adiciona tabs de `channels`;
- depois adiciona tabs de `pm_conversations`;
- glifo P2P aparece na PM cujo nick bate com `p2p_peer`.

Contrato atual incorreto:

- `pm_conversations` esta documentado como "Open PM nicks, in order", mas o
  valor real vem do historico/sidebar.

Contrato alvo:

- `ChatTabs` recebe `pm_tabs` ou `open_pm_tabs`;
- a sidebar continua recebendo `pm_conversations`;
- o glifo P2P so aparece se a PM do peer estiver aberta como tab. A sessao P2P
  continua visivel pela status bar global, entao nao depende de tab aberta.

### 3.4 Sidebar de conversas

Arquivos:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/conversations.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/conversations.ex`

Hoje:

- "MY CHANNELS" mostra `channels`;
- "PRIVATE MESSAGES" mostra `pm_conversations`;
- "POPULAR CHANNELS" mostra discovery, sem entrar automaticamente;
- unread de PM vem de `unread_counts["pm:<nick>"]`;
- menu de contexto de PM nao tem acao de remover/ocultar conversa.

Contrato alvo:

- sidebar e a lista de conversas conhecidas/recentes;
- clicar em uma PM abre ou foca a tab;
- fechar tab nao remove a PM da sidebar;
- se um dia quisermos "hide conversation", isso deve ser uma acao explicita da
  sidebar, nao o X da tab.

### 3.5 Eventos principais

Arquivos:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/pm.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`

Hoje:

- `switch_pm` seta `active_pm`, reseta unread, carrega historico e persiste
  reconnect.
- `close_pm_tab` desassina `pm:<sorted_ids>`, chama
  `Session.remove_pm_conversation/2`, reseta unread e remove a PM da sidebar.
- `open_pm_conversation/2` assina topico pesado, adiciona em
  `pm_conversations`, ativa PM e carrega mensagens.
- `handle_pm_send/3` envia PM, adiciona/move conversa e publica manualmente
  `{:incoming_pm_notify, ...}` no topico `user:<target>`.
- `handle_info({:incoming_pm_notify, ...})` autoabre a PM na lista e marca
  unread.
- `handle_info(%{event: "new_pm"})` move conversa para frente e insere no
  viewport se for a PM ativa; senao incrementa unread.

Contrato alvo:

- `switch_pm` deve garantir que a PM esta em `open_pm_tabs`, focar e assinar o
  topico pesado.
- `close_pm_tab` remove somente de `open_pm_tabs` e desassina o topico pesado
  se a PM nao estiver mais aberta/ativa.
- `pm_activity` no topico `user:<nick>` atualiza sidebar, recencia, unread,
  som/flash e notify list, sem abrir tab.
- `new_pm` no topico pesado atualiza o viewport ou unread somente para PMs
  abertas/assinadas.

### 3.6 Persistencia e reconnect

Arquivos:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/persistence.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_handlers.ex`

Hoje:

- usuario identificado restaura PMs via `Queries.list_pm_partners/2`;
- `restore_pm_conversations/2` coloca esses nicks em `session.pm_conversations`;
- o mesmo restore assina todos os topicos pesados de PM;
- reconnect salva `nickname`, `channels`, `active_channel`, `active_pm` e
  `welcomed_channels`, mas nao salva lista separada de tabs;
- `maybe_restore_active_tab/1` aceita `active_pm` se ele estiver em
  `pm_conversations`;
- timers usam `pm_conversations` para ativar/restaurar janelas.

Contrato alvo:

- login restaura PMs recentes para sidebar, nao para tabs;
- login nao assina topicos pesados de todas as PMs historicas;
- reconnect salva `open_pm_tabs` e `active_pm`;
- restaurar `active_pm` abre/assina essa PM se ela passar validacao;
- timers/navegacao usam `open_pm_tabs`, nao historico/sidebar.

### 3.7 PubSub e ponto delicado

Arquivo:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`

Hoje:

- `send_private_message/5` persiste a PM e chama `broadcast_private_message/3`;
- `broadcast_private_message/3` publica `%{event: "new_pm"}` em
  `pm:<sorted_ids>`;
- `incoming_pm_notify` e publicacoes em `user:<target>` acontecem fora do
  dominio, em alguns callers.

Callers que publicam manualmente hoje:

- envio comum de PM em `helpers/pm.ex`;
- envio via command dispatch em alguns caminhos;
- convite P2P em `helpers/lobby_invite.ex`.

Callers que podem nao publicar manualmente:

- action message em PM;
- away auto-reply;
- mensagens de sistema P2P via `persist_p2p_system/3`;
- qualquer futuro caller que use `Chat.Service.send_private_message/5` direto.

Leitura arquitetural: antes de a UI parar de assinar todas as PMs historicas,
o dominio precisa garantir que toda PM nova gera atividade no topico de usuario.
Sem isso, a sidebar perderia eventos.

### 3.8 Navegacao por teclado

Arquivo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/navigation_events.ex`

Hoje:

- `build_window_list/1` monta canais ordenados e `pm_conversations` ordenados;
- a ordem de teclado pode diferir da ordem visual;
- PM historica entra na navegacao mesmo que o usuario nao considere aquilo uma
  tab aberta.

Contrato alvo:

- navegacao por "janelas/tabs" inclui status, canais e `open_pm_tabs`;
- ordem deve bater com a tab bar, nao com ordenacao alfabetica invisivel;
- PM de sidebar fechada nao entra em `window_next`, `window_prev` ou
  `window_select`.

### 3.9 P2P

Arquivos principais:

- `docs/plans/p2p-chat-integracao.md`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/lobby_invite.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`

Contrato ja decidido no plano P2P:

- fechar a tab do PM nao encerra sessao P2P;
- a status bar do chat e a superficie persistente da sessao;
- PM e o buffer natural das mensagens de sistema P2P.

Impacto desta mudanca:

- convite P2P recebido pode aparecer na sidebar/unread sem abrir tab
  automaticamente;
- ao clicar na PM, o card e carregado do historico e a tab abre;
- se o produto quiser deliberadamente abrir a PM no envio de convite pelo
  iniciador, isso continua permitido porque e uma acao local explicita;
- o receptor nao deve depender de auto-tab para perceber a sessao, pois a
  atividade leve e unread devem sinalizar a PM.

## 4. Modelo alvo

### 4.1 Conceitos

| Conceito | Dono | Persistido? | Exibicao |
|---|---|---:|---|
| Canal joined | `Session.channels` | autojoin para identificados | sidebar + tab |
| Canal popular | query/discovery | nao | sidebar discovery |
| PM conhecida | `Session.pm_conversations` | derivada de historico/atividade | sidebar |
| PM aberta | `open_pm_tabs` no LiveView | reconnect local | tab bar |
| PM ativa | `Session.active_pm` | reconnect local | viewport |
| Unread de PM | `unread_counts["pm:<nick>"]` | runtime | sidebar + tab se aberta |
| Topico pesado de PM | assinatura PubSub por tab aberta/ativa | nao | viewport |
| Atividade leve de PM | `user:<nick>` | nao | sidebar/unread |

### 4.2 Topicos e eventos

Topico pesado da conversa:

```elixir
"pm:#{pm_topic(sender, recipient)}"
%{event: "new_pm", payload: payload_completo}
```

Uso:

- entregar conteudo completo para uma PM aberta;
- atualizar viewport ativo;
- reconciliar mensagem otimista do proprio usuario;
- suportar typing, edit/delete/reply se esses eventos forem topico de conversa.

Topico leve do usuario:

```elixir
"user:#{recipient}"
{:pm_activity,
 %{
   peer: sender,
   message_id: pm.id,
   type: safe_type_atom(pm.type),
   timestamp: pm.inserted_at,
   direction: :incoming
 }}
```

E recomendado tambem publicar para o sender:

```elixir
"user:#{sender}"
{:pm_activity,
 %{
   peer: recipient,
   message_id: pm.id,
   type: safe_type_atom(pm.type),
   timestamp: pm.inserted_at,
   direction: :outgoing
 }}
```

Motivo para publicar para os dois:

- o remetente tambem deve ter sidebar/recencia consistentes quando a mensagem
  nasce fora da tab ativa, por exemplo automacoes, mensagens de sistema ou P2P;
- isso reduz casos especiais na LiveView;
- o proprio cliente pode ignorar incremento de unread quando `direction` e
  `:outgoing`.

Compatibilidade:

- `{:incoming_pm_notify, ...}` pode continuar por uma fase curta como ponte,
  mas deve ser removido dos callers depois que `pm_activity` cobrir os testes.
- O contrato final nao deve exigir caller manual para PM activity.

### 4.3 Lifecycle de PM no alvo

Login de usuario identificado:

1. `Queries.list_pm_partners/2` retorna PMs recentes.
2. `session.pm_conversations` recebe esses nicks.
3. Nenhuma tab de PM abre automaticamente.
4. Nenhum topico pesado de PM historica e assinado.
5. `user:<nick>` permanece assinado como hoje.

Receber PM de contato novo:

1. `Chat.Service` persiste PM.
2. `Chat.Service` publica `new_pm` no topico pesado.
3. `Chat.Service` publica `pm_activity` em `user:<recipient>`.
4. LiveView do recipient atualiza `session.pm_conversations`.
5. Sidebar mostra a PM, reordenada para o topo.
6. `unread_counts["pm:<sender>"]` incrementa.
7. Nenhuma tab abre automaticamente.

Clicar na PM na sidebar:

1. adiciona nick em `open_pm_tabs` se ainda nao existir;
2. assina `pm:<sorted_ids>`;
3. seta `active_pm`;
4. limpa unread/flash da PM;
5. carrega historico no viewport;
6. persiste reconnect com `open_pm_tabs` e `active_pm`.

Fechar tab de PM:

1. remove nick de `open_pm_tabs`;
2. se era ativa, escolhe proxima tab aberta, canal ativo ou status;
3. desassina topico pesado se a PM deixou de estar aberta;
4. nao remove de `session.pm_conversations`;
5. nao limpa historico;
6. nao encerra sessao P2P;
7. nao apaga unread da sidebar por si so. Unread e limpo ao abrir/focar.

Enviar PM para contato sem tab aberta:

1. comando ou acao explicita cria/garante conversa conhecida;
2. por ser acao do usuario, pode abrir/focar a tab do target;
3. `pm_activity` outgoing mantem recencia no proprio cliente;
4. recipient ve sidebar/unread sem auto-tab.

## 5. Invariantes que precisam ser garantidas

1. Historico de PM nao e tab.
2. Sidebar pode crescer por historico/atividade; tab bar so cresce por acao de
   abrir/focar.
3. Fechar tab de PM nunca remove conversa da sidebar.
4. Fechar tab de PM nunca encerra P2P.
5. PM recebida de contato novo nao abre tab.
6. PM recebida de contato ignorado nao aparece na sidebar e nao toca unread.
7. Toda PM persistida em `Chat.Service.send_private_message/5` gera atividade
   leve para pelo menos o recipient.
8. O caller nao precisa lembrar de publicar notify manual.
9. Navegacao por teclado reflete a tab bar.
10. Reconnect restaura somente tabs que estavam abertas localmente.
11. Canais continuam com semantica de membership: join abre tab; part fecha tab.
12. Guest nao restaura historico de PM do banco.
13. Identificado restaura PMs historicas na sidebar.
14. Unread de PM funciona mesmo quando a PM nao tem tab aberta.
15. `MessageViewport` so mostra PM ativa aberta.
16. Typing de PM so trafega para PM aberta/ativa.
17. Rename de nick atualiza sidebar, open tabs, unread, flash, mute e active PM.
18. Muted PM nao dispara som/flash, aberta ou fechada.
19. P2P peer sem tab aberta continua visivel pela status bar P2P.
20. Tests antigos que esperam auto-tab precisam mudar, nao ser mantidos por
    compatibilidade acidental.

## 6. Plano TDD

### F0 - Caracterizacao e contrato novo

Objetivo:

- escrever primeiro os testes que descrevem o comportamento alvo;
- deixar claro quais testes antigos devem ser alterados;
- evitar implementar a UI em cima de expectativas ambiguas.

Arquivos de teste a tocar:

- `apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_tabs_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/conversations_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/window_navigation_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`

Red tests:

- PMs restauradas no login aparecem na sidebar, mas nao na tab bar.
- `ChatTabs` renderiza PMs de `open_pm_tabs`, nao de `pm_conversations`.
- PM recebida de novo contato aparece na sidebar com unread, mas nao cria tab.
- Clique em PM da sidebar cria tab, foca e limpa unread.
- Fechar tab de PM mantem item na sidebar.
- `window_next/window_prev/window_select` ignoram PMs fechadas.
- `send_private_message/5` publica activity leve no topico do recipient para
  `message`, `action`, `system` e `p2p_invite`.

Aceite da fase:

- os testes falham pelo motivo certo antes da implementacao;
- cada falha aponta para uma regra de produto/arquitetura acima.

### F1 - Centralizar fanout no dominio

Objetivo:

- `Chat.Service` passa a ser o unico lugar obrigatorio para fanout de PM nova.

Arquivos provaveis:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/pm.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/command_dispatch.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/lobby_invite.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`

Implementacao:

- criar `broadcast_private_activity/3` em `Chat.Service`;
- publicar `{:pm_activity, payload}` para recipient e sender;
- manter `broadcast_private_message/3` no topico pesado;
- remover broadcasts manuais redundantes de `incoming_pm_notify`;
- manter handler legado de `incoming_pm_notify` temporariamente se houver tests
  ou fluxos externos ainda migrando;
- garantir payload sem conteudo sensivel desnecessario. A activity precisa de
  peer, id, type, timestamp e direction; conteudo completo fica no topico pesado
  e no banco.

Red tests especificos:

- `send_private_message/5` publica `%{event: "new_pm"}` em `pm:<sorted>`.
- `send_private_message/5` publica `{:pm_activity, ...}` em `user:<recipient>`.
- `send_private_message/5` publica activity outgoing em `user:<sender>`.
- `type` e preservado para `"message"`, `"action"`, `"system"`,
  `"p2p_invite"` e `"p2p_system"`.
- caller de action PM nao precisa publicar notify manual.
- away auto-reply gera activity.
- `persist_p2p_system/3` gera activity sem codigo extra no caller.

Garantias:

- nenhum novo caminho de PM consegue esquecer a sidebar/unread;
- a futura reducao de assinaturas pesadas nao perde mensagens.

### F2 - Introduzir modelo de tabs abertas

Objetivo:

- adicionar `open_pm_tabs` como estado separado de UI;
- manter `Session.pm_conversations` como sidebar/read-model.

Arquivos provaveis:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/pm.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_handlers.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/membership.ex`

Implementacao:

- inicializar `open_pm_tabs: []` nos assigns default;
- criar helpers pequenos:
  - `ensure_known_pm(socket, nick)`;
  - `open_pm_tab(socket, nick)`;
  - `close_pm_tab(socket, nick)`;
  - `pm_tab_open?(socket, nick)`;
  - `rename_open_pm_tab(socket, old_nick, new_nick)`;
- `open_pm_tab` deve deduplicar e preservar ordem visual;
- decidir ordem de tabs: recomendacao e manter ordem de abertura/foco, movendo
  para frente apenas se a UI ja faz isso para PMs. Se quisermos menos surpresa,
  abrir no fim e nao reordenar tabs por mensagens recebidas.

Red tests:

- estado inicial tem `open_pm_tabs == []`;
- abrir PM adiciona em `open_pm_tabs` e em `session.pm_conversations`;
- abrir PM ja aberta nao duplica;
- fechar PM remove so de `open_pm_tabs`;
- fechar PM ativa escolhe fallback previsivel;
- rename de nick muda `open_pm_tabs`.

Garantias:

- o estado passa a nomear a diferenca que a UI ja tentava comunicar.

### F3 - Separar ChatTabs de Conversations

Objetivo:

- mudar a fonte da tab bar sem mudar a sidebar.

Arquivos provaveis:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/chat_tabs.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/irc_tabs.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/showcase_live/chat/conversations_page.html.heex`

Implementacao:

- trocar attr `:pm_conversations` por `:pm_tabs` em `ChatTabs`, ou manter alias
  temporario com deprecation interna;
- template passa `pm_tabs={@open_pm_tabs}`;
- sidebar continua `pm_conversations={@session.pm_conversations}`;
- `active_pm` so deve ser possivel se PM estiver aberta; se detectar active PM
  sem tab, abrir a tab durante restore/switch ou limpar active PM.

Red tests:

- `ChatTabs` nao renderiza PM que esta na sidebar mas nao em `pm_tabs`;
- `ChatTabs` renderiza unread na PM aberta usando `unread_counts["pm:<nick>"]`;
- glifo P2P aparece apenas se peer esta em `pm_tabs`;
- status tab continua sempre primeiro e nao closeable.

Garantias:

- o crescimento visual das tabs para de acontecer por historico ou PM recebida.

### F4 - Reescrever handlers de PM activity

Objetivo:

- PM recebida vira atividade de sidebar, nao abertura automatica de tab.

Arquivos provaveis:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/pm.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pm_typing_events.ex`

Implementacao:

- adicionar `handle_info({:pm_activity, payload}, socket)`;
- aplicar ignore list antes de inserir sidebar/unread;
- para `direction: :incoming`, incrementar unread se PM nao esta ativa;
- para `direction: :outgoing`, atualizar recencia sem unread;
- `maybe_auto_open_incoming_pm/3` vira `maybe_record_pm_activity/3`;
- `new_pm` pesado deixa de criar conversa nova se a PM nao estiver aberta; em
  tese esse evento nem chega para PM fechada depois da reducao de assinaturas;
- PM ativa continua inserindo no viewport via `new_pm`;
- PM aberta mas nao ativa pode receber unread via activity ou via `new_pm`, mas
  nao os dois. Definir uma unica fonte para contagem:
  - recomendacao: unread vem de `pm_activity`; `new_pm` so atualiza viewport se
    ativo e reconcilia mensagem.

Red tests:

- `pm_activity` incoming de novo contato cria sidebar e unread, sem tab;
- `pm_activity` incoming de contato existente move para topo e incrementa
  unread, sem duplicar;
- `pm_activity` outgoing move para topo sem unread;
- `pm_activity` de usuario ignorado nao cria sidebar;
- `new_pm` de PM fechada nao cria phantom unread;
- PM ativa recebe mensagem no viewport e unread fica zerado.

Garantias:

- a sidebar fica correta mesmo com poucas assinaturas;
- unread nao dobra por receber activity e new_pm.

### F5 - Persistencia, reconnect e restauracao

Objetivo:

- historico e tabs abertas deixam de ser restaurados como se fossem a mesma
  coisa.

Arquivos provaveis:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/persistence.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_handlers.ex`
- `apps/retro_hex_chat_web/assets/js/hooks/connection_status_hook.js`

Implementacao:

- `restore_pm_conversations/2` restaura apenas sidebar e nao assina topico
  pesado;
- `push_reconnect_state/1` inclui `open_pm_tabs`;
- `restore_session/2` valida `open_pm_tabs` como lista de nicks;
- restaurar `active_pm` abre/assina a PM se ela estiver em `open_pm_tabs` ou se
  o active PM vier de estado antigo confiavel;
- se payload antigo nao tem `open_pm_tabs`, nao abrir PM historica
  automaticamente;
- limpar dados invalidos: self PM, nick vazio, duplicata, limite razoavel.

Red tests:

- connect identificado com historico mostra PM na sidebar e nao em tabs;
- guest nao restaura PMs;
- reconnect com `open_pm_tabs: ["Bob"]` restaura tab Bob;
- reconnect com `active_pm: "Bob"` e Bob aberta restaura viewport de Bob;
- reconnect com `active_pm` sem tab nao cria todas as PMs historicas;
- payload antigo sem `open_pm_tabs` nao explode e nao abre PM por historico.

Garantias:

- reload de navegador preserva a area de trabalho local, nao transforma todo
  historico em workspace aberto.

### F6 - Navegacao, timers e comandos

Objetivo:

- todos os lugares que significam "tab/janela" usam `open_pm_tabs`.

Arquivos provaveis:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/navigation_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_handlers.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/ui_actions/core.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/user_lookup_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/hover_events.ex`

Implementacao:

- `build_window_list/1` ou equivalente recebe `open_pm_tabs`;
- ordem de navegacao bate com `ChatTabs.build_tabs/1`;
- `/query`, duplo clique em nick, address/user lookup e menu de contexto
  continuam abrindo PM explicitamente;
- `close_pm_tab` nao e mais uma operacao de "forget conversation";
- se precisarmos de "forget/hide PM", criar evento novo e menu novo na sidebar,
  com nome proprio.

Red tests:

- `window_next` percorre status/canais/PMs abertas;
- PM de sidebar fechada nao entra na navegacao;
- `window_select` por indice bate com a ordem da tab bar;
- `/query Bob` abre tab Bob;
- menu/lookup abre tab Bob;
- fechar Bob remove da navegacao, mas Bob continua na sidebar.

Garantias:

- atalhos passam a agir sobre o que o usuario enxerga como tabs.

### F7 - P2P, rename e comportamento cruzado

Objetivo:

- garantir que features acopladas a PM continuam corretas com tabs fechaveis.

Arquivos provaveis:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/lobby_invite.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/membership.ex`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`

Implementacao:

- convite P2P enviado pelo iniciador pode abrir/focar a PM localmente;
- convite recebido usa `pm_activity` para sidebar/unread;
- aceitar convite a partir da PM aberta continua funcionando;
- status bar P2P continua sendo fonte persistente da sessao;
- `rename_pm_state/3` tambem renomeia `open_pm_tabs`;
- topicos pesados sao resubscribed apenas para PMs abertas.

Red tests:

- convite P2P recebido cria sidebar/unread sem tab automatica;
- abrir a PM mostra o card do convite;
- fechar tab do peer nao encerra P2P;
- glifo P2P desaparece da tab se a tab foi fechada, mas status bar permanece;
- rename de peer atualiza sidebar, open tab, active PM e unread keys.

Garantias:

- a mudanca de tabs nao quebra o plano P2P ja decidido.

### F8 - Limpeza e remocao de compatibilidade

Objetivo:

- remover caminhos antigos depois que o contrato novo estiver coberto.

Implementacao:

- apagar broadcasts manuais de `incoming_pm_notify`;
- se nenhum fluxo externo usa mais, remover handler de `incoming_pm_notify`;
- atualizar nomes e docs de attrs (`pm_tabs`, nao `pm_conversations` em tabs);
- revisar showcases;
- atualizar docs/help se a UI tiver texto que mencione comportamento antigo;
- rodar suite completa.

Red tests:

- busca por `incoming_pm_notify` deve retornar apenas testes de migracao ou
  nada, conforme decisao final;
- busca por `pm_conversations` dentro de `chat_tabs.ex` deve desaparecer;
- busca por `Session.remove_pm_conversation` deve mostrar somente fluxo de
  ocultar/remover conversa, se ele existir.

Garantias:

- o codigo nao fica com dois contratos competindo.

## 7. Matriz de testes

### Dominio

| Caso | Arquivo sugerido | Garantia |
|---|---|---|
| `send_private_message/5` publica `new_pm` | `chat/service_test.exs` | PM aberta recebe conteudo |
| publica `pm_activity` incoming | `chat/service_test.exs` | sidebar/unread nao dependem de caller |
| publica `pm_activity` outgoing | `chat/service_test.exs` | recencia do remetente consistente |
| action/system/p2p geram activity | `chat/service_test.exs` | sem buraco em fluxos especiais |
| self-PM excluida de restore | existente | historico limpo |

### Estado

| Caso | Arquivo sugerido | Garantia |
|---|---|---|
| `Session.pm_conversations` continua lista de sidebar | `accounts/session_test.exs` | read-model preservado |
| helpers de `open_pm_tabs` deduplicam | novo teste Live/helper | tabs estaveis |
| rename atualiza open tabs | membership/session tests | nick change sem estado quebrado |

### Componentes

| Caso | Arquivo sugerido | Garantia |
|---|---|---|
| `ChatTabs` usa `pm_tabs` | `chat_tabs_test.exs` | historico nao vira tab |
| unread aparece em tab aberta | `chat_tabs_test.exs` | feedback preservado |
| P2P glyph so em tab aberta | `chat_tabs_test.exs` | sem dependencia falsa |
| Conversations mostra PMs conhecidas | `conversations_test.exs` | sidebar preservada |

### LiveView

| Caso | Arquivo sugerido | Garantia |
|---|---|---|
| restore mostra sidebar, nao tabs | `session_persistence_test.exs` | login limpo |
| incoming PM nao autoabre tab | `session_persistence_test.exs` | tab bar nao cresce sozinha |
| clicar sidebar abre tab | `session_persistence_test.exs` ou novo feature test | fluxo explicito |
| fechar tab mantem sidebar | `session_persistence_test.exs` | X nao apaga historico |
| PM ignorada nao aparece | `session_persistence_test.exs` | ignore list preservada |
| unread nao duplica | novo test | activity/new_pm coordenados |
| reconnect restaura open tabs | novo/reconnect test | workspace local preservado |
| window navigation usa open tabs | `window_navigation_test.exs` | atalhos corretos |

### P2P

| Caso | Arquivo sugerido | Garantia |
|---|---|---|
| convite recebido sem auto-tab | `p2p_session_flow_test.exs` | nova UX respeitada |
| abrir PM mostra card | `p2p_session_flow_test.exs` | convite acessivel |
| fechar PM nao encerra sessao | `p2p_session_flow_test.exs` | decisao P2P preservada |
| status bar permanece | `p2p_session_flow_test.exs` | sessao nao depende de tab |

## 8. Arquivos impactados

Alta probabilidade:

- `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/chat_tabs.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/conversations.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/conversations.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/pm.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/persistence.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/session.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/membership.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/navigation_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_handlers.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/lobby_invite.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`
- `apps/retro_hex_chat_web/assets/js/hooks/connection_status_hook.js`

Tests:

- `apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs`
- `apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/window_navigation_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_tabs_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/conversations_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`

Possivel impacto secundario:

- showcases de chat;
- docs/help de comandos se houver texto descrevendo PM tabs;
- testes de typing indicator;
- testes de reconnect/localStorage;
- qualquer helper que assume `session.active_pm in session.pm_conversations` como
  equivalente a "tab aberta".

## 9. Comandos de verificacao

Durante TDD, rodar recortes pequenos:

```bash
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/chat/service_test.exs
rtk mix test apps/retro_hex_chat/test/retro_hex_chat/accounts/session_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/session_persistence_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/chat_tabs_test.exs
rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/window_navigation_test.exs
```

Depois de cada fase maior:

```bash
rtk mix test
rtk mix format
```

Antes de considerar concluido:

```bash
rtk mix precommit
```

## 10. Riscos e mitigacoes

| Risco | Mitigacao |
|---|---|
| Perder PM porque a UI deixou de assinar topicos historicos | F1 primeiro: `Chat.Service` sempre publica `pm_activity` em `user:<nick>` |
| Unread duplicado por receber `pm_activity` e `new_pm` | Definir unread como responsabilidade do evento leve; `new_pm` atualiza viewport ativo |
| Quebrar P2P por remover tab automatica | Status bar P2P permanece fonte persistente; tests de convite/card/fechar tab |
| Reconnect abrir historico inteiro | `open_pm_tabs` explicito no payload; payload antigo nao abre PM historica |
| Fechar tab apagar conversa | `close_pm_tab` nao chama `Session.remove_pm_conversation/2` |
| Rename deixar topicos/tabs inconsistentes | atualizar `rename_pm_state/3` para sidebar + tabs + active + keys |
| Callers continuarem publicando notify manual | F8 remove chamadas e adiciona busca/teste de ausencia |
| Tests antigos mascararem regressao | F0 reescreve expectativas antes da implementacao |
| Ordem visual diferente da ordem de atalho | navigation usa a mesma lista da tab bar |
| Guest/identified divergirem | tests explicitos para ambos |

## 11. Criterios de aceite

A mudanca esta pronta quando:

- PM historica restaurada aparece na sidebar e nao vira tab.
- PM recebida aparece/move na sidebar, marca unread e nao abre tab.
- Clique em PM na sidebar abre tab, foca e carrega historico.
- Fechar tab de PM mantem a conversa na sidebar.
- Envio comum, action, system, away reply e P2P system geram activity leve pelo
  dominio.
- Nao ha necessidade de caller manual para `incoming_pm_notify`.
- `ChatTabs` nao consome `session.pm_conversations`.
- Navegacao por teclado percorre tabs visiveis.
- Reconnect restaura tabs abertas, nao historico inteiro.
- P2P continua ativo ao fechar PM.
- `rtk mix precommit` passa.

## 12. Nao objetivos

- Mudar a semantica de canais joined como tabs.
- Criar janela separada por PM.
- Apagar historico de PM.
- Implementar "hide conversation" na sidebar, a menos que seja aberto como
  evento separado.
- Refatorar toda a composicao visual do `chat_live.html.heex`.
- Mudar banco de dados para PMs.

## 13. Sequencia recomendada

1. Escrever e ajustar os red tests de F0.
2. Implementar F1 antes de reduzir qualquer assinatura PubSub.
3. Introduzir `open_pm_tabs` e helpers pequenos.
4. Separar `ChatTabs` da sidebar.
5. Trocar handler de `incoming_pm_notify` por `pm_activity`.
6. Ajustar reconnect, timers e navegacao.
7. Validar P2P e rename.
8. Remover compatibilidade antiga e broadcasts manuais.
9. Rodar `rtk mix precommit`.

Essa ordem importa: primeiro garantimos entrega de evento, depois mudamos a UI
para depender desse evento. Assim a melhoria visual nao cria um buraco de
mensagens.
