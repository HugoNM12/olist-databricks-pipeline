# Dicionário de dados

## Convenções

- **Bronze:** mesmos nomes e colunas dos CSVs, **todas como texto**, mais `_arquivo_origem` e `_data_ingestao` (dados de controle, com prefixo `_`).
- **Silver:** mesmas tabelas com tipos corretos, nomes padronizados e colunas `flag_*` que sinalizam problemas sem apagar linhas. Colunas de data e hora recebem o sufixo `_ts`.
- **Gold:** modelo dimensional. `NULL` quer dizer "não se aplica"; `FALSE` quer dizer "avaliado e não ocorreu".
- Chaves **naturais**. O CEP é sempre **texto** (há CEPs com zero à esquerda).
- Valores monetários em `DECIMAL(12,2)`.

## Silver (resumo)

| Tabela | Linhas | Chave | Principais transformações e flags |
|---|---|---|---|
| `orders` | 99.441 | `order_id` | Datas para timestamp (`*_ts`); `flag_data_entrega_inconsistente` (14) |
| `customers` | 99.441 | `customer_id` | Sem transformação; só testes (CEP com 5 dígitos, estado com 2 letras maiúsculas) |
| `sellers` | 3.095 | `seller_id` | `flag_cidade_suspeita` (17) |
| `products` | 32.951 | `product_id` | Números para inteiro; `lenght` corrigido para `length`; `flag_sem_categoria` (610), `flag_peso_invalido` (6) |
| `order_payments` | 103.886 | `(order_id, payment_sequential)` | `payment_value` em `DECIMAL(12,2)`; `flag_valor_zero` (9), `flag_parcelas_zero` (2) |
| `order_items` | 112.650 | `(order_id, order_item_id)` | `price` e `freight_value` em `DECIMAL(12,2)`; `flag_frete_zero` (383) |
| `order_reviews` | 99.224 | `(review_id, order_id)` | Datas para timestamp; `qtd_avaliacoes_pedido`, `flag_pedido_multiplas_avaliacoes` (1.098 linhas), `flag_review_repetida` (1.603 linhas); comentários preservados exatamente |
| `geolocation` | 1.000.163 | sem chave natural | Coordenadas para `DOUBLE`; `flag_fora_do_brasil` (42) |
| `category_translation` | 71 | `product_category_name` | Sem transformação; só testes |

## Gold

### `dim_calendario` (852 linhas, 01/09/2016 a 31/12/2018)

| Coluna | Descrição |
|---|---|
| `data` | Chave (data) |
| `ano`, `mes`, `trimestre`, `semana_do_ano` | Partes da data |
| `ano_mes` | Texto `yyyy-MM` |
| `dia_da_semana_num` | 1 = domingo |
| `dia_da_semana` | Nome do dia (no idioma padrão do Spark, que não foi verificado nos dados) |
| `fim_de_semana` | Verdadeiro para sábado e domingo |

### `dim_cliente` (99.441 linhas)

| Coluna | Descrição |
|---|---|
| `customer_id` | Chave. **Um por pedido**, e não por pessoa |
| `customer_unique_id` | Identifica a pessoa (96.096 distintas). **Use esta para contar clientes** |
| `cep_prefixo`, `cidade`, `estado` | Localização do cliente |

### `dim_vendedor` (3.095 linhas)

| Coluna | Descrição |
|---|---|
| `seller_id` | Chave |
| `cep_prefixo`, `cidade`, `estado` | Localização do vendedor |
| `flag_cidade_suspeita` | Cidade escrita de forma suspeita (17) |

### `dim_produto` (32.951 linhas)

| Coluna | Descrição |
|---|---|
| `product_id` | Chave |
| `categoria_pt`, `categoria_en` | Categoria (fallback: `sem_categoria`, ou o nome original se não houver tradução) |
| `status_categoria` | `ok` (32.328), `sem_categoria` (610) ou `sem_traducao` (13) |
| `product_weight_g`, `product_length_cm`, `product_height_cm`, `product_width_cm`, `product_photos_qty` | Atributos do produto |
| `flag_peso_invalido` | Peso vazio ou zero (6) |

### `dim_cep` (19.010 linhas)

| Coluna | Descrição |
|---|---|
| `cep_prefixo` | Chave (texto) |
| `lat`, `lng` | **Mediana** das coordenadas do prefixo, excluindo pontos fora do Brasil |
| `qtd_pontos` | Número de pontos usados |

### `fact_itens_pedido` (112.650 linhas; 1 linha = 1 item)

| Coluna | Descrição |
|---|---|
| `order_id`, `order_item_id` | Chave composta |
| `product_id`, `seller_id`, `customer_id` | Ligações com as dimensões |
| `data_compra` | Data da compra (liga com `dim_calendario`) |
| `status_pedido` | Status do pedido |
| `preco`, `frete` | Valores do item |
| `conta_na_receita` | Falso para pedidos `canceled` e `unavailable` |
| `valor_receita` | `preco` quando conta na receita; zero caso contrário. **Some esta coluna para a receita** |
| `distancia_km` | Distância estimada vendedor-cliente (555 itens sem valor) |

### `fact_pedidos` (99.441 linhas; 1 linha = 1 pedido)

| Coluna | Descrição |
|---|---|
| `order_id` | Chave |
| `customer_id`, `data_compra`, `status_pedido` | Identificação |
| `data_entrega`, `data_prevista` | Datas (só o dia) |
| `qtd_itens`, `valor_itens`, `frete_total` | Agregados dos itens |
| `receita_pedido` | Receita do pedido pela mesma regra de `valor_receita` |
| `valor_pago` | Soma dos pagamentos (pode incluir pedidos que não viraram venda) |
| `nota`, `qtd_avaliacoes` | Nota da avaliação **mais recente** e total de avaliações (`NULL` em 768 pedidos sem avaliação) |
| `distancia_max_km`, `faixa_distancia` | Maior distância entre os vendedores do pedido e o cliente, e sua faixa |
| `tem_entrega_valida` | Status `delivered` com data de entrega (96.470) |
| `flag_data_entrega_inconsistente` | Herdada da Silver |
| `dias_ate_entrega` | Dias entre compra e entrega (só se há entrega válida) |
| `dias_apos_prazo` | Dias entre a data prevista e a entrega. Positivo = atraso |
| `entregue_apos_prazo` | `dias_apos_prazo > 0` (`NULL` se não houver entrega válida) |
| `entregue_mais_3_dias_apos_prazo` | `dias_apos_prazo > 3` (`NULL` se não houver entrega válida) |

### Auditoria: `audit.pipeline_audit`

| Coluna | Descrição |
|---|---|
| `run_id` | Identificador da execução de uma camada |
| `camada`, `tabela` | O que foi processado |
| `inicio`, `fim`, `duracao_seg` | Tempos (em UTC) |
| `status` | `OK`, `DIVERGENTE`, `ERRO` ou `PULADA` |
| `linhas_esperadas`, `linhas_gravadas` | Para reconciliar |
| `mensagem_erro` | Motivo da falha (até 200 caracteres) |
