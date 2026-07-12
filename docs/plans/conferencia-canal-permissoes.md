# Conferencia de canal — matriz de permissoes

> Contrato de autoridade para a conferencia de canal. A conferencia herda a
> hierarquia do canal; nao existe papel separado de host/moderador da chamada.

## Papeis

| Papel no canal | Rank | Descricao |
|---|---:|---|
| `owner` | 4 | Dono do canal. Pode moderar qualquer participante abaixo de owner. |
| `operator` | 3 | Operador. Pode moderar half-op, voiced e membros comuns. |
| `half_operator` | 2 | Half-op. Pode moderar voiced e membros comuns. |
| `voiced` | 1 | Usuario com voz. Nao modera a conferencia. |
| `regular` | 0 | Membro comum do canal. Nao modera a conferencia. |
| `guest` | - | Usuario nao registrado/nao identificado. Nao usa conferencia. |

## Regra base

- Criar ou entrar na conferencia exige usuario registrado e presente no canal.
- Encerrar a sala exige `half_operator` ou superior.
- Travar ou destravar a sala exige `half_operator` ou superior.
- Entrar em conferencia travada e permitido para `half_operator` ou superior,
  para que moderadores consigam destravar/moderar. Usuarios abaixo disso
  continuam no canal, mas nao entram na chamada travada.
- Levantar/baixar a propria mao e permitido para qualquer participante da
  conferencia.
- Liberar fala de outro participante exige `half_operator` ou superior e rank
  maior que o alvo; a acao desmuta o alvo e baixa a mao.
- Parar/bloquear ou liberar screen share de outro participante exige
  `half_operator` ou superior e rank maior que o alvo.
- Moderar outro participante exige `half_operator` ou superior e rank maior que
  o alvo.
- A UI deve esconder acoes que o servidor recusaria por policy.
- A policy do servidor continua sendo a autoridade final.

## Matriz de acoes

| Acao | owner | operator | half-op | voiced | member | guest |
|---|---|---|---|---|---|---|
| Criar conferencia no canal | sim | sim | sim | sim | sim | nao |
| Entrar em conferencia aberta | sim | sim | sim | sim | sim | nao |
| Entrar em conferencia travada | sim | sim | sim | nao | nao | nao |
| Encerrar conferencia | sim | sim | sim | nao | nao | nao |
| Travar/destravar conferencia | sim | sim | sim | nao | nao | nao |
| Levantar/baixar propria mao | sim | sim | sim | sim | sim | nao |
| Liberar fala de outro participante | contra rank menor | contra rank menor | contra rank menor | nao | nao | nao |
| Mutar audio remoto | contra rank menor | contra rank menor | contra rank menor | nao | nao | nao |
| Desligar camera remota | contra rank menor | contra rank menor | contra rank menor | nao | nao | nao |
| Parar/bloquear screen share remoto | contra rank menor | contra rank menor | contra rank menor | nao | nao | nao |
| Liberar screen share remoto | contra rank menor | contra rank menor | contra rank menor | nao | nao | nao |
| Remover/banir participante | contra rank menor | contra rank menor | contra rank menor | nao | nao | nao |

## UI esperada

- Botao de encerrar sala aparece somente para `owner`, `operator` e
  `half_operator`.
- Botao de travar/destravar sala aparece somente para `owner`, `operator` e
  `half_operator`.
- Botao de levantar/baixar mao aparece para todo participante local.
- Fila de pedidos de fala aparece quando ha participantes com mao levantada.
- Botao de liberar fala aparece para moderadores somente em alvos que a policy
  permite moderar.
- Botoes de mute remoto, camera-off remoto e kick aparecem por participante
  somente quando o papel atual pode moderar aquele alvo especifico.
- O botao de camera-off aparece quando a camera do alvo esta ligada ou bloqueada
  por moderador; nao serve para ligar camera que o proprio usuario desligou.
- O botao de screen moderation aparece quando o alvo esta compartilhando tela ou
  bloqueado por moderador; liberar remove apenas o bloqueio de moderacao.
- Nenhuma acao de moderacao aparece para `voiced`, `regular` ou usuario sem
  `channel_role_snapshot`.
- Nenhum participante pode moderar a si mesmo.

## Cobertura

- `RetroHexChat.GroupCall.PolicyTest` valida create/join/close/kick/mute remoto
  por papel.
- `RetroHexChat.GroupCall.RuntimeTest` valida bloqueios de audio, video e
  screen share impostos pelo servidor.
- `RetroHexChatWeb.ChatLive.GroupCallFlowTest` valida que a janela de
  conferencia esconde os botoes conforme a matriz.
