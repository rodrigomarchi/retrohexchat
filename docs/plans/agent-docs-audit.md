# Auditoria da documentação de agentes

> **STATUS: EXECUTADO em 2026-08-06.** Os 8 passos do §8 foram aplicados. O registro
> de tudo que saiu, com justificativa por linha, está em
> [`agent-docs-removals.txt`](agent-docs-removals.txt) — 1089 linhas semânticas
> auditadas, 1025 preservadas literalmente, 64 removidas por decisão, 0 perdidas.
> Este plano pode ser apagado após revisão: as regras duráveis que ele produziu já
> vivem em `AGENTS.md` e nas *Conventions* de `docs/README.md`.

Mapa do que existia antes, classificado contra as práticas levantadas na pesquisa
(ETH Zurich AGENTbench, docs oficiais Claude Code/Skills, spec AGENTS.md, Cursor,
Copilot). **Este documento mapeia — não reorganiza.** A reorganização vem depois,
a partir daqui.

Números de código verificados em 2026-08-06 contra a árvore real.

---

## 0. Legenda das classificações

| Tag | Significado |
|---|---|
| **MANTER** | Não é descobrível do código. Fica onde está. |
| **ENCURTAR** | O núcleo é bom, mas carrega detalhe derivável junto. |
| **MOVER** | Conteúdo válido, camada errada (sempre-carregado quando deveria ser sob demanda). |
| **APAGAR** | O agente descobre em 1 tool call, ou duplica outro arquivo. |
| **APLICAR** | Não deveria ser prosa: vira hook, linter ou permissão. |
| **CORRIGIR** | Afirma algo que o código contradiz hoje. |

E as camadas da pesquisa:

```
Camada 0 — ENFORCEMENT   hook / linter / CI          determinístico, sempre vence
Camada 1 — ORIENTAÇÃO    AGENTS.md raiz              sempre no contexto, curto
Camada 2 — ESCOPO        rules por path / skills     carrega condicionalmente
Camada 3 — PROFUNDIDADE  docs/                       custo zero até ser lido
```

---

## 1. O que realmente entra no contexto hoje

Só isto carrega em toda sessão. O resto é sob demanda.

| Arquivo | Linhas | ~Tokens | Quando carrega |
|---|---:|---:|---|
| `CLAUDE.md` | 340 | ~4.2K | **Launch, sempre** (Claude Code) |
| `AGENTS.md` | 13 | ~0.2K | Launch (Codex, Cursor, Copilot, Zed, Amp…) |
| **Total cold-start** | **353** | **~4.4K** | |

**Veredito:** o orçamento (~4.4K) está *dentro* do alvo da pesquisa (<6K), mas as
340 linhas do `CLAUDE.md` estão **70% acima** do limite oficial de 200 linhas — e
o problema não é volume, é composição: ~55% do arquivo é conteúdo derivável do
código, e parte dele está errada (§4).

### O problema estrutural mais grave: a indireção invertida

```
AGENTS.md (13 linhas) ──"leia o CLAUDE.md"──▶ CLAUDE.md (340 linhas)
```

A pesquisa recomenda o inverso: `AGENTS.md` é o canônico (padrão da Agentic AI
Foundation, lido nativamente por ~15 ferramentas) e `CLAUDE.md` é o ponteiro
(`@AGENTS.md`). Hoje qualquer agente que não seja o Claude recebe **apenas uma
instrução para ler outro arquivo** — depende dele decidir abrir, e nada garante
que abra. Todo o conteúdo real do repositório está atrás de um salto opcional.

---

## 2. Inventário — todos os 27 arquivos `.md`

### 2.1 Camada de instrução (o agente obedece)

| Arquivo | Linhas | ~Tok | Carrega | Classificação | Ação |
|---|---:|---:|---|---|---|
| `AGENTS.md` | 13 | 0.2K | launch | Ponteiro invertido | **MOVER** — vira o canônico |
| `CLAUDE.md` | 340 | 4.2K | launch | Mistura 4 camadas | **ENCURTAR** — ver §3 |
| `docs/AGENT-GUIDE.md` | 1139 | 21.8K | sob demanda | 18 seções num arquivo só | **MOVER** — ver §5 |
| `docs/README.md` | 52 | 0.8K | sob demanda | Índice, já bem feito | **MANTER** + virar tabela de roteamento |

### 2.2 Camada de referência (o agente consulta)

| Arquivo | Linhas | ~Tok | Assunto | Classificação | Ação |
|---|---:|---:|---|---|---|
| `docs/reference/call-handshake-resilience-map.md` | 677 | 8.4K | mapa de handshake P2P/conferência | Inventário vivo, PT-BR | **MANTER** — candidato a path-scoped |
| `docs/reference/i18n-catalogs.md` | 228 | 2.6K | convenções Gettext + roster | Inventário vivo, PT-BR | **MANTER** |
| `docs/reference/conferencia-canal-permissoes.md` | 80 | 1.2K | matriz de autoridade | Regra de negócio não-derivável | **MANTER** — alto valor |
| `docs/reference/media-session-p2p-conference-current.md` | 98 | 1.1K | superfícies da sessão de mídia | Inventário vivo | **MANTER** |
| `docs/operations/group-call-sfu.md` | 59 | 0.7K | env vars do SFU | Runbook | **MANTER** |

⚠️ Três destes estão em português e o resto do corpus em inglês. Não é defeito —
mas terminologia inconsistente entre arquivos é um dos anti-padrões documentados.
Decisão a tomar, não urgência.

### 2.3 Domínio virtual.space (pipeline de arte)

| Arquivo | Linhas | ~Tok | Classificação | Ação |
|---|---:|---:|---|---|
| `virtual.space/ANIMATIONS.md` | 356 | 5.2K | Playbook empírico, alto valor | **MOVER** → skill / path-scoped |
| `virtual.space/CHARACTERS.md` | 335 | 4.1K | idem | **MOVER** |
| `virtual.space/SCENES.md` | 318 | 5.0K | idem | **MOVER** |
| `virtual.space/ISOMETRIC.md` | 216 | 3.4K | idem | **MOVER** |
| `virtual.space/DISCOVERY.md` | 89 | 1.5K | Log de arqueologia (ground truth) | **MANTER** |
| `virtual.space/scenes/fx/README.md`, `tools/README.md` | — | — | Runbooks locais | **MANTER** |

Todos dizem literalmente *"read this before …"* — ou seja, já **querem** ser
skills/path-scoped rules com gatilho, mas hoje nada os dispara. O agente só os
encontra se procurar. São ~1.200 linhas de conhecimento empírico caro,
invisíveis por padrão.

### 2.4 Domínio e2e

| Arquivo | Linhas | ~Tok | Classificação | Ação |
|---|---:|---:|---|---|
| `e2e/README.md` | 133 | 1.4K | Runbook + a regra "fora do CI, por design" | **MANTER** |
| `e2e/TEST_CATALOG.md` | 582 | 21.9K | Catálogo com "Last reviewed: 2026-07-28" | **MANTER** — risco de drift alto |
| `e2e/TEST_BACKLOG.md` | 264 | 7.7K | Backlog de jornadas | **MANTER** — é plano, não referência |

`TEST_CATALOG.md` é o segundo maior arquivo do repositório (~21.9K tokens, empatado
com o AGENT-GUIDE) e se descreve como "single source of truth". Um catálogo desse
porte mantido à mão é exatamente o que a pesquisa aponta como custo alto/valor
incerto — mas aqui há um contra-argumento real: os specs Playwright não carregam
essa semântica. Fica, com verificação de drift.

### 2.5 Camada humana (não é doc de agente)

| Arquivo | Linhas | Classificação | Ação |
|---|---:|---|---|
| `README.md` | 442 | Vitrine do projeto | **MANTER** — mas ver drift §4 |
| `CONTRIBUTING.md` | 102 | Humano, PT-BR | **MANTER** |
| `CODE_OF_CONDUCT.md`, `SECURITY.md` | — | Boilerplate | **MANTER** |
| `apps/*/README.md` | — | Gerados pelo Phoenix | **MANTER** |
| `scripts/server-provision.md` | — (44KB) | Runbook de provisionamento | **MANTER** |
| `scripts/research/irc_census/README.md` | — | Metodologia da pesquisa | **MANTER** |

### 2.6 O que **não existe** (e a pesquisa recomenda)

| Ausente | Para quê |
|---|---|
| `.claude/rules/` | escopo por path — hoje **toda** regra é sempre-carregada |
| `.claude/skills/` | procedimentos multi-step (i18n repair, adicionar ícone, gerar arte) |
| `.claude/settings.json` | `permissions.deny` para `_build/`, `deps/`, `node_modules/`, `priv/static/` |
| hooks (`PreToolUse`/`Stop`) | as regras de git que hoje são prosa (§6) |
| `docs/adr/` | racionalidade das decisões travadas (hoje vive na memória do assistente) |

O `.claude/` existe mas contém só `scheduled_tasks.lock` e `worktrees/`. **Zero
uso das camadas 0 e 2.** Tudo está na camada 1 (sempre carregado) ou na 3 (invisível
sem gatilho). É a lacuna central deste repositório.

---

## 3. Dissecção do `CLAUDE.md` (o arquivo que custa em toda sessão)

| # | Seção | Linhas | % | Descobrível? | Classificação | Ação proposta |
|---|---|---:|---:|---|---|---|
| 1 | Active Technologies | 3–12 (10) | 3% | Sim (`mix.exs`) + **números errados** | **CORRIGIR/APAGAR** | 2 linhas de stack, zero contagens |
| 2 | Project Structure | 13–32 (20) | 6% | Sim (`ls`) + duplica README | **APAGAR** | 1 linha: a fronteira umbrella (domínio sem Phoenix) |
| 3 | Commands | 33–58 (26) | 8% | Sim (`make help`, 80+ alvos) | **ENCURTAR** | só os 4 que carregam regra + "rode `make help`" |
| 4 | Git Safety | 59–71 (13) | 4% | Não — mas duplica AGENT-GUIDE §14 | **APLICAR** | vira hook; 1 linha fica |
| 5 | Deploy | 72–90 (19) | 6% | Diagrama sim; a regra não | **ENCURTAR** | mantém "NUNCA `make deploy-sun` direto" |
| 6 | **CI Validation** | 91–195 (**105**) | **31%** | Quase tudo (`scripts/ci.exs`) | **MOVER** | ~8 linhas ficam; resto → `docs/reference/` |
| 7 | Code Style | 196–205 (10) | 3% | Metade é linter | **APLICAR + MANTER** | corta o que o linter faz, mantém arquitetura |
| 8 | CSS Architecture | 206–217 (12) | 4% | Não — mas duplica AGENT-GUIDE §10 | **APAGAR** | dedupe: §10 é mais rico |
| 9 | SVG Architecture | 218–269 (52) | 15% | Tabela sim (`ls icons/`) e **já errada** | **ENCURTAR** | apaga a tabela, mantém regra + procedimento |
| 10 | i18n | 270–322 (53) | 16% | Não — é o melhor conteúdo do arquivo | **MOVER** | path-scoped rule (`priv/gettext/**`, `scripts/i18n/**`) |
| 11 | Help System | 323–333 (11) | 3% | Não — mas duplica AGENT-GUIDE §12 | **APAGAR** | 1 linha + ponteiro; §12 é mais rico |
| 12 | Governing Principles (ponteiro) | 334–340 (7) | 2% | — | **MANTER** | vira tabela de roteamento com gatilhos |

**Leitura:** duas seções (CI + SVG + i18n = 210 linhas) são **62% do arquivo**.
Depois do corte, a estimativa é **~90–110 linhas** de conteúdo sempre-carregado —
dentro do alvo de 200 e sem perder nenhuma regra, porque tudo que sai vai para
uma camada com gatilho, não para o lixo.

### A ironia documentada

`CLAUDE.md:266-268` diz:

> *"There is no hand-written inventory — a list of 344 icons rots the week it is
> written. The submodules under `components/icons/` **are** the catalog."*

Trinta e sete linhas acima, em `CLAUDE.md:229-243`, há **um inventário escrito à mão**
dos submódulos de ícones. Ele tem 15 linhas. O diretório tem 16 arquivos — falta
`call_controls.ex`. O arquivo previu o próprio defeito e o cometeu na mesma seção.

### Onde está o melhor conteúdo (não perder na reorganização)

Estas passagens são exatamente o que a pesquisa classifica como alto valor —
não-derivável, com o *porquê* junto:

- **i18n / glossário** — *"Uma tradução ruim é pior que inglês"*, com os casos
  reais ("OK" → "Está bem.", "No" → "Numéro", "Mute" → "Mignon"). É a única parte
  do arquivo que ensina um critério em vez de ditar uma regra, e traz duas
  heurísticas que **não** funcionaram.
- **"Never `dgettext` an identifier"** — com a consequência: corrompe o audit log,
  que persiste o que recebe. Regra + custo do erro.
- **Sentinelas alfanuméricos, não markup** — modelos tratam token com cara de tag
  como tag e mutilam. Empírico puro.
- **"NEVER `make deploy-sun`"** — a razão (pula validação) está junto.
- **e2e: nunca escrever spec descartável para screenshot** — usar `shot()`, que é
  inerte sem `E2E_SHOTS`. Com a racionalidade: *"a disposable spec deleted after
  the picture is a tool thrown away"*.
- **`GETTEXT_ALLOWED_LOCALES` envenena o compile_env** e quebra `make ci` até um
  `mix compile --force`. Armadilha cara, invisível no código.

---

## 4. Drift verificado — código vs documentação

Medido na árvore, hoje:

| Afirmação | Onde | Documentado | Real | Δ |
|---|---|---:|---:|---|
| migrations | `CLAUDE.md:5`, `README.md:175,398` | 39 | **75** | +92% |
| schemas Ecto | `CLAUDE.md:5`, `README.md:175` | 36 | **53** | +47% |
| bounded contexts | `CLAUDE.md:18` | 11 | **20** | +82% |
| submódulos de ícones | `CLAUDE.md:229-243` | 15 (tabela) | **16** | falta `call_controls` |
| ícones | `CLAUDE.md:266`, `AGENT-GUIDE.md:767` | 344 | **336** | −8 |
| command handlers | `README.md:162,392` | 54 | **63 arquivos** | ver nota |
| JS hooks | `README.md:154,409` | 31 | **38–50** | ver nota |

**Correção (medido de novo com mais rigor):** os dois últimos não são erros
simples, e a primeira versão desta auditoria os exagerou.

- **"54 slash commands" está correto.** `Commands.Registry` tem exatamente 54
  comandos registrados. O que diverge é a árvore do README, que chamava de "54
  handlers" um diretório com 63 arquivos de handler — mais handlers do que
  comandos, porque nem todo handler é um comando de barra. A primeira versão
  desta auditoria dizia "71", que era a contagem de **todos** os `.ex` em
  `commands/` (incluindo parser, dispatcher, registry). Contagem errada minha.
- **"31 JS hooks"** depende do que se conta: 50 arquivos `.js` em `hooks/`, mas 38
  `phx-hook="…"` distintos no HEEx. Nenhum dos dois é 31.

Isso reforça a conclusão em vez de enfraquecê-la: **um número em prosa não tem
como declarar o que está contando.** "54" estava certo para comandos e errado para
handlers, no mesmo README, com o mesmo dígito. Por isso a correção aplicada foi
*remover* as contagens, não atualizá-las.

Cinco afirmações inequivocamente erradas (migrations, schemas, contextos, ícones,
submódulos) e duas ambíguas — nenhuma delas ajudava o agente. No README cada uma
aparecia duas vezes (diagrama ASCII e árvore de diretórios). Nenhuma delas ajuda o agente a
fazer nada — são exatamente a categoria que a ETH mediu como custo negativo:
tokens gastos para transmitir informação que o agente descobriria correta em uma
tool call, e que aqui transmite informação *errada*.

Os contextos são o caso mais grave: 11 documentados vs 20 reais. Os 9 ausentes
(`arcade`, `calls`, `games`, `group_call`, `jobs`, `lobby`, `net`, `system_info`,
`virtual_space`) incluem subsistemas inteiros — um agente que confie na lista
conclui que `group_call` ou `jobs` não existem.

### Uma discrepância que não é numérica

`docs/AGENT-GUIDE.md:932` intitula a seção **"JS hook loading & bundle standard
(CI-enforced)"**, e `CLAUDE.md:192` manda *"NEVER skip dialyzer, JS tests, JS lint,
or CSS lint in final validation"*.

Mas os 13 checks do `make ci` (`scripts/ci_impact.exs:4-18`) são: `compile`,
`lint_js`, `js_tests`, `ci_impact_tests`, `ci_partition_profile_plan`, `py_tests`,
`i18n_quality`, `format`, `credo`, `lint_css`, `test`, `test_feature`, `dialyzer`.

`lint_hooks` e `lint_bundle` **não estão na lista**. Eles rodam em `make lint` e
podem ser selecionados por `make ci.changed`, mas o gate final declarado — `make ci`
— não os executa. O contrato de hooks e o orçamento de bundle estão documentados
como "CI-enforced" e não são, na rota que a documentação define como obrigatória.

Isso é uma decisão a tomar, não necessariamente um bug: ou o `make ci` passa a
rodá-los (e vira 15 checks), ou a documentação para de chamá-los de CI-enforced.
Mas hoje as duas coisas não podem estar certas ao mesmo tempo.

---

## 5. Dissecção do `docs/AGENT-GUIDE.md`

1139 linhas / ~21.8K tokens num arquivo único. Como é sob demanda, não custa nada
até ser lido — mas quando é lido, **entra inteiro**. Perguntar sobre Oban carrega
WebRTC, testes, mobile e i18n junto.

| § | Título | Linhas | Tam. | Natureza | Ação |
|---:|---|---|---:|---|---|
| 1 | Governing Principles | 14–67 | 54 | Constituição | **MANTER** — candidato a subir p/ raiz |
| 2 | State: tiers por escopo | 68–103 | 36 | Arquitetural | MANTER |
| 3 | Command / dispatch (a espinha) | 104–139 | 36 | Arquitetural | MANTER |
| 4 | PubSub & permissions | 140–170 | 31 | Arquitetural | MANTER |
| 5 | Persistence conventions | 171–222 | 52 | Arquitetural | MANTER |
| **6** | **LiveComponent islands** (6.1–6.10) | 223–475 | **253** | Playbook | **DIVIDIR** → arquivo próprio |
| 7 | Windowed desktop (7.1) | 476–585 | 110 | Playbook | DIVIDIR |
| **8** | **WebRTC / P2P** (8.1–8.5) | 586–715 | **130** | Playbook | **DIVIDIR** |
| 9 | UI = composição de componentes | 716–761 | 46 | Regra | MANTER |
| 10 | SVG / CSS fidelity | 762–781 | 20 | Regra | MANTER (canônico p/ CSS/SVG) |
| 11 | Retro / mIRC parity | 782–798 | 17 | Design | MANTER |
| 12 | Help é obrigatório | 799–815 | 17 | Regra | MANTER (canônico p/ help) |
| **13** | **Testing conventions & gotchas** | 816–893 | **78** | Armadilhas | **DIVIDIR** → path-scoped `**/*_test.exs` |
| 14 | Process & tooling discipline | 894–931 | 38 | Armadilhas | **APLICAR** parcialmente (hooks) |
| 15 | JS hook loading & bundle | 932–970 | 39 | Regra | **CORRIGIR** (§4) + path-scoped `assets/js/**` |
| 16 | i18n & public URLs | 971–1001 | 31 | Regra | path-scoped |
| 17 | Oban (17.1–17.5) | 1002–1088 | 87 | Playbook | DIVIDIR |
| 18 | Mobile & touch (18.1–18.2) | 1089–1139 | 51 | Playbook | DIVIDIR |

**Diagnóstico:** o conteúdo é excelente — é o ativo mais valioso do repositório,
denso em *por quê* e em armadilhas empíricas ("`#3639` quebrou o build uma vez",
"um `str.replace` reescreveu silenciosamente uma asserção não relacionada"). O
problema é só de embalagem: **um arquivo monolítico, sem gatilhos, e com um nível
de indireção a mais do que o recomendado** (raiz → AGENT-GUIDE → seção).

O corte natural: §§1–5 e 9–12 são a *constituição* (curta, estável, sempre
relevante); §§6, 7, 8, 13, 17, 18 são *playbooks de subsistema* (longos, só
relevantes quando você toca aquele código) — exatamente o critério de
path-scoped rule ou skill.

### Regra em `CLAUDE.md` vs regra em `AGENT-GUIDE.md` — quem é canônico?

Hoje é ambíguo em quatro assuntos. Instrução contraditória ou duplicada entre
camadas é o anti-padrão explícito da doc oficial ("se dois arquivos discordam, o
modelo escolhe um arbitrariamente"):

| Assunto | `CLAUDE.md` | `AGENT-GUIDE.md` | Mais rico | Proposta |
|---|---|---|---|---|
| Git safety | linhas 59–71 | §14 | **§14** (tem o aviso do `git checkout` destrutivo) | §14 canônico |
| CSS/SVG | 206–269 | §10 | **§10** (tem a história do `#3639`) | §10 canônico |
| Help | 323–333 | §12 | **§12** (tem "reuse existing topic IDs") | §12 canônico |
| i18n | 270–322 | §16 | **empate** — assuntos diferentes | fundir: pipeline+glossário / URLs+rotas |

Em três dos quatro casos, **a versão sempre-carregada é a mais pobre**. O agente
paga contexto por uma versão resumida e só encontra a boa se abrir o guia.

---

## 6. Regras que deveriam ser código, não prosa

A camada 0 está completamente vazia neste repositório. Estas são as candidatas
diretas — todas hoje existem só como texto que o modelo pode ignorar:

| Regra hoje em prosa | Onde | Vira |
|---|---|---|
| `git fetch` + `git pull --ff-only` antes de commitar | `CLAUDE.md:59-71`, §14 | hook `PreToolUse` em `Bash(git commit*)` |
| Nunca `git add -A` (memória do assistente) | — | hook `PreToolUse` |
| Nunca `git checkout <file>` com trabalho não commitado | §14 | hook `PreToolUse` |
| Nunca `make deploy-sun` direto | `CLAUDE.md:77` | hook `PreToolUse` |
| `mix format` antes do `make ci` | §14 | hook, ou o próprio `make ci` |
| Usar o Prettier do repo, não `npx prettier` | §14 | hook, ou alias no Makefile |
| Não ler `_build/`, `deps/`, `node_modules/`, `priv/static/` | — | `permissions.deny` |
| "Todo public function tem `@spec`" | `CLAUDE.md:200` | Credo check (parcialmente já é) |
| "`mix format` enforced", "ESLint enforced" | `CLAUDE.md:198-199` | **já são** — a linha é redundante |

As duas últimas linhas do `CLAUDE.md` sobre formatação são o caso puro do
*"never send an LLM to do a linter's job"*: gastam contexto para pedir ao modelo
o que a ferramenta já garante.

---

## 7. Resumo executivo do mapa

| Dimensão | Estado |
|---|---|
| Orçamento de cold-start | ✅ ~4.4K tokens (alvo <6K) |
| Tamanho do arquivo raiz | ⚠️ 340 linhas (alvo <200) |
| Composição do arquivo raiz | ❌ ~55% derivável do código |
| Precisão | ❌ 7/7 afirmações numéricas erradas |
| Camada 0 (enforcement) | ❌ inexistente — 9 regras candidatas em prosa |
| Camada 2 (escopo) | ❌ inexistente — nenhum path-scoped rule, nenhuma skill |
| Camada 3 (profundidade) | ⚠️ existe e é ótima, mas monolítica e sem gatilhos |
| Interop entre ferramentas | ❌ indireção invertida (AGENTS.md → CLAUDE.md) |
| Qualidade do conteúdo humano | ✅ **excelente** — denso em *porquê* e armadilhas reais |

A conclusão que importa: **o problema deste repositório não é falta de
documentação, é excesso de documentação na camada errada.** O conteúdo
não-derivável é de qualidade alta e rara (a seção de i18n é material de
referência). O que sobra é inventário que apodrece e regra que deveria ser hook.

---

## 8. O que foi feito

Executado na ordem abaixo, cada passo verificado pelo harness de preservação:

1. **Drift corrigido** — as 11 ocorrências dos 7 números errados saíram do
   `README.md` e do `AGENT-GUIDE.md`. Nenhuma foi *atualizada*: foram removidas,
   porque um número em prosa volta a apodrecer. A regra "nunca escreva contagens
   em prosa" entrou em `AGENTS.md` e nas *Conventions* de `docs/README.md`.
2. **`lint_hooks` entrou no `make ci`** (`scripts/ci_impact.exs` → `@full_checks`,
   agora 14 checks; os 14 testes do planejador de impacto seguem verdes).
   **`lint_bundle` ficou de fora e a razão está documentada**: ele está vermelho
   hoje — `app.js` 40.9kb acima do budget de 390kb, `space_canvas_hook` 106.8kb e
   `group_call_webrtc_hook` 73.1kb acima do budget de 50kb por chunk. Colocá-lo no
   gate quebraria o gate; escondê-lo manteria a mentira. Está na tabela
   "O que `make ci` NÃO roda" em `reference/ci-pipeline.md`.
3. **Indireção invertida** — `AGENTS.md` é o canônico (114 linhas); `CLAUDE.md`
   virou `@AGENTS.md` + 37 linhas específicas do Claude Code.
4. **Camada 0 criada** — `.claude/settings.json` com `permissions.deny` para
   `_build/`, `deps/`, `node_modules/`, assets compilados e `tmp/`; e o hook
   `PreToolUse` `scripts/hooks/guard_bash.py`, que bloqueia `git add -A`/`.`/`--all`,
   `make deploy-sun`, `git checkout <arquivo>` destrutivo, e commit/push com `main`
   atrás de `origin/main` ou sem fetch recente. 14 casos de teste, 14 passando.
5. **Camada 2 criada** — `.claude/rules/` com `paths:` para i18n, CSS/SVG, assets/JS,
   testes e help topics; `virtual.space/` ganhou gatilho via a skill
   `virtual-space-art`.
6. **`CLAUDE.md` encurtado** — 340 → 37 linhas. Cold start total 353 → 151 linhas.
7. **`AGENT-GUIDE.md` dividido** — 1139 → 470 linhas, com §6, §7, §8, §13, §17 e §18
   extraídos para `docs/guide/`. **Os números de seção foram preservados**, então
   toda referência `§N` existente continua válida; as que cruzam a fronteira nova
   passaram a nomear o arquivo.
8. **`docs/README.md` virou tabela de roteamento** com uma coluna **Read when** por
   linha — o gatilho, não só o ponteiro.

Nada apagou conhecimento. O único conteúdo que saiu foi o inventário derivável, as
contagens erradas e as linhas que pediam ao modelo o que o linter já faz — cada uma
listada em `agent-docs-removals.txt` com o motivo e o destino.

### O que ficou de fora, de propósito

- **`lint.bundle` continua vermelho.** Isto é uma dívida real de frontend, não de
  documentação, e não cabia resolver aqui: baixar o `app.js` para dentro do budget
  (ou revisar o budget conscientemente) é uma decisão de produto/performance.
- **Os três `reference/` em português** seguem em português. Terminologia
  inconsistente entre arquivos é um anti-padrão conhecido, mas traduzir conteúdo
  técnico correto tem risco maior que o ganho; fica como decisão sua.
- **`e2e/TEST_CATALOG.md`** (582 linhas, ~21.9K tokens) foi mantido inteiro. É o
  maior candidato a inventário que apodrece, mas os specs Playwright não carregam a
  semântica que ele guarda. Vale um `Last reviewed` vigiado, não uma exclusão.
