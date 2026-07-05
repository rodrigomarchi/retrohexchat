# Decisões de produto do usuário

Status: respostas do usuário incorporadas ao plano. Nenhuma implementação feita
ainda.

## Escopo fechado

O espaço virtual nasce somente de um canal de chat. Ele não nasce de PM, aba
Status, lobby P2P ou tela genérica. O card do espaço fica no canal onde foi
iniciado ou no `#canal-alvo` informado no comando.

Comando alvo:

```text
/space [#canal-alvo] [nome-do-space] ttl=[2h default]
```

Regras:

- se `#canal-alvo` não vier, usar o canal ativo;
- se vier, o usuário precisa ter permissão para postar naquele canal;
- comando em PM/Status deve ser recusado, mesmo que informe um canal alvo;
- `ttl` default é 2 horas;
- TTL mínimo/máximo deve vir de configuração/admin para evitar links longos sem
  controle.

## Admissão

Entrada nunca aceita guests. Criar e entrar exigem usuário registrado e
identificado.

O espaço pertence a um canal:

- em canal público, qualquer usuário registrado e identificado pode entrar pelo
  link;
- em canal privado, invite-only ou com política restritiva, somente usuários que
  satisfaçam a política de membership/acesso do canal podem entrar;
- o `join_token` assinado por `SpaceLive` deve incluir `space_token`,
  `channel_name`, `user_id`, `nickname` e validade curta;
- `SpaceChannel.join/3` deve validar o `join_token` e chamar a policy do domínio
  antes de entrar no `SessionServer`.

## Capacidade e erro

O limite padrão continua 20 participantes por espaço, mas não é hardcoded. Deve
ser configurável no painel de admin do servidor.

Quando o espaço estiver cheio, a entrada é recusada com erro simples. Não há fila,
sala de espera ou retry automático na V1.

## Expiração e encerramento

O espaço expira por TTL e também pode ser encerrado manualmente pelo criador. O
TTL default do comando é 2 horas.

Atividade dentro do espaço não renova o TTL. Se o criador fechar manualmente, o
card no canal e todos os clientes conectados devem receber estado terminal.

## Mapas

Teremos quatro mapas no total, mas o primeiro mapa deve ser completo e servir de
playbook para os próximos.

Primeiro mapa: `tavern_cafe_v1`, uma taverna-cafe de fantasia inspirada em uma
cafeteria urbana movimentada, sem copiar marca, trade dress, nomes ou assets.

O primeiro mapa deve definir:

- gramática de tiles;
- paleta e escala;
- colisão;
- zonas/salas;
- cadeiras e mesas;
- quadros interativos;
- fluxo de spawn;
- playbook para criar os outros três mapas.

## Interações obrigatórias da V1

A V1 não é só MVP mínimo. Ela deve nascer como feature completa.

Obrigatório:

- andar com colisão em paredes, móveis, balcões, mesas, cadeiras e objetos;
- chat textual global do espaço;
- balão acima do avatar para mensagens recentes;
- sentar em cadeira;
- entrar em sala/zona;
- interagir com quadro;
- abrir modal de imagem ao clicar/interagir com quadro;
- persistir posição do usuário enquanto a sessão estiver ativa;
- poderes do criador: expulsar usuário, fechar espaço, trocar mapa e mutar chat.

Áudio fica fora da V1 visual/textual, mas o desenho deve reservar proximidade
para áudio no futuro.

## Visual

O estilo é apenas inspirado em RPGs 8-bit top-down antigos. O mapa deve ser
autoral, com liberdade visual maior que uma reprodução fiel de NES Zelda.
