# Contributing to Retro Hex Chat

Obrigado por considerar contribuir com o Retro Hex Chat! Este guia vai te ajudar a começar.

## Como reportar bugs

1. Verifique se o bug já não foi reportado em [Issues](https://github.com/rodrigomarchi/retro_hex_chat/issues)
2. Se não encontrar, abra uma nova Issue com:
   - Descrição clara do problema
   - Passos para reproduzir
   - Comportamento esperado vs. observado
   - Versão do Elixir/OTP e sistema operacional

## Como sugerir features

Abra uma Issue com a label `enhancement` descrevendo:
- O problema que a feature resolve
- Como você imagina a solução
- Exemplos de uso

## Desenvolvimento local

### Setup

```bash
git clone https://github.com/rodrigomarchi/retro_hex_chat.git
cd retro_hex_chat
make setup
make server  # http://localhost:4000
```

### Requisitos

- Elixir 1.17+
- OTP 27+
- PostgreSQL 16+
- Node.js 20+

### Workflow de PR

1. Fork o repositório
2. Atualize sua base antes de criar a branch:

```bash
git fetch origin
git checkout main
git pull --ff-only origin main
git status --short --branch
```

3. Crie uma branch a partir de `main`: `git checkout -b minha-feature`
4. Faça suas mudanças
5. Rode os testes e linters:

```bash
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix test --include e2e
mix dialyzer
make lint.js
make lint.css
npm test --prefix apps/retro_hex_chat_web/assets
```

6. Commit com mensagem descritiva
7. Abra um Pull Request

### Push direto na `main`

Antes de qualquer commit ou push direto para `main`, confira o remoto e faça pull
com fast-forward:

```bash
git fetch origin
git status --short --branch
git pull --ff-only origin main
```

Se houver mudanças locais ainda não commitadas, use `git pull --ff-only --autostash origin main`.
Só faça `git push origin main` depois de confirmar que a branch local está atualizada.

### Code style

- **Elixir**: `mix format` (enforced). Toda função pública precisa de `@spec`.
- **JavaScript**: ESLint + Prettier (`make lint.js`). Auto-fix com `make lint.js.fix`.
- **CSS**: Sem inline styles nos templates (`make lint.css`).
- **Testes**: TDD. Tags: `@tag :unit`, `@tag :integration`, `@tag :liveview`, `@tag :e2e`.

### Estrutura do projeto

```
apps/
├── retro_hex_chat/           # Domain (Elixir puro)
└── retro_hex_chat_web/       # Web (Phoenix + LiveView)
```

O domínio (`retro_hex_chat`) não depende de Phoenix. A camada web (`retro_hex_chat_web`) é thin — delega para os contextos de domínio.

## Código de conduta

Seja respeitoso. Contribuições construtivas são bem-vindas independente de experiência, gênero, orientação, etnia, ou qualquer outra característica pessoal.
