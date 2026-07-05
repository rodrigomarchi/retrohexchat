# Prompt de loop de implementação

Este arquivo é o prompt a ser executado em loop até o projeto estar completo e
funcional. Cada iteração é autossuficiente: ela reconstrói o contexto a partir
dos arquivos do plano, avança o máximo que conseguir com segurança e registra
tudo antes de encerrar.

## Como rodar

Em uma sessão nova do Claude Code na raiz do repositório:

```text
/loop Leia docs/plans/espaco.virtual/10-prompt-loop.md e execute uma iteração
completa do loop de implementação do espaço virtual. Não pare até concluir a
iteração e atualizar o PROGRESS.md.
```

Ou como prompt direto por iteração. O loop só termina quando o `PROGRESS.md`
estiver marcado como CONCLUÍDO.

## Prompt

Você está implementando o espaço virtual do Retro Hex Chat (escritório virtual
multiplayer estilo RPG 8-bit, até 20 pessoas, servidor autoritativo). O plano
completo, já auditado contra o codebase e com decisões fechadas, vive em
`docs/plans/espaco.virtual/`.

### Passo 0 — Reconstruir contexto (sempre, em toda iteração)

1. Leia `docs/plans/espaco.virtual/PROGRESS.md` — estado atual, fase corrente,
   próximo item, aprendizados acumulados e bloqueios.
2. Leia `docs/plans/espaco.virtual/05-plano-implementacao.md` — checklist
   canônico. O próximo trabalho é o primeiro item `[ ]` da fase corrente.
3. Leia a seção da fase corrente em
   `docs/plans/espaco.virtual/09-mapa-de-testes.md` — os testes que definem
   "pronto" para cada item.
4. Consulte os docs 00–04 e 06–07 conforme o item exigir (arquitetura,
   protocolo, mapa, integração, decisões). Não reabra decisões fechadas.
5. Rode `git log --oneline -5` e `git status` para ver onde a última iteração
   parou. Trabalho não commitado de iteração anterior é seu para terminar.

### Passo 1 — Executar com TDD

Para cada item do checklist, nesta ordem, sem exceção:

1. Escreva os testes do item (conforme `09-mapa-de-testes.md`) e veja-os
   FALHAR pelo motivo certo.
2. Implemente até os testes passarem.
3. Valide somente os arquivos tocados (ciclo rápido — NÃO rode `make ci` aqui):
   - Elixir: `mix format <arquivos>`, `mix test <arquivo_de_teste>` no app
     correspondente, `mix credo <arquivos>` para módulos novos;
   - JS (em `apps/retro_hex_chat_web/assets`): `npx vitest run <arquivo>`,
     `npx eslint <arquivos>`, `npx prettier --write <arquivos>`;
   - E2E: apenas o spec alvo (`npx playwright test e2e/tests/<arquivo>`);
     antes de confiar num E2E após mudança Elixir, mate o servidor stale da
     porta 4003.
4. Marque o item `[x]` no `05-plano-implementacao.md`.
5. Siga para o próximo item. Trabalhe em blocos longos: continue consumindo
   itens enquanto houver contexto e segurança.

### Passo 2 — Fechamento de fase (somente quando TODOS os itens da fase estão [x])

1. Rode `make ci` completo. É o único momento em que o CI inteiro roda. Se
   falhar qualquer uma das 9 checagens, corrija e rode de novo — a fase não
   fecha com CI vermelho, e nenhuma checagem pode ser pulada.
2. Commit ÚNICO da fase, direto na `main` (nunca criar branch):
   - stage por caminho explícito (`git add <paths>`) — NUNCA `git add -A`
     (a árvore pode carregar trabalho paralelo de outras sessões);
   - mensagem descritiva, ex.:
     `feat(space): fase 1 — dominio VirtualSpace, /space, card e channel minimo`;
   - terminar a mensagem com o trailer de coautoria padrão do harness.
3. Marque os itens de fechamento da fase no `05-plano-implementacao.md` e
   avance a fase corrente no `PROGRESS.md`.

### Passo 3 — Registrar e encerrar a iteração (obrigatório, mesmo se travou)

Atualize `docs/plans/espaco.virtual/PROGRESS.md`:

- data/hora, fase corrente, itens concluídos na iteração;
- **Aprendizados**: tudo que custou a descobrir (APIs reais, gotchas de teste,
  decisões de detalhe) — a próxima iteração não pode repagar esse custo;
- decisões de implementação tomadas (com justificativa curta);
- próximo item exato a atacar;
- bloqueios, se houver, com o que já foi tentado.

### Regras permanentes

- O loop NÃO PARA por dificuldade: quando travar, investigue até a síntese
  (a resposta certa costuma ser um terceiro caminho, não um trade-off binário)
  e registre o aprendizado. Só interrompa para decisão de PRODUTO genuinamente
  nova — e liste-a em "Perguntas para o usuário" no PROGRESS.md antes de
  continuar com outro item que não dependa dela.
- Todo erro/teste vermelho que você encontrar é seu para corrigir agora, mesmo
  que outra sessão o tenha introduzido.
- 100% autoral: os checkouts `~/src/workadventure` e `~/src/gather-clone` são
  APENAS pesquisa de modelagem/estrutura (ver `08-referencias-locais.md`).
  Nunca copiar código, assets, nomes ou textos. Nunca usar assets da Nintendo.
- Padrões da casa (inegociáveis): `@spec` em toda função pública; LiveViews
  finas delegando ao domínio; alias no primeiro write (credo-clean de
  primeira); comentários descrevem o código, não a atividade/migração; sem
  cores hardcoded em Elixir/JS; sem SVG inline (módulos `Icons` + facade);
  nenhum `catch` silencioso no JS; hooks lazy com contrato de
  `lazyFeatureHook`; help topics obrigatórios para comando/feature/UI/atalhos.
- Testes LiveView: nunca assertar em mensagens assíncronas de stream; usar
  estado síncrono (`:sys.get_state`), unit de domínio ou dados persistidos;
  sem sleep/render-retry.
- i18n: ao extrair gettext, manter apenas os catálogos dos domínios afetados,
  reverter o resto e preencher msgstrs com traduções reais.
- Se o desktop/janelas entrarem em cena: Start button usa `icon_hex_stone`;
  geometria de janela nunca é recalculada durante interação de ponteiro;
  estado inicial de janela gerenciada carrega no mount da ilha.
- Browser/E2E para depurar: specs Playwright descartáveis, nunca sessão manual
  de browser.

### Critério de conclusão do projeto

O loop termina quando: todas as fases 1–6 do `05-plano-implementacao.md` estão
`[x]`, o `make ci` final está verde, existe um commit por fase na `main`, e o
fluxo completo do produto funciona de ponta a ponta (criar `/space` num canal,
card persistido, entrar com 2+ usuários, andar com colisão, chat/balões,
sentar, zonas, quadro/modal, poderes do criador, expiração). Nesse momento,
marque `PROGRESS.md` como CONCLUÍDO com um resumo final e encerre o loop.
