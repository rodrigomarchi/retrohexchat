# Media sessions P2P + conferencia - estado atual

Data: 2026-07-24

Este documento e a fonte operacional curta para P2P e conferencia depois da
unificacao mobile-first. Use este arquivo para implementacao, revisao e
auditoria. Documentos antigos com capturas de tela ou planos anteriores devem
ser tratados como historico, mesmo quando seus nomes mencionarem "atual".

Para o mapa tecnico de handshake, sinalizacao, recovery e lacunas de
resiliencia, use `docs/reference/call-handshake-resilience-map.md`.

## Contrato de produto

- Existe uma superficie principal por sessao de midia.
- Mobile e desktop usam a mesma experiencia conceitual: uma janela/superficie
  com secoes internas, nao fluxos separados.
- O desktop pode aproveitar mais espaco, mas nao deve reintroduzir janelas
  paralelas para as mesmas features.
- Arquivos, jogos e estatisticas P2P sao secoes da sessao P2P, nao janelas
  top-level independentes.
- Estatisticas da conferencia sao uma secao da janela da conferencia, nao uma
  janela/dock separado.
- P2P usa a mesma logica conceitual da conferencia: a acao vive no contexto da
  conversa/sessao.
- **Nem P2P nem conferencia tem janela dentro do chat.** Cada sessao vive no seu
  proprio endereco (`/p2p/:token`, `/call/:token`) e a unica porta e o card
  escrito na conversa. O chat abre a porta e nao entra por ela.
- O PM mostra uma entrada `P2P` no topic/header quando pode iniciar, quando ha
  request pendente, e quando a sessao esta viva — como link para o endereco, ou
  para a aba que ja esta aberta.
- Convites P2P sao request lines persistidas no PM, com o card que carrega o
  endereco da sessao. Quem convidou entra pelo mesmo card; ao lado dele so fica
  Decline, que e conversa.
- O anchor WebRTC (`p2p-webrtc`) continua desmontado ate `[Ready]`, para nao
  iniciar signaling antes das escolhas de dispositivo.

## Superficies vivas

| Area | Endereco | Container vivo | Secoes vivas |
|---|---|---|---|
| P2P | `/p2p/:token` | `p2p-call` / `p2p-call-window` | Call, Files, Games, Stats |
| Conferencia | `/call/:token` | `group-call` / `group-call-window` | Call, People, Stats, Settings |

## Rotas e eventos vivos

P2P:

- `p2p_start_pm_session` inicia P2P a partir do PM header usando as mesmas
  validacoes do `/p2p`.
- `p2p_console_select` seleciona a secao da sessao, na propria pagina da sessao.
- `open_p2p_console/2` abre/foca `p2p-call` e grava a secao ativa.
- Nao ha entradas de menu/Start para P2P: tudo que agia sobre a sessao vive na
  pagina que a segura.

Conferencia:

- `group_call_console_select` seleciona a secao da conferencia.
- A janela viva e `group-call`; Stats aparece inline dentro dela.

## Superficies removidas

Nao reintroduzir estes caminhos sem uma decisao explicita de produto:

- `p2p-files`
- `p2p-games`
- `p2p-stats`
- `p2p_open_files`
- `p2p_open_games`
- `p2p_open_stats`
- `p2p-files-window`
- `p2p-games-window`
- `p2p-stats-window`
- `group-call-stats`
- a janela `p2p-call` dentro do chat (e o submenu P2P do Start/menu bar)
- `group-call-stats-window`
- `group-call-dock-stats`
- card acionavel de convite P2P no transcript
- componente legado `P2PInviteCard`
- enriquecimento `SessionCard.enrich/1` para `:p2p_invite`

Seletores como `p2p-stats-*`, `p2p-files-*`, `p2p-games-*` e
`group-call-stats-*` ainda podem existir como test IDs internos das secoes. Eles
nao sao evidencia de janelas legadas.

## Evidencia principal

- P2P abre a sessao pelo console unico em
  `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`.
- P2P e conferencia sao renderizados em uma janela cada em
  `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`.
- O registry de janelas fica em
  `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/windows.ex`.
- A navegacao compartilhada por secoes fica em
  `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/media_session/section_nav.ex`.
- O fluxo E2E P2P atual fica em `e2e/tests/chat-p2p.spec.ts` e salva capturas
  visuais em `e2e/test-results/p2p-flow-conference-parity/`.

## Guardrail para trabalho futuro

Se uma feature futura quiser "destacar" arquivos, jogos ou stats em outra
superficie, isso deve ser desenhado como uma nova capacidade explicita. Nao use
codigo antigo ou nomes antigos como compatibilidade silenciosa.
