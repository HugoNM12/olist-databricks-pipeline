-- Consultas de investigacao (etapa "Investigar os dados").
-- Rodar no SQL Editor do Databricks, uma de cada vez.
-- O nome de cada consulta (como foi salva) esta no comentario que a antecede.

-- ver_se_arquivos_chegaram
SELECT *
FROM read_files(
  '/Volumes/workspace/default/olist_raw/olist_orders_dataset.csv',
  format => 'csv',
  header => true
)
LIMIT 10;

-- teste_contagem  (esperado: 99441)
SELECT COUNT(*) AS total_pedidos
FROM read_files(
  '/Volumes/workspace/default/olist_raw/olist_orders_dataset.csv',
  format => 'csv',
  header => true
);

-- status_x_datas_entrega_vazias
SELECT
  order_status,
  COUNT(*) AS pedidos,
  COUNT(order_delivered_customer_date) AS com_data_entrega
FROM read_files(
  '/Volumes/workspace/default/olist_raw/olist_orders_dataset.csv',
  format => 'csv',
  header => true
)
GROUP BY order_status
ORDER BY pedidos DESC;

-- ver_14_linhas_estranhas  (esperado: 14 linhas)
SELECT
  order_id,
  order_status,
  order_purchase_timestamp,
  order_delivered_customer_date,
  order_estimated_delivery_date
FROM read_files(
  '/Volumes/workspace/default/olist_raw/olist_orders_dataset.csv',
  format => 'csv',
  header => true
)
WHERE (order_status = 'delivered' AND order_delivered_customer_date IS NULL)
   OR (order_status = 'canceled'  AND order_delivered_customer_date IS NOT NULL)
ORDER BY order_status, order_purchase_timestamp;

-- investigar_customers_visao_geral
SELECT
  COUNT(*)                                                         AS total,
  COUNT(DISTINCT customer_id)                                      AS ids_distintos,
  COUNT(DISTINCT customer_unique_id)                               AS clientes_distintos,
  COUNT(DISTINCT customer_state)                                   AS estados_distintos,
  SUM(CASE WHEN length(customer_zip_code_prefix) <> 5 THEN 1 ELSE 0 END) AS cep_fora_do_padrao,
  SUM(CASE WHEN customer_city <> lower(trim(customer_city)) THEN 1 ELSE 0 END) AS cidade_fora_do_padrao,
  SUM(CASE WHEN customer_id IS NULL OR customer_unique_id IS NULL THEN 1 ELSE 0 END) AS chave_vazia
FROM workspace.bronze.customers;

-- investigar_customers_estados
SELECT customer_state, COUNT(*) AS clientes
FROM workspace.bronze.customers
GROUP BY customer_state
ORDER BY clientes DESC;

-- investigar_sellers_visao_geral
SELECT
  COUNT(*)                                                                    AS total,
  COUNT(DISTINCT seller_id)                                                   AS ids_distintos,
  COUNT(DISTINCT seller_state)                                                AS estados_distintos,
  SUM(CASE WHEN length(seller_zip_code_prefix) <> 5 THEN 1 ELSE 0 END)        AS cep_fora_do_padrao,
  SUM(CASE WHEN NOT (seller_state RLIKE '^[A-Z]{2}$') THEN 1 ELSE 0 END)      AS estado_fora_do_padrao,
  SUM(CASE WHEN seller_city <> lower(trim(seller_city)) THEN 1 ELSE 0 END)    AS cidade_fora_do_padrao,
  SUM(CASE WHEN seller_city RLIKE '[0-9/\\\\]' THEN 1 ELSE 0 END)             AS cidade_com_simbolo
FROM workspace.bronze.sellers;

-- investigar_sellers_cidades_suspeitas  (esperado: 17 linhas)
SELECT seller_id, seller_city, seller_state, seller_zip_code_prefix
FROM workspace.bronze.sellers
WHERE seller_city RLIKE '[0-9/\\\\]'
ORDER BY seller_city;

-- investigar_products_visao_geral
SELECT
  COUNT(*)                                                                        AS total,
  COUNT(DISTINCT product_id)                                                      AS ids_distintos,
  COUNT(*) - COUNT(product_category_name)                                         AS sem_categoria,
  COUNT(*) - COUNT(product_name_lenght)                                           AS sem_tam_nome,
  COUNT(*) - COUNT(product_weight_g)                                              AS sem_peso,
  SUM(CASE WHEN product_weight_g = '0' THEN 1 ELSE 0 END)                         AS peso_zero,
  COUNT(DISTINCT product_category_name)                                           AS categorias_distintas
FROM workspace.bronze.products;

-- investigar_products_zeros_e_traducao  (esperado: 13 e 32951)
SELECT
  SUM(CASE WHEN p.product_category_name IS NOT NULL
            AND t.product_category_name IS NULL THEN 1 ELSE 0 END) AS categoria_sem_traducao,
  COUNT(*) AS total
FROM workspace.bronze.products p
LEFT JOIN workspace.bronze.category_translation t
  ON p.product_category_name = t.product_category_name;

-- investigar_payments_visao_geral
SELECT
  COUNT(*)                                                           AS linhas,
  COUNT(DISTINCT order_id)                                           AS pedidos_distintos,
  COUNT(DISTINCT payment_type)                                       AS tipos_distintos,
  SUM(CASE WHEN try_cast(payment_value AS DOUBLE) = 0 THEN 1 ELSE 0 END)        AS valor_zero,
  SUM(CASE WHEN try_cast(payment_installments AS INT) = 0 THEN 1 ELSE 0 END)    AS parcelas_zero,
  SUM(CASE WHEN payment_type = 'not_defined' THEN 1 ELSE 0 END)      AS tipo_not_defined,
  MAX(try_cast(payment_sequential AS INT))                           AS maior_sequencial
FROM workspace.bronze.order_payments;

-- investigar_pedidos_sem_itens  (a soma dos pedidos e 775)
SELECT order_status, COUNT(*) AS pedidos
FROM workspace.bronze.orders
WHERE order_id NOT IN (SELECT order_id FROM workspace.bronze.order_items)
GROUP BY order_status
ORDER BY pedidos DESC;

-- investigar_order_items_visao_geral
SELECT
  COUNT(*)                                                                         AS linhas,
  COUNT(DISTINCT order_id)                                                         AS pedidos,
  SUM(CASE WHEN try_cast(price AS DECIMAL(12,2)) <= 0 THEN 1 ELSE 0 END)           AS preco_zero_ou_negativo,
  SUM(CASE WHEN try_cast(freight_value AS DECIMAL(12,2)) < 0 THEN 1 ELSE 0 END)    AS frete_negativo,
  SUM(CASE WHEN try_cast(freight_value AS DECIMAL(12,2)) = 0 THEN 1 ELSE 0 END)    AS frete_zero,
  SUM(CASE WHEN try_to_timestamp(shipping_limit_date) IS NULL THEN 1 ELSE 0 END)   AS data_invalida,
  MAX(try_cast(order_item_id AS INT))                                              AS maior_item_id
FROM workspace.bronze.order_items;

-- investigar_order_items_orfaos  (integridade referencial; total deve ficar em 112650)
SELECT
  COUNT(*)                                          AS total,
  SUM(CASE WHEN o.order_id   IS NULL THEN 1 ELSE 0 END) AS sem_pedido,
  SUM(CASE WHEN s.seller_id  IS NULL THEN 1 ELSE 0 END) AS sem_vendedor,
  SUM(CASE WHEN p.product_id IS NULL THEN 1 ELSE 0 END) AS sem_produto
FROM workspace.bronze.order_items i
LEFT JOIN workspace.bronze.orders   o ON i.order_id   = o.order_id
LEFT JOIN workspace.bronze.sellers  s ON i.seller_id  = s.seller_id
LEFT JOIN workspace.bronze.products p ON i.product_id = p.product_id;

-- investigar_reviews_visao_geral
SELECT
  COUNT(*)                                                                  AS linhas,
  COUNT(DISTINCT review_id)                                                 AS reviews_distintos,
  COUNT(DISTINCT order_id)                                                  AS pedidos_distintos,
  COUNT(DISTINCT review_id, order_id)                                       AS pares_distintos,
  SUM(CASE WHEN review_score NOT IN ('1','2','3','4','5') THEN 1 ELSE 0 END) AS score_fora_do_dominio
FROM workspace.bronze.order_reviews;

-- investigar_reviews_pedidos_repetidos
SELECT qtd_reviews, COUNT(*) AS pedidos
FROM (
  SELECT order_id, COUNT(*) AS qtd_reviews
  FROM workspace.bronze.order_reviews
  GROUP BY order_id
)
GROUP BY qtd_reviews
ORDER BY qtd_reviews;

-- investigar_reviews_fanout  (duplicacao de linhas no JOIN: 99992 linhas para 99441 pedidos)
SELECT
  COUNT(*)                     AS linhas_apos_join,
  COUNT(DISTINCT o.order_id)   AS pedidos_distintos
FROM workspace.bronze.orders o
LEFT JOIN workspace.bronze.order_reviews r
  ON o.order_id = r.order_id;

-- investigar_geolocation_visao_geral
SELECT
  COUNT(*)                                        AS linhas,
  COUNT(DISTINCT geolocation_zip_code_prefix)     AS zips_distintos,
  COUNT(*) - COUNT(DISTINCT geolocation_zip_code_prefix, geolocation_lat,
                   geolocation_lng, geolocation_city, geolocation_state) AS linhas_duplicadas,
  SUM(CASE WHEN try_cast(geolocation_lat AS DOUBLE) < -34
             OR try_cast(geolocation_lat AS DOUBLE) > 6
             OR try_cast(geolocation_lng AS DOUBLE) < -74
             OR try_cast(geolocation_lng AS DOUBLE) > -34
           THEN 1 ELSE 0 END)                     AS fora_do_brasil
FROM workspace.bronze.geolocation;

-- investigar_geolocation_cobertura
SELECT
  (SELECT COUNT(*) FROM workspace.bronze.customers
   WHERE customer_zip_code_prefix NOT IN
     (SELECT DISTINCT geolocation_zip_code_prefix FROM workspace.bronze.geolocation)) AS clientes_sem_geo,
  (SELECT COUNT(*) FROM workspace.bronze.sellers
   WHERE seller_zip_code_prefix NOT IN
     (SELECT DISTINCT geolocation_zip_code_prefix FROM workspace.bronze.geolocation)) AS vendedores_sem_geo;
