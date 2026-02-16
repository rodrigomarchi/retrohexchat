# Transferência de Arquivos

## DataChannel, Chunking e Protocolo

---

## I. Visão Geral

A transferência de arquivos via WebRTC DataChannel é o equivalente moderno
do `DCC SEND` do mIRC. A diferença fundamental: criptografia ponta-a-ponta
obrigatória, travessia de NAT automática, e interface no navegador sem
precisar de software instalado.

O fluxo é simples:
1. Peer A seleciona arquivo no browser (drag-and-drop ou file picker)
2. Metadata é enviada ao Peer B via DataChannel (nome, tamanho, tipo)
3. Peer B aceita a transferência
4. Arquivo é enviado em chunks de 64KB via DataChannel
5. Peer B remonta os chunks e oferece download

Zero bytes passam pelo servidor.

## II. DataChannel para Arquivos

### Configuração do DataChannel

```javascript
const fileChannel = peerConnection.createDataChannel("file-transfer", {
  ordered: true,          // Entrega em ordem (essencial para arquivos)
  maxRetransmits: null,   // Reliable mode (retransmite até entregar)
});

// Buffer threshold para controle de fluxo
fileChannel.bufferedAmountLowThreshold = 65536; // 64KB
```

### Por que DataChannel e não fetch/upload?

| Aspecto | DataChannel (P2P) | Upload via servidor |
|---------|-------------------|---------------------|
| Bandwidth | Usa conexão direta | Passa pelo servidor |
| Latência | Mínima | Upload + download |
| Criptografia | E2E automática | Depende do servidor |
| Custo para operador | Zero | Proporcional ao tráfego |
| Tamanho máximo | Ilimitado¹ | Limitado pelo servidor |
| Offline do servidor | Funciona (sessão já ativa) | Falha |

¹ DataChannel não tem limite de tamanho — o chunking permite qualquer arquivo.

## III. Protocolo de Transferência

O protocolo usa o DataChannel para trocar mensagens JSON de controle e
dados binários (ArrayBuffer) para os chunks.

### Mensagens do protocolo

```
┌─────────────────────────────────────────────────────────┐
│  Fase 1: Metadata                                       │
│                                                         │
│  Sender → Receiver:                                     │
│  {                                                      │
│    "type": "file-offer",                                │
│    "id": "uuid-do-arquivo",                             │
│    "name": "relatorio-2026.pdf",                        │
│    "size": 2516582,                                     │
│    "mime": "application/pdf",                            │
│    "chunks": 39                                          │
│  }                                                      │
│                                                         │
│  Receiver → Sender:                                     │
│  { "type": "file-accept", "id": "uuid-do-arquivo" }    │
│  — ou —                                                 │
│  { "type": "file-reject", "id": "uuid-do-arquivo" }    │
├─────────────────────────────────────────────────────────┤
│  Fase 2: Transferência (após aceite)                    │
│                                                         │
│  Sender → Receiver (binário):                           │
│  [chunk-header: 4 bytes index][64KB de dados]           │
│                                                         │
│  Receiver → Sender (a cada N chunks):                   │
│  { "type": "file-ack", "id": "...", "chunk": 15 }      │
├─────────────────────────────────────────────────────────┤
│  Fase 3: Conclusão                                      │
│                                                         │
│  Sender → Receiver:                                     │
│  { "type": "file-complete", "id": "...",                │
│    "checksum": "sha256-hash" }                          │
│                                                         │
│  Receiver → Sender:                                     │
│  { "type": "file-verified", "id": "..." }               │
│  — ou —                                                 │
│  { "type": "file-error", "id": "...",                   │
│    "reason": "checksum-mismatch" }                      │
└─────────────────────────────────────────────────────────┘
```

### Diagrama de sequência

```
  Sender                   DataChannel                  Receiver
    │                          │                          │
    │── file-offer ────────────▶── file-offer ────────────▶
    │                          │                          │
    │                          │◀── file-accept ──────────│
    │◀── file-accept ──────────│                          │
    │                          │                          │
    │── [chunk 0: 64KB] ───────▶── [chunk 0: 64KB] ──────▶
    │── [chunk 1: 64KB] ───────▶── [chunk 1: 64KB] ──────▶
    │── [chunk 2: 64KB] ───────▶── [chunk 2: 64KB] ──────▶
    │   ...                    │   ...                    │
    │                          │◀── file-ack (chunk 10) ──│
    │◀── file-ack (chunk 10) ──│                          │
    │   ...                    │   ...                    │
    │── [chunk N: restante] ───▶── [chunk N: restante] ──▶
    │                          │                          │
    │── file-complete ─────────▶── file-complete ─────────▶
    │                          │                          │
    │                          │◀── file-verified ────────│
    │◀── file-verified ────────│                          │
```

## IV. Chunking — 64KB por Chunk

### Por que 64KB?

- **Limite do DataChannel**: mensagens > 256KB podem falhar em alguns browsers
- **Controle de fluxo**: chunks pequenos permitem backpressure eficiente
- **Progresso granular**: atualização visual a cada 64KB
- **Retry eficiente**: retransmitir 64KB é barato

### Implementação do sender

```javascript
const CHUNK_SIZE = 64 * 1024; // 64KB

async function sendFile(dataChannel, file) {
  const fileId = crypto.randomUUID();
  const totalChunks = Math.ceil(file.size / CHUNK_SIZE);

  // Fase 1: Metadata
  dataChannel.send(JSON.stringify({
    type: "file-offer",
    id: fileId,
    name: file.name,
    size: file.size,
    mime: file.type,
    chunks: totalChunks,
  }));

  // Aguardar aceite...

  // Fase 2: Chunks
  const reader = file.stream().getReader();
  let chunkIndex = 0;
  let offset = 0;

  while (offset < file.size) {
    // Backpressure: esperar se buffer cheio
    if (dataChannel.bufferedAmount > CHUNK_SIZE * 4) {
      await waitForBufferDrain(dataChannel);
    }

    const slice = file.slice(offset, offset + CHUNK_SIZE);
    const buffer = await slice.arrayBuffer();

    // Header: 4 bytes com índice do chunk
    const header = new Uint32Array([chunkIndex]);
    const chunk = new Uint8Array(header.byteLength + buffer.byteLength);
    chunk.set(new Uint8Array(header.buffer), 0);
    chunk.set(new Uint8Array(buffer), header.byteLength);

    dataChannel.send(chunk.buffer);
    offset += CHUNK_SIZE;
    chunkIndex++;

    // Callback de progresso
    onProgress(offset / file.size);
  }

  // Fase 3: Checksum
  const checksum = await computeSHA256(file);
  dataChannel.send(JSON.stringify({
    type: "file-complete",
    id: fileId,
    checksum: checksum,
  }));
}
```

### Implementação do receiver

```javascript
function receiveFile(dataChannel) {
  const chunks = [];
  let metadata = null;

  dataChannel.onmessage = (event) => {
    if (typeof event.data === "string") {
      const msg = JSON.parse(event.data);

      if (msg.type === "file-offer") {
        metadata = msg;
        // Mostrar confirmação ao usuário...
      }

      if (msg.type === "file-complete") {
        // Remontar arquivo
        const blob = new Blob(chunks, { type: metadata.mime });
        // Verificar checksum...
        // Oferecer download
        downloadBlob(blob, metadata.name);
      }
    } else {
      // Dados binários — chunk
      const view = new DataView(event.data);
      const chunkIndex = view.getUint32(0);
      const data = event.data.slice(4); // Pular header

      chunks[chunkIndex] = data;
      onProgress(chunks.filter(Boolean).length / metadata.chunks);
    }
  };
}
```

## V. Seleção de Arquivo no Browser

### File picker (botão)

```javascript
const input = document.createElement("input");
input.type = "file";
input.onchange = (e) => {
  const file = e.target.files[0];
  sendFile(dataChannel, file);
};
input.click();
```

### Drag-and-drop

```javascript
dropZone.addEventListener("dragover", (e) => {
  e.preventDefault();
  dropZone.classList.add("drag-over");
});

dropZone.addEventListener("drop", (e) => {
  e.preventDefault();
  dropZone.classList.remove("drag-over");
  const file = e.dataTransfer.files[0];
  sendFile(dataChannel, file);
});
```

A UI do lobby terá ambas as opções: botão "Enviar Arquivo" e área de
drag-and-drop (o chat area inteiro pode servir como drop zone).

## VI. Barra de Progresso e Controles

### UI durante transferência

```
┌───────────────────────────────────────────────────┐
│ 📁 Transferência de Arquivo                       │
│                                                   │
│  relatorio-2026.pdf (2.4 MB)                      │
│  ████████████████░░░░░░░░  67%  1.6/2.4 MB        │
│  Velocidade: 450 KB/s  ETA: 2s                    │
│                                                   │
│  [Cancelar]                                       │
└───────────────────────────────────────────────────┘
```

### Cálculo de velocidade e ETA

```javascript
class TransferProgress {
  constructor(totalSize) {
    this.totalSize = totalSize;
    this.transferred = 0;
    this.startTime = Date.now();
    this.samples = []; // Últimas 10 amostras para média móvel
  }

  update(bytesReceived) {
    this.transferred += bytesReceived;
    const now = Date.now();
    this.samples.push({ bytes: bytesReceived, time: now });

    // Manter apenas últimas 10 amostras
    if (this.samples.length > 10) this.samples.shift();
  }

  get speed() {
    if (this.samples.length < 2) return 0;
    const first = this.samples[0];
    const last = this.samples[this.samples.length - 1];
    const bytes = this.samples.reduce((sum, s) => sum + s.bytes, 0);
    const seconds = (last.time - first.time) / 1000;
    return seconds > 0 ? bytes / seconds : 0;
  }

  get eta() {
    const remaining = this.totalSize - this.transferred;
    return this.speed > 0 ? remaining / this.speed : Infinity;
  }

  get percentage() {
    return (this.transferred / this.totalSize) * 100;
  }
}
```

## VII. Cancelamento e Retry

### Cancelamento

Qualquer peer pode cancelar a transferência a qualquer momento:

```javascript
// Enviar mensagem de cancelamento
dataChannel.send(JSON.stringify({
  type: "file-cancel",
  id: fileId,
  reason: "user-cancelled"
}));

// Limpar estado local
chunks.length = 0;
```

### Retry (reconexão)

Se a conexão WebRTC cair durante transferência:

1. **Retry automático de handshake** (3 tentativas, ver `01-fluxo-sessao.md`)
2. Se reconectar, o receiver informa quais chunks já tem:
   ```json
   { "type": "file-resume", "id": "...", "have_chunks": [0, 1, 2, 3, 4] }
   ```
3. Sender envia apenas os chunks faltantes
4. Se retry falhar, notificar ambos os peers

## VIII. Limites e Restrições

| Parâmetro | Limite | Justificativa |
|-----------|--------|---------------|
| Tamanho máximo | 500 MB | Evita sessões infinitas; DataChannel pode ficar instável |
| Tipos bloqueados | `.exe`, `.bat`, `.cmd`, `.scr` | Segurança básica contra malware |
| Transferências simultâneas | 1 por sessão | Simplicidade; múltiplas sessões para múltiplos arquivos |
| Timeout por chunk | 30 seg | Se um chunk não for confirmado, considerar erro |

Esses limites são configuráveis pelo operador do servidor via variáveis de
ambiente. O default é conservador.

## IX. Comparação com DCC do mIRC

| Aspecto | DCC (mIRC) | P2P (RetroHexChat) |
|---------|------------|---------------------|
| Conexão | TCP direto (IP:porta) | WebRTC DataChannel |
| NAT traversal | Nenhum (requeria port forward) | ICE + STUN + TURN automático |
| Criptografia | Nenhuma | DTLS obrigatório |
| Exposição de IP | IP exposto no CTCP | IP pode ser escondido via TURN |
| UI de progresso | Básica (% e velocidade) | Rica (%, velocidade, ETA, drag-drop) |
| Resumo | DCC RESUME (parcial suporte) | Resume via chunks recebidos |
| Limite de tamanho | 4GB (32-bit offset) | 500MB (configurável) |
| Integração | Janela separada no mIRC | Lobby integrado no browser |
| Aceite | Unilateral (receptor aceita) | Bilateral (ambos confirmam) |
