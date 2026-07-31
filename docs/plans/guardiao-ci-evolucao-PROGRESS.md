# Guardiao CI - progresso e aprendizados

> Criado em 2026-07-31. Plano base:
> `docs/plans/guardiao-ci-evolucao.md`.

## Objetivo do acompanhamento

Registrar as iteracoes da evolucao do guardiao CI, os tempos medidos, as
decisoes de arquitetura e os gates usados para garantir que velocidade nao
reduza cobertura.

## Regra atual de execucao

Por decisao de 2026-07-31, a ordem de trabalho foi ajustada:

1. Primeiro acelerar o `make ci` completo sem remover checks.
2. Depois adicionar inteligencia por diff, stale/related e camadas seletivas.

Essa ordem evita criar um seletor rapido em cima de um guardiao completo ainda
caro demais para ser usado com frequencia.

## Invariantes

- `make ci` continua sendo o guardiao completo.
- Nenhum check existente do `scripts/ci.exs` pode ser removido para ganhar
  tempo.
- Paralelismo novo precisa ter banco, porta e estado isolados.
- Qualquer ganho precisa ser medido antes e depois.
- Se particionamento causar flakiness, existe caminho serial documentado.

## Iteracoes

### 2026-07-31 - Baseline quick e particionamento de testes

Status: `CONCLUIDO`

Baseline medido:

- Comando: `make ci.quick`
- Resultado: 10 checks, 0 falhas.
- Tempo total: `5m42s`.

Tempos por check no baseline:

| Check | Tempo |
|---|---:|
| Compile | `1.1s` |
| i18n Tooling Tests | `1.4s` |
| i18n Quality | `1.5s` |
| JS Tests | `8.0s` |
| JS Lint | `8.5s` |
| Credo | `3.5s` |
| CSS Lint | `5.6s` |
| Format | `5.8s` |
| Tests | `3m38s` |
| Feature Tests | `5m32s` |

Conclusao:

- O gargalo real e ExUnit, principalmente `test_feature`.
- Otimizar stage ordering economiza poucos segundos.
- Particionar `Tests` e `Feature Tests` e a primeira mudanca com maior retorno
  sem perda de cobertura.

Experimentos:

| Suite | Modo | Maior shard | Resultado |
|---|---|---:|---|
| Feature Tests | `--partitions 2` | `159.02s` | 322 testes, 0 falhas no total dos shards |
| Tests | `--partitions 2` | `140.26s` | 3867 testes/properties, 0 falhas no total dos shards |

Mudancas implementadas:

- `config/test.exs` passa a aceitar `TEST_DB_SUFFIX`, preservando
  `MIX_TEST_PARTITION` para selecao de shard do ExUnit.
- `scripts/ci.exs` passa a particionar `test` e `test_feature` por default.
- `scripts/ci.exs` roda compile, JS e i18n juntos no Stage 1.
- `Makefile` expoe `CI_TEST_PARTITIONS` e `CI_FEATURE_PARTITIONS`, ambos com
  default `2`.
- `Makefile` adiciona `ci.serial` e `ci.quick.serial` para fallback sem
  particionamento.

Aceite desta iteracao:

- `make ci.quick` continua rodando todos os 10 checks do modo quick.
- `make ci.quick` usa 2 particoes para `Tests` e 2 para `Feature Tests` por
  default.
- `make ci.quick.serial` executa o mesmo conjunto com 1 particao por suite.
- `test` e `test_feature` nao compartilham banco quando rodam em paralelo:
  `TEST_DB_SUFFIX` separa os bancos e `MIX_TEST_PARTITION` fica para o ExUnit.
- O tempo total do quick caiu de `5m42s` para `3m01s`.

Validacao executada:

- `mix format scripts/ci.exs config/test.exs`
  - Resultado: passou.
- `elixir scripts/ci.exs --only compile --test-partitions 1 --feature-partitions 1`
  - Resultado: 1 check, 0 falhas.
- `make ci.quick`
  - Resultado: 10 checks, 0 falhas, `3m01s`.
  - `Tests`: 2 particoes, `2m40s`.
  - `Feature Tests`: 2 particoes, `2m53s`.
- `make ci`
  - Resultado: 11 checks, 0 falhas, `2m53s`.
  - `Tests`: 2 particoes, `2m24s`.
  - `Feature Tests`: 2 particoes, `2m34s`.
  - `Dialyzer`: `11.2s`.
- `make ci.quick.serial`
  - Resultado: 10 checks, 0 falhas, `5m08s`.
  - `Tests`: 1 particao, `3m25s`.
  - `Feature Tests`: 1 particao, `5m00s`.

Aprendizados:

- `MIX_TEST_PARTITION` nao deve ser reutilizado como identificador unico de
  banco quando duas suites independentes sao particionadas ao mesmo tempo.
- `TEST_DB_SUFFIX` separa responsabilidades: ExUnit escolhe o shard, Ecto
  escolhe o banco.
- O full guard completo agora e mais rapido que o quick antigo porque Dialyzer
  e barato com PLT quente; o gargalo era quase todo ExUnit monolitico.
- A rota serial continua util como diagnostico, mas nao deve ser o default.

### 2026-07-31 - Loops locais e seletor por impacto

Status: `CONCLUIDO`

Objetivo:

- Adicionar a camada seletiva depois de acelerar o full guard.
- Manter o seletor explicavel e coberto por testes.
- Criar loops locais oficiais para agentes sem substituir `make ci`.

Mudancas implementadas:

- Criado `scripts/ci_impact.exs` com a matriz de impacto testavel.
- Criado `scripts/ci_impact_test.exs` com 10 cenarios de classificador.
- `scripts/ci.exs` ganhou:
  - `--changed`;
  - `--base`;
  - `--head`;
  - `--explain-only`;
  - plano explicavel com arquivos, superficies, checks selecionados, checks
    pulados e fallback.
- `scripts/ci.exs` agora inclui arquivos untracked no calculo de diff via
  `git ls-files --others --exclude-standard`.
- `Makefile` ganhou:
  - `ci.changed`;
  - `test.stale`;
  - `test.domain.stale`;
  - `test.web.stale`;
  - `test.js.changed`;
  - `test.js.related`;
  - `e2e.changed`;
  - `e2e.shard`.
- `apps/retro_hex_chat_web/assets/package.json` ganhou scripts Vitest
  `test:changed` e `test:related`.
- `README.md` e `docs/AGENT-GUIDE.md` foram atualizados com a politica de
  gates.

Aceite desta iteracao:

- `ci.changed` explica antes de executar.
- Mudanca em arquivo global cai para full.
- Arquivos untracked entram no plano.
- O classificador e coberto por teste unitario.
- Loops locais sao documentados como iteracao, nao como gate final.

Validacao executada:

- `elixir scripts/ci_impact_test.exs`
  - Resultado: 10 testes, 0 falhas.
- `elixir scripts/ci.exs --only ci_impact_tests`
  - Resultado: 1 check, 0 falhas.
- `make ci.changed EXPLAIN=1 CI_BASE=HEAD`
  - Resultado: passou; plano incluiu arquivos tracked e untracked.
- `make test.js.changed SINCE=HEAD`
  - Resultado: passou.
- `make test.js.related FILES='test/lib/i18n.test.js'`
  - Resultado: 1 arquivo de teste, 13 testes, 0 falhas.
- `make -n test.stale test.domain.stale test.web.stale e2e.changed e2e.shard SHARD=1/2`
  - Resultado: comandos renderizados corretamente.

Aprendizados:

- Seletor por diff local precisa considerar untracked, senao planos novos de
  infraestrutura ficam invisiveis.
- Playwright `--only-changed` e seguro para specs alteradas; quando helpers,
  pages ou hooks criticos mudam, o classificador deve ampliar para E2E mais
  amplo.
- `ci.changed` deve permanecer uma ferramenta de iteracao. O `make ci` completo
  continua sendo o contrato final.

### 2026-07-31 - Validacao final do guardiao completo

Status: `CONCLUIDO`

Mudanca desde a validacao anterior:

- O full guard passou a incluir `CI Impact Tests`, protegendo o classificador
  que alimenta `ci.changed`.

Validacao executada:

- `make ci`
  - Resultado: 12 checks, 0 falhas, `2m53s`.
  - Stage 1: 6 checks em paralelo.
  - `CI Impact Tests`: `570ms`.
  - `Tests`: 2 particoes, `2m23s`.
  - `Feature Tests`: 2 particoes, `2m34s`.
  - `Dialyzer`: `11.3s`.

Conclusao:

- O guardiao completo ficou mais rapido e mais abrangente ao mesmo tempo.
- Baseline inicial: `make ci.quick` com 10 checks em `5m42s`.
- Resultado final: `make ci` com 12 checks em `2m53s`.

### 2026-07-31 - Seletores JS/CSS/E2E por superficie critica

Status: `CONCLUIDO`

Objetivo:

- Fechar F4 criando uma camada browser focada para mudancas de frontend.
- Evitar que uma mudanca CSS/JS critica dependa apenas de lint/test unitario.
- Evitar Playwright full quando ja existe smoke confiavel para a superficie.

Mudancas implementadas:

- `Makefile` ganhou smokes Playwright oficiais:
  - `e2e.smoke.connect`;
  - `e2e.smoke.chat`;
  - `e2e.smoke.dialogs`;
  - `e2e.smoke.i18n`;
  - `e2e.smoke.calls`;
  - `e2e.smoke.mobile`;
  - agregador `make e2e.smoke SURFACE=<surface>`.
- `Makefile` ganhou `lint.js.changed SINCE=<ref>` para ESLint/Prettier focado
  em assets JS/test/scripts alterados.
- `assets/package.json` passou a usar cache do ESLint em `lint`, `lint:fix` e
  no novo `lint:changed`.
- `scripts/ci_impact.exs` agora seleciona smokes Playwright por superficie para
  JS, CSS e web source criticos:
  - connect flow;
  - chat shell;
  - dialogs/window manager;
  - i18n;
  - P2P/group call;
  - mobile layout.
- `scripts/ci.exs` ganhou checks `e2e_smoke_*` e executa browser smokes em
  sequencia quando selecionados, evitando conflito de porta, servidor e build de
  assets.
- Mudancas em helpers/pages/global setup E2E continuam ampliando para E2E amplo.
- `README.md`, `docs/AGENT-GUIDE.md`, `e2e/README.md` e o plano-base foram
  atualizados com o contrato dos smokes.

Aceite desta iteracao:

- Mudanca em hook critico seleciona JS checks e smokes Playwright focados.
- Mudanca CSS em area critica seleciona `lint_css`, `lint_bundle` e smoke de
  superficie.
- Mudanca de i18n frontend seleciona JS checks, tooling i18n, quality i18n e
  smoke i18n.
- Playwright full permanece fallback para suporte E2E amplo e superficies sem
  smoke confiavel.
- Os smokes sao comandos oficiais visiveis em `make help`.

Validacao executada:

- `elixir scripts/ci_impact_test.exs`
  - Resultado: 12 testes, 0 falhas.
- `elixir scripts/ci.exs --only ci_impact_tests`
  - Resultado: 1 check, 0 falhas.
- Planos simulados do classificador:
  - `assets/js/hooks/ui/window_manager_hook.js` seleciona `lint_js`,
    `js_tests`, `e2e_smoke_chat`, `e2e_smoke_dialogs`, `e2e_smoke_mobile`.
  - `assets/css/retrohex/dialogs/address-book.css` seleciona `lint_css`,
    `lint_bundle`, `e2e_smoke_dialogs`.
  - `e2e/helpers/chatUsers.ts` amplia para `e2e`.
- `make -n e2e.smoke.connect e2e.smoke.chat e2e.smoke.dialogs
  e2e.smoke.i18n e2e.smoke.calls e2e.smoke.mobile`
  - Resultado: todos os comandos renderizados corretamente.
- `npm test --prefix apps/retro_hex_chat_web/assets`
  - Resultado: 144 arquivos, 3995 testes, 0 falhas.
- `make lint.js.changed SINCE=HEAD`
  - Resultado: passou; nenhum asset JS alterado no diff simulado.
- `make test.js.changed SINCE=HEAD`
  - Resultado: passou.
- `make e2e.smoke.connect`
  - Resultado: 1 teste Playwright, 0 falhas.
- `make ci`
  - Resultado: 12 checks, 0 falhas, `3m14s`.

Aprendizados:

- Playwright precisa ser tratado como estagio serial quando o seletor escolhe
  mais de um smoke; paralelizar smokes no mesmo servidor/porta aumentaria risco
  sem entregar valor claro.
- Para CSS, o ganho vem de mapear arquivos por familia visual, nao por todo o
  bundle: dialogs, shell, calls e mobile tem contratos diferentes.
- `make help` precisava usar `grep -h`; com prefixo de arquivo, a listagem
  escondia o nome real dos targets.

### 2026-07-31 - Full guard particionado por perfil real

Status: `CONCLUIDO`

Objetivo:

- Concluir F5 acelerando o `make ci` completo por particionamento real, sem
  remover nenhum gate.
- Escolher os defaults por medicao local, nao por intuicao.
- Manter uma rota serial para diagnostico quando uma falha depender de
  particionamento.

Mudancas implementadas:

- Criado `scripts/ci_partition_profile.exs` para medir `test` e
  `test_feature` com listas configuraveis de contagem de particoes.
- Adicionados `make ci.partition-profile` e `make ci.partition-profile.plan`.
- `make ci` passou a rodar 13 checks, incluindo `CI Partition Profile Plan`.
- Defaults atualizados:
  - `CI_TEST_PARTITIONS=3`;
  - `CI_FEATURE_PARTITIONS=4`;
  - `CI_TEST_DB_POOL_SIZE=6`.
- O runner imprime os sufixos de banco por suite e o pool por particao:
  `test=1..3 | feature=4..7`.
- Falhas de particao gravam log completo em `tmp/ci-logs/`.
- Quando `compile` roda no Stage 1, particoes ExUnit recebem `--no-compile`
  para evitar recompilacao concorrente.
- Projetos Mix desabilitam protocol consolidation no ambiente de teste com
  `consolidate_protocols: Mix.env() != :test`.
- `config/test.exs` passou a aceitar `TEST_DB_POOL_SIZE` para limitar o pool
  por worker.
- `scripts/ci_impact.exs` trata mudancas no profiler como globais, caindo para
  full guard.

Perfil executado:

`make ci.partition-profile CI_PARTITION_COUNTS=1,2,3,4 CI_PARTITION_SUITES=test,test_feature CI_PARTITION_RUNS=1`

Relatorio: `tmp/ci-partition-profile/20260731T131544Z/report.md`

| Suite | Particoes | Resultado | Wall-clock |
|---|---:|---|---:|
| `test` | 1 | passou | `3m18s` |
| `test` | 2 | passou | `2m16s` |
| `test` | 3 | passou | `1m08s` |
| `test` | 4 | passou | `1m40s` |
| `test_feature` | 1 | passou | `4m58s` |
| `test_feature` | 2 | passou | `2m27s` |
| `test_feature` | 3 | passou | `2m18s` |
| `test_feature` | 4 | passou | `1m55s` |

Decisao:

- `test=3` foi escolhido porque foi o melhor resultado medido e reduziu a suite
  normal para perto de um minuto.
- `test_feature=4` foi escolhido porque reduziu a suite de feature para menos
  de dois minutos no perfil e ficou estavel no full guard.
- Pool `6` por worker preserva paralelismo interno suficiente sem estourar o
  limite local de conexoes do Postgres.
- Cobertura continua explicita: o guardiao rapido nao consolida cobertura em
  particoes concorrentes. Quando cobertura for o sinal desejado, usar
  `make test.cover` ou `make test.cover.all`.
- Sharding Playwright hospedado fica para F6, porque E2E segue fora do
  `make ci` local e o CI hospedado ainda esta desabilitado por creditos.

Incidentes encontrados e resolvidos:

- Com 7 workers ExUnit, multiplos processos tentaram consolidar protocolos em
  `_build/test/consolidated`, causando erro de escrita intermitente. Resolvido
  com compile previo, `--no-compile` nas particoes e protocol consolidation
  desabilitado no ambiente de teste.
- A primeira rodada com `3/4` workers estourou conexoes do Postgres. Resolvido
  adicionando `TEST_DB_POOL_SIZE` e default local `6`.

Validacao executada:

- `make ci.partition-profile.plan CI_PARTITION_COUNTS=2,3 CI_PARTITION_SUITES=test,test_feature CI_PARTITION_RUNS=1`
  - Resultado: passou.
- `elixir scripts/ci.exs --only ci_partition_profile_plan`
  - Resultado: 1 check, 0 falhas.
- `elixir scripts/ci_impact_test.exs`
  - Resultado: 12 testes, 0 falhas.
- `elixir scripts/ci.exs --only test --test-partitions 1 --feature-partitions 1`
  - Resultado: 2 checks, 0 falhas; validou `--only test` com compile automatico
    e `--no-compile` na particao.
- `make ci`
  - Resultado: 13 checks, 0 falhas, `2m23s`.
- `make ci`
  - Resultado: 13 checks, 0 falhas, `2m25s`.
- `make ci`
  - Resultado: 13 checks, 0 falhas, `2m22s`.
- `make ci.serial`
  - Resultado: 13 checks, 0 falhas, `5m28s`.

Aprendizados:

- O maior ganho sustentavel veio de acelerar o proprio guardiao completo antes
  de sofisticar ainda mais a inteligencia seletiva.
- `MIX_TEST_PARTITION` deve ficar como contrato do ExUnit; `TEST_DB_SUFFIX`
  continua sendo o contrato do runner para separar suites independentes.
- Concurrency de teste precisa controlar tres recursos juntos: banco por
  worker, pool por worker e artefatos compartilhados de build.
- A rota serial e essencial como ferramenta de diagnostico, mas nao deve voltar
  a ser o default.

### 2026-07-31 - CI hospedado seletivo com report final unico

Status: `CONCLUIDO`

Objetivo:

- Concluir F6 preparando GitHub Actions para rodar jobs condicionais pelo mesmo
  classificador usado localmente.
- Manter um check final unico para branch protection.
- Nao reativar consumo automatico de creditos enquanto o projeto ainda esta em
  `workflow_dispatch`.

Mudancas implementadas:

- Criado `scripts/ci_github_plan.exs`.
  - Modo `full`: seleciona os 13 checks do guardiao completo.
  - Modo `changed`: calcula `git diff base...head` e chama `CIImpact.plan/1`.
  - Falha de diff cai para full por fallback conservador.
  - Emite outputs booleanos por check e grupos para GitHub Actions.
  - Escreve resumo Markdown no `GITHUB_STEP_SUMMARY`.
- `.github/workflows/ci.yml` foi reestruturado:
  - job `Impact Plan` sempre roda;
  - jobs `Compile`, `CI Tooling`, `Static Checks`, `Elixir Tests`,
    `Browser Smokes` e `Dialyzer` rodam apenas quando selecionados;
  - job `CI Report` sempre roda e e o unico status final estavel;
  - jobs pulados sao tratados como decisao do plano, nao como check pendente;
  - `workflow_dispatch` continua manual, com input `mode=full|changed`.
- O workflow preserva cobertura hospedada para `test` selecionado usando
  `mix test --cover`.
- Browser smokes ficam disponiveis no CI hospedado quando o seletor escolher
  checks E2E, mas so sao acionados por `workflow_dispatch` enquanto creditos
  estiverem restritos.
- `scripts/ci_impact.exs` trata mudancas no planejador GitHub como globais.

Aceite desta iteracao:

- Docs-only em modo `changed` pode chegar a zero checks tecnicos e ainda publicar
  `CI Report`.
- Mudanca global continua selecionando full guard.
- Job final falha quando um check selecionado falha, quando o job selecionado
  falha por infraestrutura, ou quando um check selecionado nao reporta status.
- Nao ha workflow-level path filter que possa deixar required check pendente.
- Reativar `pull_request`/`push` depois exige apenas habilitar eventos; a
  arquitetura de impacto e report final ja esta pronta.

Validacao executada:

- `elixir scripts/ci_github_plan.exs --mode full --base origin/main --head HEAD`
  - Resultado: passou; selecionou os 13 checks do full guard.
- `elixir scripts/ci_github_plan.exs --mode changed --base HEAD --head HEAD`
  - Resultado: passou; sem diff, selecionou zero checks tecnicos.
- Parser YAML local em `.github/workflows/ci.yml`
  - Resultado: passou.
- `elixir scripts/ci_impact_test.exs`
  - Resultado: 13 testes, 0 falhas.
- `elixir scripts/ci.exs --only ci_impact_tests,ci_partition_profile_plan`
  - Resultado: 2 checks, 0 falhas.
- `git diff --check`
  - Resultado: passou.

Aprendizados:

- O job final precisa avaliar checks selecionados, nao apenas resultado bruto de
  jobs, porque jobs condicionais podem ser `skipped` corretamente.
- O planejador GitHub deve ser um adaptador fino sobre `CIImpact`; duplicar a
  matriz em YAML criaria deriva entre local e hospedado.
- Mesmo com CI automatico desabilitado por creditos, manter a workflow pronta
  reduz o risco da reativacao futura.

### 2026-07-31 - Auditoria de fronteiras do umbrella

Status: `CONCLUIDO`

Objetivo:

- Fechar F7 usando dados antes de qualquer reestrutura do umbrella.
- Criar um comando reproduzivel para acompanhar candidatos a novos apps.
- Registrar uma decisao explicita sobre extracao agora.

Mudancas implementadas:

- Criado `scripts/umbrella_boundary_audit.exs`.
- Criado `make umbrella.boundary-audit`.
- O auditor mede:
  - frequencia de candidatos (`chat`, `bots`, `calls`, `commands`, etc.);
  - pares de co-mudanca por commit;
  - quantidade de commits cross-app;
  - estatisticas de `mix xref graph --format stats`.
- README e guia de agentes passaram a apontar o comando antes de qualquer RFC de
  extracao.

Resultado local:

- `make umbrella.boundary-audit CI_BOUNDARY_COMMITS=80`
  - Resultado: passou, 79 commits analisados.
  - Report: `tmp/umbrella-boundary-audit/20260731T143831Z/report.md`.
- `mix xref graph --format stats`
  - Resultado incorporado no report.
  - 867 arquivos rastreados, 415 dependencias de compile, 1134 de exports,
    2656 de runtime e 6 ciclos.
- `elixir scripts/ci_impact_test.exs`
  - Resultado: 14 testes, 0 falhas.
- `make ci.changed EXPLAIN=1 CI_BASE=HEAD`
  - Resultado: passou; mudancas de tooling cairam para full por fallback
    conservador.

Sinais relevantes:

- `domain + web`: 24 commits.
- `candidate:chat + web`: 33 commits.
- `e2e + web`: 27 commits.
- `candidate:chat + domain`: 16 commits.
- Candidatos mais frequentes: `chat` 33, `bots` 10, `calls` 10,
  `commands` 10.

Decisao:

- Nao criar novo app no umbrella agora.
- `chat` e caro/frequente, mas aparece altamente acoplado a web, E2E, CSS,
  i18n e dominio. Extrair isso agora aumentaria risco e provavelmente nao
  simplificaria o seletor.
- Melhor proximo passo estrutural futuro: reduzir ciclos xref e separar APIs
  publicas pequenas antes de qualquer extracao de app.

Aprendizados:

- A auditoria confirma que reestrutura de umbrella deve ser consequencia de
  fronteiras estaveis, nao mecanismo primario de acelerar CI.
- O seletor por impacto e o particionamento entregaram ganho sem obrigar uma
  extracao prematura.

### 2026-07-31 - Documentacao duravel do protocolo de agentes

Status: `CONCLUIDO`

Objetivo:

- Fechar F8 tornando o protocolo de guardas duravel para agentes e humanos.

Mudancas implementadas:

- README ganhou tabela "Which Guard To Run".
- `docs/AGENT-GUIDE.md` documenta:
  - `make ci` como unico gate final;
  - defaults de particionamento;
  - cobertura explicita;
  - CI hospedado com `CI Report`;
  - auditoria de fronteiras antes de qualquer extracao.
- Plano-base foi atualizado para refletir F0-F8 concluidas.

Aceite:

- Um agente novo consegue escolher loop local, guardiao seletivo e full guard.
- Um humano sabe que branch protection deve depender do check final `CI Report`
  quando GitHub Actions for reativado.
- Reestruturacao do umbrella ficou protegida por dados e RFC curta.

Validacao final:

- `make ci`
  - Resultado: 13 checks, 0 falhas, `2m20s`.
