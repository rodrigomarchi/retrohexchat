# Plano: espaço virtual estilo Zelda 8-bit

Status: auditado contra o codebase em 2026-07-05 (3 varreduras: domínio, web,
JS); apontamentos inválidos corrigidos; ambiguidades fechadas com o usuário
(decisões 18–21). Pronto para o loop de implementação — ver `10-prompt-loop.md`
e `PROGRESS.md`. Nenhuma implementação feita ainda.

## Objetivo

Criar um novo tipo de experiência multiplayer: um escritório virtual estilo
Gather, mas apresentado como um mundo de fantasia inspirado em RPGs 8-bit de
topo. O espaço deve suportar até 20 usuários no mesmo link e, diferente dos
jogos P2P atuais, o estado compartilhado deve passar pelo servidor.

O cliente do mundo deve ser 100% JavaScript autoral, seguindo o padrão local de
engine modular dos jogos atuais. O servidor deve seguir a arquitetura Phoenix /
BEAM existente do projeto: contexto de domínio, tabela pequena para auditoria,
Registry, DynamicSupervisor e um GenServer por sessão ativa.

## Documentos

- `00-visao-geral.md`: decisão de produto e modelo mental do espaço.
- `01-arquitetura-servidor.md`: contexto, schema, GenServer e ciclo de vida.
- `02-protocolo-runtime-js.md`: eventos, validação de movimento e cliente JS.
- `03-mapa-renderizacao-assets.md`: formato de mapa, tiles, colisão e estética.
- `04-integracao-chat-produto.md`: slash command, menu de contexto, cards e rota.
- `05-plano-implementacao.md`: fases, testes, riscos e decisões abertas.
- `06-ambiguidades-fechadas.md`: ambiguidades encontradas, fontes consultadas e
  decisões fechadas.
- `07-decisoes-produto-usuario.md`: respostas do usuário para escopo, comando,
  admissão, mapas e interações da V1.
- `08-referencias-locais.md`: checkouts locais dos projetos de referência e onde
  o agente de implementação deve pesquisar dúvidas.
- `09-mapa-de-testes.md`: inventário TDD — os testes de cada fase, escritos
  antes da implementação.
- `10-prompt-loop.md`: prompt do loop de implementação (rodar até concluir).
- `PROGRESS.md`: arquivo vivo do loop — estado, histórico de iterações e
  aprendizados.

## Recomendação curta

Eu modelaria como `RetroHexChat.VirtualSpace`, com rota `/space/:token`, comando
`/space [#canal-alvo] [nome-do-space] ttl=2h`, card de convite no canal de chat,
`SpaceLive` como shell e `SpaceChannel` como transporte realtime do runtime.

O mundo roda em um `VirtualSpace.SessionServer` por token vinculado ao canal de
origem. O cliente JS manda intenção de input, não posição final livre. O servidor
valida registro/identificação, permissão no canal, colisão, limite de velocidade,
capacidade configurável e publica snapshots/deltas via Channel. O cliente
renderiza com Canvas 2D, prevê o movimento local para sensação responsiva e
corrige suavemente quando chega a posição oficial.

## Referências lidas

- WorkAdventure: mapas em JSON/Tiled, tiles 32x32, camadas, colisão por
  propriedade e zonas especiais.
- Gather Clone: sessão em memória por espaço, índice por posição, broadcast por
  socket, movimento em tile e camada de vídeo separada da movimentação.

Essas referências informam decisões de produto e arquitetura, mas a proposta
abaixo evita copiar código ou trazer engines externas.

Os repositórios foram clonados em `~/src` para consulta local. Veja
`08-referencias-locais.md`.
