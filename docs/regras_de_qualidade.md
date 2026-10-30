# Regras de qualidade

**Ação em caso de falha (todas as regras):** a tabela recebe o status `DIVERGENTE` (ou `ERRO`, se houver exceção) na auditoria, o notebook levanta uma exceção, a tarefa do Job falha e as tarefas seguintes **não executam**. Os valores "informativos" (por exemplo, 14 pedidos sinalizados) aparecem na saída, mas **não** reprovam, porque são características conhecidas dos dados.

## Bronze

| Regra | Objetivo | Critério de aprovação |
|---|---|---|
| Contagem igual à origem | Garantir que nenhuma linha se perdeu nem duplicou | Linhas gravadas = valor de `CONTAGENS_ESPERADAS` (em `utils/config`) para cada uma das 9 tabelas |

## Silver (aplicadas a todas as tabelas, conforme o dicionário de cada uma)

| Regra | Objetivo | Critério |
|---|---|---|
| Contagem Bronze = Silver | Nenhuma linha se perde na transformação | Contagens iguais |
| Chave única | Evitar duplicidade | Zero chaves repetidas (a `geolocation` não tem chave natural e fica sem este teste) |
| Colunas obrigatórias | Chaves e campos essenciais preenchidos | Zero vazios |
| **Vazios Bronze = Silver** | Detectar conversão de tipo que falhou e virou vazio sem aviso | Mesma contagem de vazios antes e depois da conversão |

Regras de domínio por tabela:

| Tabela | Regra | Critério (violações esperadas) |
|---|---|---|
| `customers`, `sellers`, `geolocation` | `cep_com_5_digitos` | 0 |
| `customers`, `sellers`, `geolocation` | `estado_2_maiusculas` | 0 |
| `order_items` | `preco_nao_positivo`, `frete_negativo` | 0 |
| `order_payments` | `valor_negativo`, `tipo_fora_do_dominio` (`credit_card`, `boleto`, `voucher`, `debit_card`, `not_defined`) | 0 |
| `order_reviews` | `score_fora_de_1_a_5`, `resposta_antes_da_criacao` | 0 |
| `category_translation` | `nome_fora_do_padrao` | 0 |

## Gold

| Regra | Objetivo | Critério |
|---|---|---|
| Linhas esperadas | Fatos e dimensões com o tamanho correto | Igual à tabela de origem (ou 852 dias no calendário) |
| Chave única | Granularidade correta | Zero repetições |
| Colunas obrigatórias | Chaves e medidas preenchidas | Zero vazios |
| Integridade referencial | Todo item e pedido aponta para dimensões que existem | `item_sem_cliente`, `item_sem_vendedor`, `item_sem_produto`, `item_sem_data`, `pedido_sem_cliente` = 0 |
| `data_de_compra_fora_do_calendario` | Calendário cobre todos os pedidos | 0 |
| `centro_fora_do_brasil` | Nenhum centro de CEP fora do Brasil | 0 |
| `receita_fora_da_regra` | `valor_receita` coerente com `conta_na_receita` | 0 |
| `distancia_negativa` | Sanidade da fórmula | 0 |
| `nota_fora_de_1_a_5` | Domínio da nota | 0 |
| `atraso_em_pedido_sem_entrega_valida` | Atraso só existe com entrega válida | 0 |
| `mais_3_dias_sem_estar_apos_prazo` | Coerência entre as duas definições de atraso | 0 |

### Reconciliações (Gold)

| Reconciliação | Compara |
|---|---|
| `preco` | Soma na `fact_itens_pedido` x soma na Silver |
| `frete` | Idem |
| `receita_pedidos_vs_itens` | Receita da `fact_pedidos` x `valor_receita` da `fact_itens_pedido` |
| `valor_pago` | Pagamentos na `fact_pedidos` x Silver |
| `qtd_itens` | Itens somados nos pedidos x linhas da `fact_itens_pedido` |

Na Silver, a reconciliação dos totais de pagamento, preço e frete foi feita por consulta em [sql/02_validacao_silver_gold.sql](../sql/02_validacao_silver_gold.sql). Na Gold, ela é parte da validação automática.
