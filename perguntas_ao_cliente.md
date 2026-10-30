# Perguntas pendentes ao cliente

Regras de negócio implementadas como **propostas provisórias**. Em um projeto real, cada uma seria confirmada em reunião com a diretora comercial e o gerente de logística.

| # | Pergunta | Proposta atual | Impacto |
|---|---|---|---|
| 1 | Pedidos "entregues" sem data de entrega (8) e "cancelados" com data (6): manter, sinalizar e excluir do cálculo de atraso? | Manter, sinalizar e excluir do cálculo | Indicador de atraso |
| 2 | Vendedores com cidade suspeita (17): preservar e sinalizar? | Preservar e sinalizar | Nenhum nas métricas atuais |
| 3 | Produtos sem categoria (610 produtos, 1,32% da receita): manter como "sem categoria" ou excluir da análise? | Manter como "sem categoria" | Receita por categoria |
| 4 | Pedidos em `created`, `invoiced` ou `shipped` **sem itens** (8) e 1 pedido entregue **sem pagamento**: como tratar? | Preservar | Reconciliação e contagem de pedidos |
| 5 | A receita deve vir dos itens, excluindo `canceled` e `unavailable` (R$ 97.242,96)? | Sim | **Número principal do painel** |
| 6 | Pedido com mais de uma avaliação (547): qual vale (mais recente, pior, média)? | A mais recente | Nota média e pergunta 5 |
| 7 | O atraso compara só a data (6,77%) ou o horário (8,11%)? E quem desempata se as definições de atraso divergirem (> 0 dias x > 3 dias)? | Só a data, com as duas flags | Percentual de atraso |
| 8 | Analisar apenas jan/2017 a ago/2018? (2016 e set/2018 têm poucos pedidos) | Sim | Gráficos e médias |
| 9 | Para pedidos com mais de um vendedor (1.278), usar a maior distância? | Sim | Pergunta 6 |
