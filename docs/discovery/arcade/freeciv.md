# Freeciv

## Identity

| Campo | Valor |
|-------|-------|
| Nome | Freeciv (clone de Civilization) |
| Ano | 1996 (desenvolvimento contínuo) |
| Gênero | Estratégia 4X (turn-based) |
| Desenvolvedora | Freeciv community |
| Nossa ID | `freeciv` |
| Engine | Freeciv-web (HTML5/WebGL nativo — não é WASM) |

## Source & License

| Repo | Licença | Descrição |
|------|---------|-----------|
| [freeciv/freeciv-web](https://github.com/freeciv/freeciv-web) | GPL v2 (server) + AGPL v3 (web client) | Cliente web nativo com servidor Freeciv |
| [freeciv/freeciv](https://github.com/freeciv/freeciv) | GPL v2 | Engine/server base do Freeciv |

## Game Data

| Arquivo | Tamanho | Fonte | Status Legal |
|---------|---------|-------|-------------|
| Jogo completo | N/A (web app) | Incluído no projeto | **Livre** — 100% open-source |

Todos os assets (tilesets, mapas, civilizações, unidades) são open-source.
Nenhum dado proprietário necessário.

## Technology

- **Arquitetura**: Cliente HTML5/JavaScript + Servidor C (Freeciv engine)
- **Não é WASM**: É uma aplicação web nativa com client-server
- **Demo online**: https://www.freecivweb.com/
- **Rendering**: HTML5 Canvas (2D) ou WebGL (3D)
- **Backend**: Servidor C (freeciv-server) precisa rodar como processo separado
- **Deploy**: Docker Compose (nginx + tomcat + freeciv-server + PostgreSQL)
- **Áudio**: Web Audio API
- **RAM (client)**: ~100-200 MB
- **RAM (server)**: ~200-500 MB por partida

## Integration Plan

**Complexidade: Native web app (arquitetura fundamentalmente diferente)**

Freeciv-web NÃO é um jogo estático no iframe. Requer um servidor backend rodando.
Isso muda completamente o padrão de integração.

### Opção A: Self-hosted via Docker (recomendada)
1. Deploy Freeciv-web stack via Docker Compose no servidor
2. Configurar reverse proxy (nginx) para rotear `/arcade/freeciv/` para o container
3. O iframe aponta para o servidor Freeciv-web
4. Requer recursos de servidor significativos

### Opção B: Iframe para instância externa
1. Apontar iframe para freecivweb.com (ou self-hosted instance)
2. Mais simples mas dependente de serviço externo
3. Problemas de CORS, latência, controle

### Novos Módulos
- Não segue o padrão `mix arcade.build` — precisa de deploy de infraestrutura
- Ansible playbook para deploy do Docker stack
- Entry no `Arcade.Catalog` com `engine: :external` ou `:web_app`
- Ícone `icon_game_freeciv` em `Icons.Games`

### Desafios
- **Servidor**: Requer processo backend persistente (não é static file serving)
- **Recursos**: Cada partida consome RAM do servidor
- **Multiplayer**: O jogo é inherentemente multiplayer (vs AI ou vs jogadores)
- **Sessão**: Partidas duram horas — como lidar com timeout do solo session?
- **Complexidade de deploy**: Docker + nginx + PostgreSQL + Java (Tomcat)

## Current Status

- **Freeciv-web**: Ativo, mantido, Docker deploy funcional
- **Maturidade**: Alta — projeto maduro com anos de desenvolvimento
- **Prioridade**: Média — jogo excelente mas integração complexa (servidor backend)
- **Recomendação**: Avaliar se vale o overhead de infraestrutura. Se sim, Freeciv é um dos jogos de estratégia mais completos disponíveis open-source. Considerar como projeto futuro após os jogos static-file estarem estabelecidos.
