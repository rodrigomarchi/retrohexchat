# Guardiao CI - evolucao continua

**Status:** plano aprovado, nao iniciado
**Criado:** 2026-07-31
**Escopo:** reduzir tempo de feedback sem enfraquecer o guardiao principal.
**Progresso futuro:** `docs/plans/guardiao-ci-evolucao-PROGRESS.md`

---

## 1. Objetivo

Transformar o CI local e hospedado em um sistema de qualidade em camadas:

- `make ci` continua sendo o guardiao completo e autoritativo.
- Um guardiao seletivo roda apenas os checks necessarios para a mudanca atual.
- Loops locais de agente usam testes stale/failed/related para iterar rapido.
- O full guard fica mais rapido por particionamento e sharding, nao por perda de
  cobertura.
- A estrutura do umbrella evolui com base em dados reais de acoplamento e custo.

O objetivo nao e apenas aliviar uma dor atual de 5 minutos. E criar uma
plataforma permanente de evolucao: rapida para iterar, explicavel para agentes e
conservadora quando a confianca estiver em jogo.

## 2. Principios nao negociaveis

1. **`make ci` nao perde autoridade.** Ele continua existindo, continua
   completo, e continua sendo o gate final antes de merge/deploy.
2. **Selecao precisa explicar a decisao.** Todo runner seletivo imprime arquivos
   alterados, checks escolhidos, checks pulados e motivo de fallback.
3. **Fallback conservador.** Qualquer mudanca global, ambigua ou sem regra cai
   para full ou quase full.
4. **Sem estado local como garantia de CI.** `mix test --stale`, `--failed` e
   testes related sao loops de desenvolvimento, nao substitutos do gate de PR.
5. **Mudanca de dominio protege consumidores web.** `retro_hex_chat_web` depende
   de `retro_hex_chat`; alteracoes de dominio podem exigir testes web.
6. **Medicao antes de reestrutura pesada.** Novos apps no umbrella so nascem
   depois de evidencia de fronteiras estaveis, custo relevante e baixo risco de
   ciclos.
7. **Otimizar full guard por paralelismo primeiro.** Partitions/shards reduzem
   wall-clock sem pular cobertura.
8. **O CI hospedado sempre publica um check final.** Path filtering no nivel do
   workflow nao pode deixar required checks pendentes.
9. **Agentes trabalham por contratos.** O runner deve ser facil de invocar,
   previsivel, documentado e seguro para uso automatico.

## 3. Estado atual

O projeto ja tem boa granularidade operacional:

- `Makefile` expoe alvos para `test.domain`, `test.web`, `test.unit`,
  `test.integration`, `test.liveview`, `test.feature`, `test.js`, `lint.css`,
  `lint.js`, `format.check`, `credo`, `dialyzer` e `ci`.
- `scripts/ci.exs` ja executa checks em estagios paralelos e aceita
  `--quick`/`--only`.
- `config/test.exs` ja usa `MIX_TEST_PARTITION` no nome do banco de teste,
  preparando o terreno para particionamento.
- A workflow GitHub Actions existe, mas esta desabilitada por creditos e usa
  `workflow_dispatch`.

Lacunas principais:

- O runner local nao calcula impacto por diff.
- Os targets seletivos existem, mas agentes precisam escolher manualmente.
- Nao ha relatorio padrao dizendo por que um check foi escolhido.
- Nao ha medicao historica por check/superficie.
- Full CI ainda e o caminho mais confiavel para qualquer mudanca, mesmo quando a
  mudanca e localizada.

## 4. Arquitetura alvo

```text
diff git
  -> classificador de superficies
  -> grafo de dependencia entre superficies
  -> plano de checks
  -> execucao paralela quando seguro
  -> relatorio de decisoes e tempos
  -> fallback full quando necessario
```

Camadas:

1. **Loop de edicao:** comandos de foco (`mix test arquivo:linha`,
   `mix test --failed`, `mix test --stale`, `vitest related`, Playwright focado).
2. **Guardiao seletivo:** `make ci.changed BASE=origin/main`, com impacto por
   diff e fallback conservador.
3. **Guardiao completo otimizado:** `make ci` completo, com particionamento onde
   houver ganho real.
4. **CI hospedado:** workflow sempre acionado, jobs condicionais por impacto e
   job final unico para branch protection.
5. **Evolucao estrutural:** novos apps ou fronteiras internas surgem quando os
   dados mostrarem que isso torna o seletor mais correto e barato.

## 5. Matriz inicial de impacto

Esta matriz e a regra inicial. Ela deve morar em codigo de forma testavel, nao
apenas neste documento.

| Mudanca | Checks minimos | Fallback |
|---|---|---|
| `apps/retro_hex_chat/lib/**` | `compile`, `format`, `credo`, `test.domain` | Tambem `test.web` quando tocar APIs publicas usadas pela web, PubSub, comandos, schemas ou migrations relacionadas |
| `apps/retro_hex_chat/test/**` | `format`, testes alterados ou `test.domain` | `test.domain` se suporte/factory/case mudar |
| `apps/retro_hex_chat_web/lib/**` | `compile`, `format`, `credo`, `test.web` | `test.feature` se tocar LiveView de jornada, window manager, auth, chat shell, P2P/calls ou dialogs complexos |
| `apps/retro_hex_chat_web/test/**` | `format`, testes alterados ou `test.web` | `test.web` se suporte/case mudar |
| `apps/retro_hex_chat_web/assets/js/**` | `lint_js`, `js_tests` ou related | Playwright focado se hook, window manager, i18n client, media, games ou UX critica mudar |
| `apps/retro_hex_chat_web/assets/css/**` | `lint_css`, `lint.bundle` | Smoke visual/E2E focado se tocar layout critico, dialogs, chat, connect ou mobile |
| `apps/retro_hex_chat_web/assets/test/**` | `js_tests` focado/changed | `js_tests` completo se suporte/config mudar |
| `e2e/**` | format E2E, Playwright spec alterada | Playwright shard/full se helper/page/global setup mudar |
| `scripts/i18n*`, `scripts/i18n/**`, `priv/gettext/**`, catalogos JS i18n | `py_tests`, `i18n_quality`, checks i18n especificos | Full i18n se catalogs, placeholders ou locale roster mudarem |
| `mix.exs`, `mix.lock`, `.formatter.exs`, `.credo.exs` | full ou quase full | Sempre conservador |
| `config/**`, migrations, repo setup, `test/support/**` | full ou quase full | Sempre conservador |
| `Makefile`, `scripts/ci.exs`, `.github/workflows/**` | full, mais testes do runner | Sempre conservador |
| Documentacao pura | `format` se houver markdown tooling futuro; senao nenhum check tecnico obrigatorio | Full se docs alterarem exemplos executaveis, scripts ou contratos copiados para codigo |

## 6. Definicao de pronto global

O plano so esta concluido quando todos os itens abaixo forem verdadeiros:

- `make ci` continua verde e completo.
- Existe `make ci.changed BASE=<ref>` documentado e testado.
- O runner seletivo explica cada decisao em saida legivel para humanos e agentes.
- Toda regra de impacto tem teste automatizado.
- Mudancas globais e desconhecidas caem para full ou quase full.
- Ha comandos de loop local para stale/failed/related.
- Ha medicao de tempo por check.
- Full guard usa partitions/shards onde isso reduz wall-clock sem flakiness.
- GitHub Actions, quando reativado, usa um job final estavel para branch
  protection e nao depende de workflow-level path filters.
- A documentacao duravel de uso fica em `docs/AGENT-GUIDE.md` ou `README.md`,
  conforme a natureza do aprendizado.

## 7. Plano de fases

Estados:

- `PENDENTE`: ainda nao iniciado.
- `EM ANDAMENTO`: implementacao iniciada.
- `CONCLUIDO`: implementado, testado e documentado.
- `ADIADO`: decisao explicita de nao executar agora.

### F0 - Baseline de tempos e inventario de checks

Status: `EM ANDAMENTO`

Objetivo:

- Medir o custo real de cada check antes de otimizar.
- Separar custo fixo, custo por superficie e custo de setup.

Tarefas:

- Registrar tempo de `compile`, `format`, `credo`, `lint_js`, `lint_css`,
  `js_tests`, `py_tests`, `i18n_quality`, `test`, `test_feature` e `dialyzer`.
- Registrar contagem de testes por app, tag e suite JS/E2E.
- Identificar os 10 arquivos/suites mais caros se ExUnit/Vitest/Playwright
  oferecerem dados suficientes.
- Adicionar um modo de relatorio no runner, por exemplo `scripts/ci.exs
  --profile` ou persistencia de JSON em `tmp/ci-profile/`.

Aceite:

- Existe um relatorio reproduzivel com tempo por check.
- O relatorio mostra tempo total, tempo por estagio e checks que rodaram em
  paralelo.
- O relatorio nao interfere no exit status atual.
- A medicao funciona em maquina local sem GitHub Actions.
- O documento de progresso registra o baseline inicial.

Validacao:

- `make ci.quick` continua funcionando.
- `elixir scripts/ci.exs --only compile,format` continua funcionando.
- O novo modo de perfil gera saida mesmo quando um check falha.

### F1 - Modelo testavel de impacto

Status: `CONCLUIDO`

Objetivo:

- Tirar a matriz de impacto do texto e transformar em codigo pequeno,
  deterministico e coberto por testes.

Tarefas:

- Criar modulo/script de impacto, por exemplo `scripts/ci_impact.exs` ou modulo
  carregado por `scripts/ci.exs`.
- Entrada: lista de arquivos alterados, base/head opcionais e modo local/CI.
- Saida: checks escolhidos, checks pulados, motivos e nivel de fallback.
- Cobrir as regras da matriz inicial com testes.
- Definir aliases de checks estaveis: `compile`, `format`, `credo`,
  `lint_js`, `lint_css`, `lint_bundle`, `js_tests`, `py_tests`,
  `i18n_quality`, `test_domain`, `test_web`, `test_feature`, `dialyzer`,
  `full`.

Aceite:

- Para qualquer path conhecido, o classificador retorna uma decisao previsivel.
- Para path desconhecido, o classificador cai para full ou quase full.
- O classificador consegue receber arquivos por stdin ou argumento para testes
  unitarios.
- As razoes sao strings estaveis e revisaveis.
- O comportamento nao depende de arquivos nao versionados, salvo quando
  explicitamente em modo local.

Validacao:

- Testes unitarios do classificador cobrem pelo menos um exemplo de cada linha
  da matriz.
- Teste especifico garante que mudanca em `config/**` seleciona full.
- Teste especifico garante que mudanca em dominio seleciona dominio e considera
  consumidores web quando a regra exigir.

### F2 - Loops locais de agente

Status: `CONCLUIDO`

Objetivo:

- Dar aos agentes comandos rapidos, oficiais e seguros para iterar entre uma
  falha e a correcao.

Tarefas:

- Adicionar `make test.stale` usando `mix test --stale`.
- Adicionar variantes por superficie se fizer sentido:
  `make test.domain.stale`, `make test.web.stale`.
- Adicionar `make test.failed.fast` ou documentar `make test.failed` como loop
  oficial de rerun.
- Adicionar comando JS changed/related, usando Vitest `--changed` ou
  `vitest related` quando aplicavel.
- Documentar quando cada comando pode e nao pode substituir outros gates.

Aceite:

- O primeiro run stale pode rodar tudo; runs seguintes reduzem o escopo quando
  so uma parte mudou.
- O comando stale nao e usado como criterio final de PR/deploy.
- Se nenhum teste for encontrado, o comportamento e documentado e nao mascara
  erro real.
- Comandos funcionam a partir da raiz do umbrella.
- `make help` lista os novos targets com descricao clara.

Validacao:

- Rodar `make test.stale` em workspace limpo.
- Alterar temporariamente um arquivo de teste em dry-run/manual e confirmar que
  o comando seleciona escopo coerente.
- Reverter qualquer alteracao temporaria antes de concluir a fase.

### F3 - `make ci.changed`

Status: `CONCLUIDO`

Objetivo:

- Criar o guardiao seletivo principal para agentes e humanos.

Tarefas:

- Adicionar target `ci.changed` no `Makefile`.
- Estender `scripts/ci.exs` com `--changed`, `--base`, `--head` e talvez
  `--explain-only`.
- Calcular diff com `git diff --name-only --diff-filter=ACMRTUXB`.
- Excluir deletados dos comandos que recebem paths diretos.
- Executar checks selecionados usando o mesmo runner paralelo atual.
- Imprimir relatorio antes da execucao.
- Manter `--quick` e `--only` compativeis com `--changed`, com regra clara de
  precedencia.

Aceite:

- `make ci.changed BASE=origin/main` roda apenas checks selecionados para uma
  mudanca localizada.
- `make ci.changed EXPLAIN=1` ou equivalente imprime o plano sem executar.
- Mudancas globais caem para full/near-full.
- O exit status e 0 apenas se todos os checks selecionados passarem.
- O relatorio mostra:
  - base/head usados;
  - arquivos alterados;
  - superficies afetadas;
  - checks selecionados;
  - checks pulados;
  - motivo de cada decisao;
  - fallback aplicado ou nao.
- Nenhum check atual some do `make ci`.

Validacao:

- Testes do classificador.
- `elixir scripts/ci.exs --changed --explain-only --base HEAD~1` em branch com
  diff real ou simulado.
- `make ci.quick` continua com comportamento anterior.
- `make ci` continua com comportamento anterior.

### F4 - Seletores especificos para JS, CSS e E2E

Status: `EM ANDAMENTO`

Objetivo:

- Reduzir custo de frontend sem perder os contratos criticos de UI.

Tarefas:

- Atualizar scripts JS para suportar ESLint cache ou lint por arquivos
  alterados quando seguro.
- Adicionar comando Vitest changed/related.
- Definir quando CSS exige apenas `lint.css` e quando exige smoke visual.
- Criar tag ou lista de smoke Playwright por superficie critica:
  connect, chat shell, dialogs, i18n, group call/P2P, mobile.
- Adicionar suporte a Playwright `--only-changed`, `--grep`, arquivo especifico
  ou lista de testes quando for seguro.

Aceite:

- Mudanca em teste JS roda JS tests focados/changed.
- Mudanca em hook critico roda JS tests e sugere/roda E2E focado conforme
  matriz.
- Mudanca CSS em area critica roda `lint.css` e pelo menos um smoke definido.
- O caminho seletivo nunca roda Playwright full por padrao local se um smoke
  confiavel existir.
- Quando helper/page/global setup E2E muda, o seletor amplia para E2E mais
  amplo.

Validacao:

- `npm test --prefix apps/retro_hex_chat_web/assets` continua verde.
- Novo comando changed/related JS funciona com diff local.
- Pelo menos um smoke Playwright focado documentado por superficie critica.

### F5 - Full guard mais rapido por partitions e sharding

Status: `EM ANDAMENTO`

Objetivo:

- Reduzir o tempo do `make ci` completo sem reduzir cobertura.

Tarefas:

- Medir `mix test` com `--partitions 2`, `--partitions 3` e `--partitions 4`.
- Garantir banco particionado por `MIX_TEST_PARTITION` para todos os workers.
- Definir estrategia de cobertura quando particionado: exportar cobertura por
  particao e consolidar, ou manter cobertura em run separado.
- Medir `test_feature` separado versus particionado.
- Medir Playwright sharding quando E2E hospedado voltar.
- Ajustar runner para evitar corrida de compilacao/protocol consolidation.

Aceite:

- O full guard fica mensuravelmente mais rapido em maquina local ou CI.
- Partitions nao introduzem falhas intermitentes por banco, portas, arquivos
  temporarios ou estado global.
- Cobertura continua sendo reportada corretamente ou a excecao fica
  documentada e aprovada.
- O runner preserva logs de falha por particao.
- Um shard/partition com falha falha o check agregado.

Validacao:

- Rodar full suite particionada pelo menos 3 vezes sem flakiness nova antes de
  trocar o default.
- Confirmar que cada particao usa database distinto.
- Confirmar que `make ci` continua passando em modo nao particionado enquanto a
  fase estiver experimental.

### F6 - CI hospedado com jobs condicionais e check final unico

Status: `PENDENTE`

Objetivo:

- Reativar GitHub Actions sem desperdicar credito e sem quebrar branch
  protection.

Tarefas:

- Trocar `workflow_dispatch` por eventos adequados quando creditos permitirem.
- Adicionar job inicial de impacto que sempre roda.
- Condicionar jobs por outputs do classificador, nao por workflow-level path
  filters.
- Manter job `report`/final que sempre publica status unico.
- Restaurar caches de deps, `_build`, node_modules e PLT com chaves revisadas.
- Garantir que skipped checks aparecam como decisao consciente no report.

Aceite:

- Um PR com mudanca de docs nao fica preso em check pendente.
- Um PR com mudanca global roda full/near-full.
- Um PR com mudanca localizada roda so jobs necessarios e o report explica.
- O check requerido para branch protection e o job final, nao cada job
  condicional individual.
- Cache miss nao altera o conjunto de checks, apenas tempo de execucao.

Validacao:

- `workflow_dispatch` manual continua possivel.
- Simular pelo menos tres diffs: docs-only, web-only, config/global.
- Confirmar que o job final falha se qualquer check selecionado falhar.

### F7 - Evolucao do umbrella por dados

Status: `PENDENTE`

Objetivo:

- Usar o seletor e os perfis para decidir se vale criar mais apps no umbrella.

Tarefas:

- Registrar por algumas iteracoes quais diretorios mudam juntos.
- Identificar areas com alta mudanca, alto custo e baixa dependencia cruzada.
- Auditar possiveis fronteiras: `accounts`, `commands`, `bots`, `calls`,
  `arcade`, `services`, `presence`, `rate_limit`.
- Para cada candidata, mapear dependencias de compilacao, dependencias de
  runtime, PubSub, repositorio, migrations e testes.
- Propor no maximo uma extracao por vez.

Aceite:

- Nenhum novo app e criado sem RFC curta ou secao de decisao no progresso.
- A fronteira candidata tem API publica clara.
- Nao ha ciclo de dependencia entre apps.
- O ganho esperado para CI e explicito.
- A extracao preserva config compartilhada do umbrella ou documenta por que isso
  e aceitavel.
- `mix test` da app extraida e dos consumidores passa isoladamente.

Validacao:

- `mix cmd --app <app> mix test` ou equivalente funciona para app extraida.
- `mix test` na raiz continua verde.
- `mix xref graph` ou ferramenta equivalente nao mostra ciclo proibido.

### F8 - Documentacao duravel e protocolo de agentes

Status: `EM ANDAMENTO`

Objetivo:

- Fazer a evolucao virar habito do projeto, nao conhecimento tribal.

Tarefas:

- Atualizar `docs/AGENT-GUIDE.md` com a politica final de gates.
- Atualizar `README.md` ou `CONTRIBUTING.md` com comandos para humanos.
- Criar secao "qual comando rodar" por tipo de mudanca.
- Documentar quando `make ci.changed` basta e quando `make ci` e obrigatorio.
- Documentar formato esperado do relatorio do runner.

Aceite:

- Um agente novo consegue escolher o comando certo sem perguntar.
- Um humano sabe quando exigir full guard.
- A documentacao diferencia loop local, guardiao seletivo e guardiao completo.
- O documento de plano registra quais aprendizados foram promovidos para docs
  duraveis.

Validacao:

- Revisar docs contra targets reais do `Makefile`.
- Rodar `make help` e garantir que nomes documentados existem.

## 8. Politica de fallback

O seletor deve cair para full ou near-full quando ocorrer qualquer item:

- Arquivo alterado nao mapeado.
- Mudanca em `config/**`.
- Mudanca em `mix.exs`, `mix.lock`, `.formatter.exs`, `.credo.exs`.
- Mudanca em `Makefile`, `scripts/ci.exs`, classificador ou workflow CI.
- Mudanca em `test/support/**`, factories, cases ou mocks compartilhados.
- Mudanca em migrations, repo setup, seeds ou schema cross-context.
- Mudanca simultanea em muitas superficies independentes.
- Falha ao calcular diff base/head.
- Estado git ambiguo entre staged/unstaged quando o modo exigir base limpa.

Near-full permitido:

- Pular `dialyzer` apenas em modo explicitamente quick.
- Pular E2E browser-real local quando o plano exigir apenas smoke server-side.
- Pular checks i18n quando nao houver mudanca em fonte/catalogo/i18n tooling.

## 9. Formato esperado do relatorio seletivo

O runner deve imprimir algo nesta forma:

```text
CI changed plan
Base: origin/main
Head: HEAD

Changed files:
- apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex

Surfaces:
- web_live: LiveView runtime changed

Selected checks:
- compile: Elixir source changed
- format: Elixir/HEEx source changed
- credo: Elixir source changed
- test_web: web app source changed
- test_feature: chat LiveView journey surface changed

Skipped checks:
- js_tests: no assets/js or assets/test changes
- i18n_quality: no i18n source/catalog changes
- dialyzer: quick mode enabled

Fallback: none
```

Em caso de fallback:

```text
Fallback: full
Reason: config/test.exs changed; test environment affects every suite
```

## 10. Trade-offs aceitos

- O seletor pode rodar checks demais. Isso e aceitavel.
- O seletor nao pode pular check essencial por otimismo.
- A primeira versao pode ser grosseira por app/superficie.
- Otimizacoes finas por arquivo so entram depois que houver teste de impacto.
- Particionamento que economiza pouco e aumenta flakiness deve ser rejeitado.
- Reestrutura do umbrella pode ser adiada se o seletor simples ja entregar o
  ganho necessario.

## 11. Referencias tecnicas

- Mix `test --stale`, paths em umbrella, `--failed`, `--partitions`:
  `https://mix.hexdocs.pm/Mix.Tasks.Test.html`
- Mix `cmd --app` em umbrella:
  `https://mix.hexdocs.pm/1.12/Mix.Tasks.Cmd.html`
- Umbrella projects e dependencia entre apps:
  `https://elixir.hexdocs.pm/main/dependencies-and-umbrella-projects.html`
- GitHub Actions path filters e checks pendentes:
  `https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax`
- GitHub Actions cache:
  `https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching`
- `dorny/paths-filter`:
  `https://github.com/dorny/paths-filter`
- Nx affected como referencia conceitual:
  `https://nx.dev/docs/features/ci-features/affected`
- bazel-diff como referencia conceitual de affected targets:
  `https://github.com/Tinder/bazel-diff`
- Vitest changed/related:
  `https://vitest.dev/guide/cli`
- ESLint cache:
  `https://eslint.org/docs/latest/use/command-line-interface`
- Playwright `--only-changed`, `--grep`, `--shard`:
  `https://playwright.dev/docs/test-cli`
  `https://playwright.dev/docs/test-sharding`
  `https://playwright.dev/docs/test-annotations`
