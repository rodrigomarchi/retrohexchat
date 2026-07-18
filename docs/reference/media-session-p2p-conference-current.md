# Media sessions P2P + conferencia - estado atual

Data: 2026-07-17

Este documento e a fonte operacional curta para P2P e conferencia depois da
unificacao mobile-first. Use este arquivo para implementacao, revisao e
auditoria. Documentos antigos com capturas de tela ou planos anteriores devem
ser tratados como historico, mesmo quando seus nomes mencionarem "atual".

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

## Superficies vivas

| Area | Container vivo | Secoes vivas |
|---|---|---|
| P2P | `p2p-call` / `p2p-call-window` | Call, Files, Games, Stats |
| Conferencia | `group-call` / `group-call-window` | Call, People, Stats, Settings |

## Rotas e eventos vivos

P2P:

- `p2p_console_select` seleciona a secao da sessao.
- `open_p2p_console/2` abre/foca `p2p-call` e grava a secao ativa.
- Entradas de menu/Start para Files, Games e Stats devem apontar para
  `p2p_console_select` com `section`, nao para janelas antigas.

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
- `group-call-stats-window`
- `group-call-dock-stats`

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

## Guardrail para trabalho futuro

Se uma feature futura quiser "destacar" arquivos, jogos ou stats em outra
superficie, isso deve ser desenhado como uma nova capacidade explicita. Nao use
codigo antigo ou nomes antigos como compatibilidade silenciosa.
