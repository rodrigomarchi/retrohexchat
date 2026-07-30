# Chat sidebar: UX IRC-native sem treeview

> Criado em 2026-07-30. Revisado em 2026-07-30 apos decisao de nao criar
> fluxos paralelos. Escopo: redesenhar a sidebar de conversas usando entidades
> IRC/client que ja existem no projeto, mantendo a estetica retro e removendo a
> aparencia de treeview.

## Decisao

Atualizar este documento, nao criar outro.

O plano agora e de **fase unica**. A proposta anterior separava "Fase 1 visual"
e "Fase 2 preferencias persistidas", mas essa divisao empurrava o produto para
um modelo mais parecido com Slack/Discord: favoritos genericos, secoes
customizadas, hidden conversations e notification levels por conversa.

Isso nao combina bem com a essencia do RetroHexChat. A plataforma e, no centro,
um IRC com UX propria. A evolucao correta da sidebar deve usar a prata da casa:

- canais joined;
- queries/PMs;
- autojoin;
- channel list;
- notify list;
- contact list;
- ignore list;
- highlight words;
- sound/flash settings;
- reconnect state;
- context menus existentes.

O objetivo e melhorar a UX sem inventar um segundo sistema de organizacao da
conversa.

## Motivacao

A sidebar original parecia uma treeview classica:

```text
[-] MEUS CANAIS
    #lobby
[-] MENSAGENS PRIVADAS
    Yuki
[+] CANAIS POPULARES
```

O modelo real nao e uma arvore. A UI esta mostrando listas de IRC/client com
semanticas diferentes:

- canais em que o usuario esta joined agora;
- PMs conhecidas/recentes;
- atividade nao lida, highlight e flash;
- canais salvos para autojoin;
- descoberta via channel list/popular channels.

A mudanca troca a aparencia de arvore por uma lista de navegacao mais clara,
mas sem mudar o significado operacional dessas entidades.

## Pesquisa usada como limite de produto

Esta proposta usa referencias externas como limite de dominio. A inspiracao
visual pode ser moderna, mas o modelo de produto deve continuar IRC-native.

Referencias IRC:

- RFC 2812 define `JOIN` como o pedido para comecar a escutar um canal.
  Fonte: https://www.rfc-editor.org/rfc/rfc2812.html#section-3.2.1
- RFC 2812 define `PRIVMSG` como mensagem para usuarios ou canais.
  Fonte: https://www.rfc-editor.org/rfc/rfc2812.html#section-3.3.1
- RFC 2812 define `LIST` como comando para listar canais e topicos.
  Fonte: https://www.rfc-editor.org/rfc/rfc2812.html#section-3.2.6
- mIRC documenta switchbar/treebar com highlight, flash e cores de evento,
  mensagem e highlight. Isso valida feedback visual retro de atividade sem
  exigir que a nossa sidebar continue como arvore.
  Fonte: https://www.mirc.com/help/html/display.html

Leitura: em IRC, a unidade primaria de navegacao nao e "workspace section". E
canal joined, query/PM, status/server buffer e descoberta de canais. Qualquer
persistencia nova precisa respeitar isso.

## Estado atual verificado no codigo

### Sessao

Arquivo:

- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`

`RetroHexChat.Accounts.Session` e uma struct em memoria no socket da LiveView.
Ela nao e persistida diretamente no banco.

Campos relevantes ja existentes:

- `channels`: canais joined na sessao atual;
- `active_channel`: canal focado;
- `pm_conversations`: PMs conhecidas/recentes;
- `pm_conversations_truncated`: indica restauracao parcial de PMs;
- `active_pm`: PM focada;
- `notify_list`: nicks observados;
- `contacts`: address book;
- `highlight_words`: palavras de highlight;
- `ignore_list`: nicks ignorados;
- `perform_list`: comandos executados no connect;
- `autojoin_list`: canais para entrar automaticamente;
- `sound_settings`: som/flash por evento;
- `identified`: gate para preferencias persistidas.

Leitura:

- `channels` ja e a lista correta para "canais abertos/joined".
- `pm_conversations` ja e a lista correta para "PMs recentes".
- `open_pm_tabs` nao esta em `Session`; fica no LiveView porque representa
  buffer/tab aberto no browser.
- `autojoin_list` ja e o equivalente IRC-native para "salvar canal para voltar".
- Notify/contacts/highlights/ignore/sound ja cobrem boa parte do que uma V2
  generica chamaria de favoritos, pessoas importantes, mute e notificacoes.

### Composicao da tela

Arquivo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`

O template compoe:

- `RetroHexChatWeb.ChatLive.Components.Conversations` para a sidebar;
- `<.chat_tabs>` para a tab bar;
- viewport de mensagens/status;
- nicklist;
- toolbar e surfaces auxiliares.

Dados passados para a sidebar hoje:

- `channels={@session.channels}`;
- `active_channel={@session.active_channel}`;
- `active_pm={@session.active_pm}`;
- `pm_conversations={@session.pm_conversations}`;
- `pm_conversations_truncated={@session.pm_conversations_truncated}`;
- `unread_counts={@unread_counts}`;
- `highlight_channels={@highlight_channels}`;
- `flash_channels={@flash_channels}`;
- `muted_channels={@muted_channels}`;
- `disconnected_channels={...}`;
- `group_call_channels={@group_call_channels}`;
- `p2p_session={@p2p_session}`;
- `p2p_pm_sessions={@p2p_pm_sessions}`;
- `conversations_sections={@conversations_sections}`;
- `channel_user_counts={@channel_user_counts}`;
- `popular_channels={@popular_channels}`;
- `nick_color_fn={@nick_color_fn}`.

Dados passados para tabs:

- `channels={@session.channels}`;
- `pm_tabs={@open_pm_tabs}`;
- `active_channel`;
- `active_pm`;
- unread/status/P2P/group-call.

Leitura:

- a separacao entre "PM conhecida" e "PM aberta como tab" ja existe;
- a sidebar pode evoluir sem alterar `ChatTabs`;
- para mostrar autojoin na sidebar, basta roscar dados existentes de
  `session.autojoin_list`; nao precisa de tabela nova.

### Adapter LiveComponent da sidebar

Arquivo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/conversations.ex`

Este componente e o lugar correto para montar read-model de UI:

- recebe assigns do parent;
- deriva listas simples como unread channels e unread PMs;
- chama o componente visual;
- mantem eventos voltando para o parent.

Ele pode passar a derivar:

- `alert_items`;
- `joined_channel_items`;
- `pm_items`;
- `autojoin_items`;
- `popular_channel_items`.

Isso continua sendo UI read-model. Nao deve virar regra de dominio nem acessar
Repo.

### Componente visual

Arquivo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/conversations.ex`

O componente visual nao usa mais `TreeView` nesta superficie. Ele ainda usa a
composicao local do design system (`Button`, `EmptyState`, `ListStates`,
badges de group call/P2P e `Icons`) e renderiza:

- `ACTIVITY`;
- `OPEN CHANNELS`;
- `RECENT PRIVATE MESSAGES`;
- `AUTO-JOIN`;
- `POPULAR CHANNELS`, visivel quando ha canais populares reais ou quando a
  acao de abrir a lista completa esta disponivel;
- acao compacta `Browse All Channels...` dentro de `POPULAR CHANNELS`.

Arquivo de estilo dedicado:

- `apps/retro_hex_chat_web/assets/css/retrohex/components/chat-conversations.css`

Ele suporta estados visuais de sidebar:

- active;
- unread;
- highlight;
- flash;
- muted;
- disconnected;
- group call;
- P2P.

A troca principal aconteceu aqui: secoes/rows especificas de conversa,
mantendo o design system retro e os atributos consumidos pelos hooks/context
menus.

### Eventos e fluxos

Arquivos:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex`;
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/channel.ex`;
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/pm.ex`;
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/conversations_events.ex`;
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/conversations_context_menu_events.ex`;
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/timer_handlers.ex`.

Fluxos atuais que devem permanecer:

- `switch_channel`: foca canal, reseta unread/highlight/flash, carrega usuarios
  e mensagens, salva reconnect.
- `close_channel_tab`: chama `part_channel`; fechar tab de canal significa sair
  do canal.
- `switch_pm`: garante assinatura da PM, adiciona conversa conhecida, abre tab,
  foca PM, reseta unread e carrega historico.
- `close_pm_tab`: remove de `@open_pm_tabs`; a conversa pode continuar na
  sidebar.
- `conversations_join_popular`: entra no canal popular e recarrega discovery.
- `ctx_conversations_mute`: alterna `muted_channels` em memoria.
- `ctx_conversations_mark_read`: reseta unread/highlight/flash em memoria.
- `execute_autojoin`: percorre `session.autojoin_list` e entra nos canais em
  background apos perform.

### Persistencia existente

Arquivos:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/helpers/persistence.ex`;
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/autojoin_list.ex`;
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex`;
- `apps/retro_hex_chat/lib/retro_hex_chat/presence/notify_list.ex`;
- `apps/retro_hex_chat/lib/retro_hex_chat/accounts/contact_list.ex`;
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/highlight_words.ex`;
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/ignore_list.ex`;
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/sound_settings.ex`;
- `apps/retro_hex_chat/lib/retro_hex_chat/chat/schemas/user_preference.ex`.

`load_persisted_data/2` ja carrega para usuario identificado:

- notify list;
- contacts;
- nick colors;
- highlight words;
- ignore list;
- perform list;
- autojoin list;
- flood protection;
- sound settings;
- bio;
- aliases;
- custom menus;
- autorespond rules;
- PM conversations via `Queries.list_pm_partners/2`.

Isso confirma a tese: a UX melhor deve expor melhor essas entidades, nao criar
um store paralelo de sidebar.

## O que nao vamos inventar

Fora do escopo deste plano:

- favoritos genericos de canal/PM;
- secoes customizadas estilo workspace;
- hidden conversations persistidas;
- notification levels por conversa independentes de highlight/sound/ignore;
- drag-and-drop persistido para qualquer item;
- tabela nova para preferencias de sidebar;
- persistencia de unread;
- persistencia de active tab fora do reconnect temporario.

Racional:

- canal salvo para voltar ja e `autojoin`;
- pessoa importante ja pode ser `notify_list` ou `contacts`, dependendo da
  intencao;
- nao ver mensagens de alguem ja e `ignore_list`;
- receber destaque ja e `highlight_words` mais mention do nick;
- som/flash ja e `sound_settings`;
- discovery ja e channel list/popular channels;
- PM recente ja vem do historico de PM.

Se uma necessidade futura nao couber nisso, ela deve ser desenhada como
evolucao explicita dessas entidades, nao como "sidebar preferences" generico.

## Proposta de UX

A sidebar vira um painel de conversas IRC-native:

```text
+-- CONVERSAS -------------------+
| [# 3] [PM 1] [AJ 3]           |
| ATIVIDADE                  02 |
| !  #anime                  03 |
| !  Yuki                    01 |
+--------------------------------+
| CANAIS ABERTOS                |
| >  #lobby                  03 |
|    #anime                  03 |
+--------------------------------+
| PRIVADAS RECENTES             |
| o  Yuki                  aberta|
| .  Lana                       |
+--------------------------------+
| AUTOJOIN                      |
| +  #elixir              login |
| +  #secret                +key |
+--------------------------------+
| DESCOBRIR CANAIS              |
| +  #brasil                42  |
| +  #retro                 18  |
+--------------------------------+
| [lista] Browse All Channels... |
```

### Secoes

| Secao | Fonte | Acao primaria | Persistencia |
| --- | --- | --- | --- |
| `ALERTAS` | `unread_counts`, `highlight_channels`, `flash_channels` | focar conversa | sessao |
| `CANAIS ABERTOS` | `session.channels`, `channel_user_counts` | `switch_channel` | sessao + reconnect |
| `PRIVADAS RECENTES` | `session.pm_conversations`, `open_pm_tabs` | `switch_pm` | historico para identificado |
| `AUTOJOIN` | `session.autojoin_list` | entrar/editar via fluxo autojoin existente | banco para identificado |
| `DESCOBRIR CANAIS` | `popular_channels` | `conversations_join_popular` ou channel list | derivado da sessao |

Quando `popular_channels` esta vazio, a secao `DESCOBRIR CANAIS` nao renderiza
um bloco vazio. A entrada para o diretorio completo continua disponivel no
rodape da sidebar via `conversations_browse_all`.

### Estados de linha

```text
>  #lobby                 3    ativo
!  #anime                12    highlight
*  #dev                   4    unread
-  #offtopic            mut    muted na sessao
~  #old                disc    disconnected/reconnect
o  Yuki                aberta PM com tab aberta
.  Lana                       PM recente sem tab aberta
+  #brasil              42    discovery/join
+  #secret            +key    autojoin com chave salva
```

### Por que `AUTOJOIN` aparece na sidebar

Autojoin e a resposta IRC-native para "meus canais salvos". O proprio help do
app descreve `/autojoin` como canais que entram automaticamente no connect, e o
codigo salva essa lista em `autojoin_entries`.

Mostrar essa secao na sidebar nao cria uma entidade nova. Ela apenas torna
visivel um recurso existente que hoje fica mais escondido em comando/dialog.

Cuidados:

- nao chamar de `Favoritos`;
- nao confundir remover de autojoin com sair do canal;
- se o canal autojoin ja estiver joined, ele continua aparecendo em `CANAIS
  ABERTOS`;
- a secao `AUTOJOIN` mostra todos os canais salvos e marca os que ja estao
  joined como `aberto`, sem esconder o vinculo com a lista persistida.

## Plano de fase unica

Status: `IMPLEMENTADO, EM VALIDACAO VISUAL`.

A fase unica foi escolhida apos revisar que a mudanca nao precisa de backend
novo nem de uma segunda camada de preferencias. O checkpoint de UX/UI fechou
estas decisoes para a primeira implementacao:

- `ALERTAS` duplica os itens com atividade no topo, sem remover os mesmos itens
  das secoes canonicas;
- `AUTOJOIN` mostra todos os canais salvos e usa estado `aberto` quando o canal
  ja esta joined;
- busca/filtro da sidebar fica fora deste ciclo;
- incoming PM continua abrindo tab pelo fluxo atual;
- context menus continuam usando `data-channel` e `data-nick`;
- a UI real substitui `TreeView` nesta superficie, mas nao remove o primitive
  global porque ele ainda e usado em outras superficies;
- a secao `POPULAR CHANNELS` continua visivel mesmo sem sugestoes, mantendo a
  acao de abrir a lista completa no mesmo contexto sem criar rodape paralelo.

### Passo 1 - Contratos TDD

Arquivo alvo:

- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/conversations_test.exs`

Objetivo:

- proteger labels e secoes IRC-native;
- proteger exibicao de autojoin vindo da sessao;
- proteger que chave de canal nao vaza na sidebar;
- proteger estado de PM que ja tem tab aberta;
- proteger eventos e testids legados que outros fluxos usam.

### Passo 2 - Showcase e mockup funcional

Arquivo alvo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/showcase_live/chat/conversations_page.html.heex`

Objetivo:

- criar estados visuais representativos com dados simulados;
- validar labels, densidade, largura, badges, colapso e hierarquia;
- validar desktop e mobile.

O showcase deve demonstrar:

- canal ativo;
- canal unread;
- canal highlight;
- canal muted;
- canal disconnected;
- PM recente aberta;
- PM recente nao aberta;
- item de autojoin;
- popular channel;
- estado vazio.

### Passo 3 - Read-model no adapter

Arquivo alvo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/conversations.ex`

Alteracoes:

- derivar `unread_channels` e `unread_pms` de `unread_counts`;
- derivar `collapsed_sections` de `conversations_sections`;
- derivar `autojoin_entries` a partir de `session.autojoin_list`;
- roscar `open_pm_tabs` para o componente visual para distinguir PM conhecida
  de PM aberta como tab.

O componente visual continua aceitando dados crus para o showcase, mas a tela
real passa por este adapter.

### Passo 4 - Componente visual real

Arquivo alvo:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/conversations.ex`

Alteracoes:

- remover a dependencia visual primaria de `TreeView`;
- criar secoes de conversa com header compacto;
- criar row visual unica para channel, PM, autojoin e canais populares quando possivel;
- aumentar a largura desktop para reduzir truncamento;
- adicionar strip compacto de contadores;
- diferenciar visualmente `ACTIVITY` e `AUTO-JOIN`;
- manter o CTA de lista completa dentro da secao `POPULAR CHANNELS`;
- preservar `conversations_sidebar/1`;
- preservar `phx-hook="ConversationsHook"`;
- preservar `data-channel` e `data-nick` onde hooks/context menu dependem;
- preservar ou migrar deliberadamente `data-testid`.

### Passo 5 - Eventos e comandos

Nao criar eventos paralelos quando ja existe fluxo.

Mapeamento:

- canal aberto: `switch_channel`;
- PM recente: `switch_pm`;
- popular channel: `conversations_join_popular`;
- browse: `conversations_browse_all`;
- mark read: `ctx_conversations_mark_read`;
- mute de sessao: `ctx_conversations_mute`;
- leave: `ctx_conversations_leave`;
- settings: `ctx_conversations_settings`;
- autojoin edit: reaproveitar fluxo/dialog de autojoin existente, nao escrever
  direto no banco a partir da row.

Se for preciso adicionar evento para abrir o Auto-Join dialog a partir da
sidebar, ele deve chamar o mesmo fluxo que `/autojoin` sem argumentos ja usa.

### Passo 6 - Help, i18n e testes

Atualizar, se a UI real mudar:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/ui_conversations.html.heex`;
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/feature_unread_indicators.html.heex`;
- Gettext via `dgettext("chat", ...)` nos novos labels;
- tests de `Conversations`;
- tests de context menu;
- tests de reconnect/PM tabs se seletores forem afetados.

Validacao tecnica minima:

- `rtk mix format`;
- testes unitarios/componentes afetados;
- LiveView tests relevantes de sidebar/tabs/PM reconnect;
- screenshots desktop e mobile.

## Criterios de aceite

Produto:

- a sidebar comunica IRC, nao workspace;
- o usuario entende o que esta joined, o que e PM recente, o que e autojoin e o
  que e canal popular sugerido;
- a estetica continua retro;
- a navegacao fica mais clara que a treeview atual;
- nao ha nova promessa de persistencia.

Comportamento:

- fechar tab de canal continua sendo part;
- fechar tab de PM nao apaga PM historica;
- autojoin continua sendo salvo/removido pelos fluxos existentes;
- ignore/highlight/sound continuam sendo as fontes de notificacao existentes;
- reconnect continua usando `rhc_reconnect_state` apenas como estado temporario.

Arquitetura:

- `ChatLive` continua orquestrador;
- LiveComponent da sidebar continua adapter;
- componente UI concentra visual;
- dominio continua sem Phoenix/HEEx;
- nenhuma tabela nova;
- nenhum modelo paralelo de favoritos/secoes/notificacoes.

## Backlog condicionado

Estes itens nao entram agora. So devem ser retomados se houver evidencia de uso
apos a sidebar IRC-native:

- persistir secoes colapsadas em `user_preferences.display_settings`, como
  preferencia visual pequena;
- reorder visual apenas para autojoin, usando `AutoJoinList` que ja tem
  `position`;
- "pessoas importantes" como integracao visual de `notify_list` ou `contacts`,
  nao como favoritos de sidebar;
- mute persistido por conversa somente se for desenhado como evolucao clara de
  `sound_settings` ou como preferencia de cliente, com semantica diferente de
  `ignore_list`;
- ocultar PM recente somente se houver regra de produto clara; se o objetivo for
  nao receber/ver conteudo de alguem, usar `ignore_list`.

## Resultado esperado

Depois desta fase unica:

- a sidebar deixa de parecer arvore;
- a UX fica mais moderna sem perder IRC;
- as entidades existentes ficam mais visiveis;
- tabs continuam sendo buffers abertos;
- canais continuam sendo membership ativa;
- PMs continuam sendo historico/queries recentes;
- autojoin continua sendo o mecanismo de retorno entre logins;
- discovery continua vindo do diretorio/lista de canais.
