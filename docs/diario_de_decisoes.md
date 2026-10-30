# Diário de decisões

Cada entrada registra o problema, a evidência observada, as hipóteses (marcadas como **não testadas** quando for o caso) e a decisão. Decisões que dependem de regra de negócio estão marcadas como **pendentes de confirmação** e listadas em [perguntas_ao_cliente.md](perguntas_ao_cliente.md).

## 1. Pedidos "entregues" sem data e "cancelados" com data

| Campo | Conteúdo |
|---|---|
| Problema | 8 pedidos `delivered` sem `order_delivered_customer_date` e 6 pedidos `canceled` com essa data |
| Evidência | 14 de 99.441 pedidos. Os 14 têm itens e pagamentos. 6 dos 8 sem data foram comprados entre 08/06 e 01/07/2018 |
| Hipóteses (não testadas) | Falha de registro no período; cancelamento ou devolução posterior à entrega |
| Decisão | Bronze: manter. Silver: manter e sinalizar (`flag_data_entrega_inconsistente`). Gold: fora do cálculo de atraso e contados na qualidade. Não preencher a data com a prevista |
| Pendente | Confirmar com o cliente |

## 2. Vendedores com a cidade escrita de forma suspeita

| Campo | Conteúdo |
|---|---|
| Problema | 17 vendedores com cidade como `sbc/sp`, `04482255` ou `sp / sp` |
| Evidência | Os 17 têm vendas, mas somam 0,12% dos itens e 0,07% da receita. A cidade não é usada nas perguntas de negócio |
| Decisão | Preservar o texto e sinalizar (`flag_cidade_suspeita`). Não corrigir por palpite (`sbc/sp` provavelmente é São Bernardo do Campo, mas seria suposição) |
| Evolução possível | Recuperar a cidade pelo CEP com a geolocalização, se a cidade passar a importar |

## 3. Produtos sem categoria, peso inválido e categorias sem tradução

| Campo | Conteúdo |
|---|---|
| Problema | 610 produtos sem categoria (as mesmas linhas também sem tamanho de nome, descrição e fotos); 6 com peso vazio ou zero; 13 com categoria sem tradução |
| Evidência | Os 610 respondem por 1.603 itens e R$ 179.535,28 (1,32% da receita). Os 4 pesos zero são todos de `cama_mesa_banho` com as mesmas dimensões (hipótese não testada: valor padrão de sistema) |
| Decisão | Preservar e sinalizar (`flag_sem_categoria`, `flag_peso_invalido`). Na Gold, `dim_produto` usa fallback (`sem_categoria`, `sem_traducao`) e nenhum produto some do JOIN |
| Pendente | Manter como "sem categoria" ou excluir da análise (o filtro entraria na Gold) |

## 4. Pagamentos em pedidos sem itens

| Campo | Conteúdo |
|---|---|
| Problema | 775 pedidos têm pagamento e nenhum item |
| Evidência | 603 `unavailable` e 164 `canceled` (99,0%). Somam cerca de R$ 161,7 mil. Os outros 8 estão em `created`, `invoiced` ou `shipped` |
| Correção de hipótese | A diferença de cerca de R$ 165 mil entre pagamentos e preço mais frete **não** era, em sua maior parte, juros de parcelamento, como se supôs de início. A maior parte é dinheiro registrado em pedidos que não viraram venda |
| Decisão | Preservar. A receita vem dos **itens**, e os pagamentos servem para forma de pagamento e reconciliação |

## 5. Receita: definição adotada

> Soma de `price` dos itens (sem frete) de pedidos com status diferente de `canceled` e `unavailable`, na data da compra.

Excluem-se 549 itens (R$ 97.242,96, 0,72% do preço total). Os itens permanecem nas tabelas; a exclusão é a coluna `valor_receita`, calculada na Gold, para que a regra exista em um só lugar. **Pendente de confirmação.**

## 6. Avaliações: granularidade e qual vale por pedido

| Campo | Conteúdo |
|---|---|
| Problema | `review_id` não é único (789 `review_id` aparecem em mais de uma linha, sempre com `order_id` diferentes). 547 pedidos têm mais de uma avaliação, e 202 deles com notas diferentes |
| Evidência | Um `LEFT JOIN` entre pedidos e avaliações devolve **99.992** linhas para **99.441** pedidos (duplicação de linhas) |
| Decisão | Silver: 1 linha por avaliação, sem deduplicar, com flags. Gold: **a avaliação mais recente** por pedido (`ROW_NUMBER`), com 768 pedidos sem nota (`NULL`, não zero). **Pendente** |

## 7. Atraso: data ou horário, e dois limiares

| Campo | Conteúdo |
|---|---|
| Problema | A diretora e o gerente de logística definem "atraso" de formas diferentes |
| Decisão | Calcular **um** número (`dias_apos_prazo`) e derivar duas flags nomeadas: `entregue_apos_prazo` (> 0 dias) e `entregue_mais_3_dias_apos_prazo` (> 3 dias) |
| Evidência | Comparando só a **data**: 6,77% (4,83% com mais de 3 dias). Comparando o **horário** completo, a sondagem inicial deu 8,11%. Os dois são defensáveis |
| Convenção | `NULL` significa "não se aplica" (sem entrega válida), e não "não atrasou" |
| Pendente | Confirmar data x horário e quem desempata a definição |

## 8. Distância entre vendedor e cliente

| Campo | Conteúdo |
|---|---|
| Decisão | Centro de cada CEP = **mediana** das coordenadas (a média seria puxada por pontos fora do lugar). As 42 coordenadas fora do Brasil são sinalizadas e excluídas do cálculo (5 CEPs ficam sem ponto). Fórmula de Haversine |
| Evidência | 555 itens ficam sem distância (CEP sem geolocalização). 1.278 pedidos têm mais de um vendedor: usa-se a **maior** distância (suposição) |
| Cuidado | A relação entre distância e atraso é uma **associação**, e não prova causa |

## 9. Escolhas técnicas

| Decisão | Motivo |
|---|---|
| Bronze toda como texto | Preserva o dado original e evita conversões silenciosas (CEP com zero à esquerda) |
| Dinheiro como `DECIMAL(12,2)` | Evita erro de arredondamento do ponto flutuante e permite reconciliar ao centavo |
| `CREATE OR REPLACE` / `overwrite` | Execução repetida gera o mesmo resultado (idempotência) |
| Auditoria com `append` | É o histórico do que aconteceu |
| Retentativas do Job desligadas | Erros de qualidade se repetem, a cota gratuita é limitada e cada tentativa gravaria a falha de novo na auditoria |
| Chaves naturais, sem chaves substitutas | Não há histórico (SCD) que as justifique |
| `geolocation` sem chave | Há linhas 100% duplicadas. A defesa é contagem e regras |
| Rascunhos de desenvolvimento fora do repositório | O SQL oficial está nos dicionários; manter duas versões do mesmo código arrisca divergência |
