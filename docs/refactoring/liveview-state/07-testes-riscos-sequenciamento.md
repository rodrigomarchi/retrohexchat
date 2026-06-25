# Testes, riscos e sequenciamento

## Sequenciamento global

```
Fase 1 (POC: Admin Console)            ── 1 PR  ── risco baixo, valida o padrão
   └─► Fase 2 (demais diálogos)        ── N PRs (1 por diálogo) ── risco baixo
          └─► Fase 3 (limpeza)         ── alguns PRs ── risco médio (Session)
Fase 4 (P2P / Game)                    ── independente ── pode ir em paralelo
```

- **Fases 1 → 2 → 3** são sequenciais (cada uma reduz o socket do `ChatLive`).
- **Fase 4** é independente das demais (toca outros arquivos) e pode ser
  paralelizada ou adiada.
- **Granularidade:** 1 diálogo por commit/PR. Passos pequenos, reversíveis,
  com `make ci` verde sempre.

## Estratégia de testes

A `CLAUDE.md` exige validação por `make ci` (9 checks: compile, format, credo,
dialyzer, CSS lint, JS lint, JS tests, testes unit/integration/liveview, E2E).
Nenhum check pode ser pulado.

Por fase:

| Fase | Testes-chave |
|---|---|
| 1 | `LiveViewTest` do Admin Console via `element([id="admin-console"])`; ciclo abrir→usar→fechar→reabrir (estado limpo na reabertura) |
| 2 | Idem para cada diálogo; tags `@tag :liveview` |
| 3 | Testes de regressão de autocomplete/search após agrupar; testes de domínio de `Session`/`Session.Preferences` (`@tag :unit`) |
| 4 | `LiveViewTest` de P2P/jogo; **E2E** de sessão P2P e de jogo (`@tag :e2e`) |

**Regra:** rodar `make ci` ao fim de cada commit de diálogo. Se qualquer check
falhar, a sub-tarefa não está pronta.

## Riscos e mitigações

| Risco | Probabilidade | Mitigação |
|---|---|---|
| Duplicar estado entre pai e componente (duas fontes de verdade) | Média | Regra de fronteira explícita ([02](./02-arquitetura-alvo.md)): domínio no pai, UI no componente; revisão de cada PR contra essa regra |
| Eventos de domínio disparados de dentro do componente sem chegar ao pai | Média | Padrão `send(self(), {...})` → `handle_info` do `ChatLive`, documentado e testado |
| Regressão visual ao trocar function component por `LiveComponent` | Baixa | Reaproveitar o markup de apresentação existente; `LiveComponent` só envolve o function component |
| Perda de granularidade de diff ao agrupar assigns em sub-mapas | Média | Agrupar só estado coeso e de baixa frequência; medir; não agrupar caminhos quentes |
| Refator de `Session` quebrar muitos chamadores | Média | Fazer por último, guiado por compilador/dialyzer, em PR dedicado; pode ser adiado |
| `attach_hook`/`dispatch_to_hooks` desalinhados ao remover módulos | Baixa | Remover o módulo das **duas** listas (`@event_hook_fns` em `:516` e `attach_all_hooks/1` em `:569`) no mesmo commit |
| E2E de P2P/jogo instável após `streams` | Baixa | Garantir `:id` estável por mensagem; validar `phx-update="stream"` |

## Critérios de pronto globais

- [ ] `assign_defaults/1` reduzido de ~260 para ~80–100 assigns.
- [ ] ≥ 8 `LiveComponent`s (um por diálogo complexo) — projeto sai de 0.
- [ ] Lista `@event_hook_fns` reduzida proporcionalmente.
- [ ] `p2p_session_live` usando `streams`; nenhum `messages ++ [..]`.
- [ ] Nenhuma mudança de comportamento/visual percebida pelo usuário.
- [ ] `make ci` verde em cada PR.
- [ ] Documentação de ajuda (`HelpTopics`) revisada onde aplicável (regra da
      `CLAUDE.md`).

## Observação sobre esforço

Este é um plano de **documentação** — nenhum código de produção foi alterado
neste PR. A implementação deve seguir as fases em PRs próprios, começando pela
Fase 1 como prova de conceito de baixo risco.
