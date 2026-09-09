# Envio de Pedidos Nodal → Gescom (PDA_PEDIDOS)

Documento gerado a partir dos mapeamentos configurados em `nodal` (org `perestrelo-cunha`).
Adapter: **Firebird** · Tabela alvo: `PDA_PEDIDOS` · Esquema flat (cabeçalho repetido em cada linha).

Código de referência:
- `app/services/erp/order_push_service.rb` — orquestração (idempotência, transições de estado)
- `app/services/erp/adapters/firebird_adapter.rb#push_order` — SQL de inserção
- `app/services/erp/adapters/firebird_adapter.rb#find_existing_pedido` — SQL de consulta

---

## 1. Mapeamento de colunas

### Campos do pedido (Nodal → Gescom)

| Campo Nodal       | Coluna Gescom   | Tipo     | Notas                              |
|-------------------|-----------------|----------|------------------------------------|
| Order Number      | `PEDIDO`        | integer  | Atribuído pelo trigger no INSERT   |
| Line Number       | `PEDIDO_LINHA`  | integer  | Atribuído pelo trigger no INSERT   |
| Customer ID       | `CLIENTE`       | integer  | `external_id` do cliente Nodal     |
| Product Code      | `CODIGO`        | string   | SKU/external_id da variante        |
| Quantity          | `QUANTIDADE`    | float    |                                    |
| Unit Price        | `PRECO`         | float    | Preço **líquido** unitário          |
| Delivery Date     | `DT_ENTREGA`    | string   | ISO `YYYY-MM-DD`                   |
| Notes             | `OBSERVACOES`   | string   | Truncado a 255 chars               |
| Idempotency Key   | `OBSERVACOES2`  | string   | `NODAL:<order_number>` — chave única do Nodal, usada para evitar duplicados |
| Location          | `LOCAL_ID`      | string   |                                    |

### Valores fixos (preenchidos em todas as linhas)

| Coluna Gescom  | Valor              |
|----------------|--------------------|
| `UTILIZADOR`   | `catalogo online`  |
| `VENDEDOR`     | `6`                |
| `ARMAZEM`      | `1`                |
| `ESTADO`       | `P`                |
| `BCI`          | `N`                |
| `AVISOS`       | `0`                |
| `LOTE`         | `NODAL`            |
| `MARCA`        | `NODAL`            |
| `LOCAL_ID`     | `SEDE`             |
| `PROCESSADO`   | `N`                |

> `LOCAL_ID` aparece nas duas listas: se o pedido Nodal trouxer `location_id`, esse valor prevalece; senão usa-se `SEDE` por defeito.

---

## 2. Query de consulta (idempotência + captura de `PEDIDO`)

Usada duas vezes:
1. **Antes** do INSERT — para detectar pedidos já enviados (idempotência).
2. **Depois do INSERT da primeira linha** — para apanhar o `PEDIDO` que o trigger atribuiu, e reutilizá-lo nas linhas seguintes.

```sql
SELECT PEDIDO
FROM PDA_PEDIDOS
WHERE OBSERVACOES2 = ?
ORDER BY PEDIDO DESC;
```

Bind variable (`?`): chave de idempotência no formato `NODAL:<order_number>`, por exemplo:

```
NODAL:NOD-2026-0123
```

A primeira row devolvida é o número do pedido Gescom (`PEDIDO`).
Se não devolver nada antes do INSERT → o pedido ainda não foi enviado, prossegue.
Se devolver algo antes do INSERT → o pedido já foi enviado, devolve esse `PEDIDO` e não insere de novo.

---

## 3. Query de inserção (uma row por linha do pedido)

Todas as linhas vão dentro de **uma transação**. A primeira linha entra com `PEDIDO = 0` para que o trigger Gescom atribua o número; as seguintes reutilizam o `PEDIDO` capturado na query de consulta.

### Forma genérica

```sql
INSERT INTO PDA_PEDIDOS (
  -- Cabeçalho (igual em todas as linhas do pedido)
  CLIENTE, DT_ENTREGA, OBSERVACOES, OBSERVACOES2, LOCAL_ID,
  -- Linha
  CODIGO, QUANTIDADE, PRECO,
  -- Valores estáticos
  UTILIZADOR, VENDEDOR, ARMAZEM, ESTADO, BCI, AVISOS, LOTE, MARCA, PROCESSADO,
  -- Atribuídos pelo trigger (passamos 0)
  PEDIDO, PEDIDO_LINHA
) VALUES (
  ?, ?, ?, ?, ?,
  ?, ?, ?,
  'catalogo online', 6, 1, 'P', 'N', 0, 'NODAL', 'NODAL', 'N',
  0, 0
);
```

### Exemplo concreto — pedido com 2 linhas

Cliente Gescom `146`, entrega `2026-01-24`, nota `"Não é para enviar, eu entrego"`,
referência Nodal `NOD-2026-0123`, com dois artigos: `PAL0570` (1 × 136.00 €) e `PAL0571` (3 × 80.00 €).

**Passo 1 — Verificar se já existe (idempotência):**

```sql
SELECT PEDIDO
FROM PDA_PEDIDOS
WHERE OBSERVACOES2 = 'NODAL:NOD-2026-0123'
ORDER BY PEDIDO DESC;
-- → 0 rows: prosseguir para o INSERT
```

**Passo 2 — Inserir a primeira linha (PEDIDO=0, trigger atribui):**

```sql
INSERT INTO PDA_PEDIDOS (
  CLIENTE, DT_ENTREGA, OBSERVACOES, OBSERVACOES2, LOCAL_ID,
  CODIGO, QUANTIDADE, PRECO,
  UTILIZADOR, VENDEDOR, ARMAZEM, ESTADO, BCI, AVISOS, LOTE, MARCA, PROCESSADO,
  PEDIDO, PEDIDO_LINHA
) VALUES (
  146, '2026-01-24', 'Não é para enviar, eu entrego', 'NODAL:NOD-2026-0123', 'SEDE',
  'PAL0570', 1.0, 136.0,
  'catalogo online', 6, 1, 'P', 'N', 0, 'NODAL', 'NODAL', 'N',
  0, 0
);
```

**Passo 3 — Apanhar o `PEDIDO` que o trigger atribuiu:**

```sql
SELECT PEDIDO
FROM PDA_PEDIDOS
WHERE OBSERVACOES2 = 'NODAL:NOD-2026-0123'
ORDER BY PEDIDO DESC;
-- → ex.: PEDIDO = 4287
```

**Passo 4 — Inserir a segunda linha com o PEDIDO capturado:**

```sql
INSERT INTO PDA_PEDIDOS (
  CLIENTE, DT_ENTREGA, OBSERVACOES, OBSERVACOES2, LOCAL_ID,
  CODIGO, QUANTIDADE, PRECO,
  UTILIZADOR, VENDEDOR, ARMAZEM, ESTADO, BCI, AVISOS, LOTE, MARCA, PROCESSADO,
  PEDIDO, PEDIDO_LINHA
) VALUES (
  146, '2026-01-24', 'Não é para enviar, eu entrego', 'NODAL:NOD-2026-0123', 'SEDE',
  'PAL0571', 3.0, 80.0,
  'catalogo online', 6, 1, 'P', 'N', 0, 'NODAL', 'NODAL', 'N',
  4287, 0
);
```

`COMMIT` no fim.

---

## 4. Pressupostos do lado Gescom

Estes três pontos têm de ser garantidos pelo trigger / generator da `PDA_PEDIDOS`:

1. **`PEDIDO`** — quando recebe `0` num INSERT, o trigger atribui o próximo número da sequência Gescom.
2. **`PEDIDO_LINHA`** — o Nodal envia sempre `0`; o trigger é responsável por numerar a linha dentro do mesmo `PEDIDO` (1, 2, 3…).
3. **`OBSERVACOES2`** — não pode ser usada para mais nada do lado Gescom; o Nodal escreve aqui a chave única `NODAL:<order_number>` que serve para detectar reenvios. Se for sobrescrita do lado Gescom, a idempotência deixa de funcionar.

Se algum destes pontos não estiver coberto, é preciso ajustar do lado Gescom ou rever o mapeamento na BO Nodal (`/bo/erp_settings`).

---

## 5. Tratamento de erros

- Todo o pedido vai numa transação Firebird — se qualquer linha falhar, faz-se rollback e nenhuma linha fica gravada.
- Erros são guardados em `orders.sync_error` no Nodal e o estado passa a `failed`.
- Reenvio: o Nodal usa o `OBSERVACOES2` para garantir que um pedido nunca é inserido duas vezes — pode-se tentar enviar várias vezes com segurança.
