# Refatoração: estado dos LiveViews grandes

> Plano de refatoração para reduzir o acoplamento e o volume de estado
> concentrado nos LiveViews do diretório `live/app/`, com foco no
> ofensor principal: o cluster `ChatLive`.

Este diretório contém um plano **incremental e por fases**. Cada documento é
autocontido, referencia o código real (`arquivo:linha`) e explica **o quê**,
**o porquê** e **o como** de cada mudança.

## Índice

| # | Documento | Conteúdo |
|---|-----------|----------|
| 0 | [README.md](./README.md) | Este índice, princípios e objetivos |
| 1 | [01-diagnostico.md](./01-diagnostico.md) | Medição dos ofensores, com números e referências de código |
| 2 | [02-arquitetura-alvo.md](./02-arquitetura-alvo.md) | Arquitetura-alvo: `LiveComponent` por diálogo, fontes de verdade, convenções |
| 3 | [03-fase-1-prova-de-conceito-admin-console.md](./03-fase-1-prova-de-conceito-admin-console.md) | Fase 1 — POC: extrair o Admin Console (32 assigns) para um `LiveComponent` |
| 4 | [04-fase-2-demais-dialogos.md](./04-fase-2-demais-dialogos.md) | Fase 2 — replicar o padrão nos demais diálogos |
| 5 | [05-fase-3-limpeza-estado-residual.md](./05-fase-3-limpeza-estado-residual.md) | Fase 3 — agrupar assigns restantes, remover estado morto, revisar a struct `Session` |
| 6 | [06-fase-4-p2p-e-game-session.md](./06-fase-4-p2p-e-game-session.md) | Fase 4 — `streams` + decomposição de `p2p_session_live` e `game_session_live` |
| 7 | [07-testes-riscos-sequenciamento.md](./07-testes-riscos-sequenciamento.md) | Estratégia de testes, riscos, sequenciamento e critérios de pronto |

## Objetivo

Reduzir o estado concentrado no socket raiz do `ChatLive` de **~260 assigns
de primeiro nível** para uma base enxuta (estimativa: **~80–100**), movendo o
estado de cada diálogo para componentes isolados, sem alterar comportamento
visível ao usuário e mantendo `make ci` verde em cada fase.

## Princípios norteadores

Estes princípios vêm do consenso da comunidade Phoenix/LiveView (ver
referências abaixo) e da própria `CLAUDE.md` do projeto:

1. **Estado de UI não pertence ao socket raiz.** Cada diálogo deve possuir o
   próprio estado dentro de um `LiveComponent` stateful, cujo socket é
   independente do pai.
2. **Uma única fonte de verdade.** Pai e componente nunca mantêm cópias do
   mesmo dado. Estado de domínio mora no pai/contextos; estado de UI do diálogo
   mora no componente.
3. **LiveView fino, lógica nos contextos.** Conforme `CLAUDE.md`:
   *"LiveViews MUST be thin — delegate to domain contexts"*.
4. **Mudança incremental e verificável.** Cada fase é um passo isolado,
   reversível, com `make ci` verde e sem mudança de comportamento.
5. **Sem regressão de fidelidade retrô.** Nenhuma mudança altera markup/estilo
   percebido; a refatoração é estrutural, não visual.

## Fora de escopo

- Reescrever a UI ou alterar o visual retrô.
- Trocar o mecanismo de mensagens do `ChatLive` (que **já usa `streams`** — ver
  [01-diagnostico.md](./01-diagnostico.md)).
- Introduzir bibliotecas de estado global (ex.: LiveEx/Flux). Avaliado e
  considerado desnecessário para este caso — ver
  [02-arquitetura-alvo.md](./02-arquitetura-alvo.md).

## Referências da comunidade

- [Phoenix.LiveComponent — HexDocs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html)
- [Phoenix.LiveView — HexDocs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [The Ten Biggest Mistakes Made With Phoenix LiveView and How to Fix Them — Hex Shift](https://hexshift.medium.com/the-ten-biggest-mistakes-made-with-phoenix-liveview-and-how-to-fix-them-cbe2afda4c36)
- [Advanced LiveComponent Architecture in Phoenix LiveView — Hex Shift](https://hexshift.medium.com/advanced-livecomponent-architecture-in-phoenix-liveview-patterns-for-scalability-and-1b53d3c41408)
- [Structuring Phoenix LiveView Applications for Long-Term Maintainability — Hex Shift](https://hexshift.medium.com/structuring-phoenix-liveview-applications-for-long-term-maintainability-and-team-collaboration-e1689c0933cb)
- [Phoenix LiveView Best Practices — Hanso Group](https://www.hanso.group/weblog/phoenix-liveview-best-practices)
