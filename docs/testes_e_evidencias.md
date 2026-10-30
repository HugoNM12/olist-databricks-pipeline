# Testes e evidências

Todos os resultados abaixo foram **executados no Databricks Free Edition** e conferidos contra o arquivo original ou contra a camada anterior. Os testes marcados como **pendentes** ainda não foram feitos.

## Bronze

| Teste | Esperado | Resultado | Situação |
|---|---|---|---|
| Contagem das 9 tabelas | 99.441, 1.000.163, 112.650, 103.886, 99.224, 99.441, 32.951, 3.095 e 71 | Todas iguais | Comprovado |
| Vazios preservados | `review_comment_title` 87.656, `review_comment_message` 58.247, `product_category_name` 610 | Iguais | Comprovado |
| Tipos | Dados de origem como texto | Texto em `customers` e `orders` (conferido), demais pelo desenho do código | Parcial |
| Execução repetida | Mesmas contagens | `orders` = 99.441 depois de duas cargas | Comprovado |
| Falha provocada | Contagem esperada de `sellers` alterada para 3.000 | `DIVERGENTE`; o notebook terminou com erro; falha registrada na auditoria | Comprovado |
| Recuperação | Valor restaurado | 4ª execução com 9/9 `OK` | Comprovado |

## Silver

| Teste | Resultado | Situação |
|---|---|---|
| Contagens iguais à Bronze nas 9 tabelas | Iguais | Comprovado |
| Vazios iguais antes e depois das conversões | Iguais (ex.: aprovação 160, envio 1.783, entrega 2.965) | Comprovado |
| Pedidos sinalizados | 14 | Comprovado |
| Reconciliação de pagamentos | R$ 16.008.872,12 = R$ 16.008.872,12 | Comprovado |
| Reconciliação de itens | Preço R$ 13.591.643,70 e frete R$ 2.251.909,54, iguais nos dois lados | Comprovado |
| Falha provocada em `orders` (`order_approved_ts` anulado) | `DIVERGENTE`: `vazios order_approved_at: bronze=160 silver=99441`; a contagem de linhas **não** detectaria isto | Comprovado |
| Falha provocada em `customers` (regra de CEP alterada) | `DIVERGENTE`: `regra cep_com_5_digitos: 99441 violações` | Comprovado |
| Falha provocada nas demais 7 tabelas | Não feito (os testes existem, mas nunca foram vistos falhando) | **Pendente** |

## Gold

| Teste | Resultado | Situação |
|---|---|---|
| Dimensões: 852, 99.441, 3.095, 32.951 e 19.010 linhas com chaves únicas | Iguais | Comprovado |
| `dim_produto`: `ok` 32.328, `sem_categoria` 610, `sem_traducao` 13 | Iguais | Comprovado |
| `fact_itens_pedido`: 112.650 linhas, chave única, zero itens órfãos | Iguais | Comprovado |
| Receita: R$ 13.494.400,74; excluído: R$ 97.242,96 (549 itens) | Iguais | Comprovado |
| `fact_pedidos`: 99.441 linhas, chave única | Iguais | Comprovado |
| Atraso: 96.470 entregas válidas, 6.534 após o prazo (6,77%), 4.664 com mais de 3 dias | Iguais | Comprovado |
| Dias até a entrega | Média 12,5 | Comprovado |
| Nota: 98.673 pedidos com nota; média 4,0863; atrasados 2,271; no prazo 4,29 | Iguais | Comprovado |
| Distância: 555 itens sem distância; média 596,6 km; mediana 431,7 km | Iguais | Comprovado |
| Atraso por faixa de distância | 4,48%, 5,20%, 6,75%, 7,08%, 8,77% e 11,60%, crescente | Comprovado |
| Falha provocada (`unavailable` voltou a contar como receita em `fact_itens_pedido`) | `DIVERGENTE` na `fact_pedidos`: `receita_pedidos_vs_itens: 13494400.74 != 13496408.43`. A diferença de R$ 2.007,69 é a receita dos 7 itens `unavailable` | Comprovado |

## Job e automação

| Teste | Resultado | Situação |
|---|---|---|
| Execução completa manual | Succeeded, 5 min 22 s; auditoria 9/9, 9/9 e 7/7 | Comprovado |
| Segunda execução, mesma entrada | Succeeded, 3 min 56 s; contagens e receita iguais (99.441, 99.441, 99.441 e R$ 13.494.400,74) | Comprovado |
| Falha proposital na Silver (regra de CEP) | Job `Failed` com a mensagem da regra; **Gold não executou**; auditoria com **uma** linha da falha (retentativas desligadas); a Gold manteve o último estado válido | Comprovado |
| Reexecução após a correção | Nova execução (`Run now`) concluída em 5 min 5 s com 9/9, 9/9 e 7/7. A `bronze` rodou de novo | Comprovado |
| Execução agendada | *Launched* = "By scheduler", Succeeded, 5 min 11 s; auditoria 9/9, 9/9 e 7/7 | Comprovado |
| Reexecução **parcial** (só tarefas que falharam) | Não testada | **Pendente** |
| Entrada com novos registros | Não testada | **Pendente** |
| Entrada com duplicidades | Não testada | **Pendente** |
| Entrada com valores inválidos (arquivo defeituoso real) | Não testada (as regras foram provadas alterando a validação, e não os dados) | **Pendente** |

## Tempos observados (poucas medições)

| Execução do Job | Duração |
|---|---|
| 1ª (manual) | 5 min 22 s |
| 2ª (manual) | 3 min 56 s |
| Com falha na Silver | 3 min 55 s |
| Recuperação (manual) | 5 min 5 s |
| Agendada | 5 min 11 s |

Por camada, somando as tabelas na auditoria: Bronze 30 a 46 s, Silver 98 a 115 s, Gold 68 a 78 s. A diferença entre a duração do Job e a soma das tabelas ficou entre cerca de 40 s e 85 s por execução. **Hipótese não testada:** inicialização do ambiente serverless em cada tarefa, maior quando o ambiente ficou parado. Com cinco medições, nenhuma conclusão sobre desempenho.

## Erro encontrado e corrigido durante o desenvolvimento

Uma edição na função de validação da Silver (para aceitar chaves compostas) deixou a variável `cols` fora de ordem, e as cinco tabelas então existentes ficaram com status `ERRO` na auditoria (`cannot access local variable 'cols'`). Nenhum dado ruim foi gravado, porque o erro ocorreu na validação. As linhas de erro permanecem no histórico, e o conserto foi substituir a célula inteira.
