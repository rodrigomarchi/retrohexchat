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
