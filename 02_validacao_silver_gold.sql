-- Consultas de validacao e reconciliacao.
-- As validacoes automaticas ficam em notebooks/utils (dicionarios de cada camada);
-- estas sao as conferencias manuais usadas durante o desenvolvimento.

-- bronze_conferir_nulos  (esperado: 87656, 58247)
SELECT
  COUNT(*) - COUNT(review_comment_title)   AS titulo_vazio,
  COUNT(*) - COUNT(review_comment_message) AS mensagem_vazia
FROM workspace.bronze.order_reviews;

-- bronze_conferir_nulos (parte 2)  (esperado: 610)
SELECT COUNT(*) - COUNT(product_category_name) AS sem_categoria
FROM workspace.bronze.products;

-- silver_orders_conferir_aprovacao  (esperado: 160)
SELECT COUNT(*) - COUNT(order_approved_ts) AS aprovacao_vazia
FROM workspace.silver.orders;

-- silver_payments_reconciliar_valor  (esperado: dois totais iguais, 16008872.12)
SELECT
  (SELECT ROUND(SUM(try_cast(payment_value AS DECIMAL(14,2))), 2)
   FROM workspace.bronze.order_payments) AS total_bronze,
  (SELECT ROUND(SUM(payment_value), 2)
   FROM workspace.silver.order_payments) AS total_silver;

-- silver_items_reconciliar_valor  (esperado: preco 13591643.70 e frete 2251909.54 dos dois lados)
SELECT
  (SELECT ROUND(SUM(try_cast(price AS DECIMAL(14,2))), 2)         FROM workspace.bronze.order_items) AS preco_bronze,
  (SELECT ROUND(SUM(price), 2)                                    FROM workspace.silver.order_items) AS preco_silver,
  (SELECT ROUND(SUM(try_cast(freight_value AS DECIMAL(14,2))), 2) FROM workspace.bronze.order_items) AS frete_bronze,
  (SELECT ROUND(SUM(freight_value), 2)                            FROM workspace.silver.order_items) AS frete_silver;

-- gold_pedidos_reconciliar  (receitas iguais a 13494400.74 e pagamentos iguais)
SELECT
  (SELECT SUM(receita_pedido) FROM workspace.gold.fact_pedidos)       AS receita_pedidos,
  (SELECT SUM(valor_receita)  FROM workspace.gold.fact_itens_pedido)  AS receita_itens,
  (SELECT SUM(valor_pago)     FROM workspace.gold.fact_pedidos)       AS pago_pedidos,
  (SELECT SUM(payment_value)  FROM workspace.silver.order_payments)   AS pago_silver;

-- gold_conferir_ultimo_estado  (esperado: 99441 e 13494400.74)
SELECT COUNT(*) AS pedidos, ROUND(SUM(receita_pedido), 2) AS receita
FROM workspace.gold.fact_pedidos;
