-- Consultas que respondem as perguntas de negocio a partir da camada Gold.

-- gold_receita_por_mes  (pergunta 1)
-- "pedidos" conta apenas pedidos que entram na receita (mesma regra da coluna receita).
SELECT c.ano_mes,
       ROUND(SUM(f.valor_receita), 2)                                      AS receita,
       COUNT(DISTINCT CASE WHEN f.conta_na_receita THEN f.order_id END)    AS pedidos
FROM workspace.gold.fact_itens_pedido f
JOIN workspace.gold.dim_calendario c ON f.data_compra = c.data
GROUP BY c.ano_mes
ORDER BY c.ano_mes;

-- gold_atraso_validar  (perguntas 3 e 4)
-- esperado: 96470 entregues validos, 6534 apos o prazo, 4664 com mais de 3 dias, 6.77 %, media ~12.5 dias
SELECT
  COUNT(CASE WHEN tem_entrega_valida THEN 1 END)                         AS entregues_validos,
  SUM(CASE WHEN entregue_apos_prazo THEN 1 ELSE 0 END)                   AS apos_prazo,
  SUM(CASE WHEN entregue_mais_3_dias_apos_prazo THEN 1 ELSE 0 END)      AS mais_3_dias,
  ROUND(100.0 * SUM(CASE WHEN entregue_apos_prazo THEN 1 ELSE 0 END)
        / COUNT(CASE WHEN tem_entrega_valida THEN 1 END), 2)             AS pct_apos_prazo,
  ROUND(AVG(dias_ate_entrega), 2)                                        AS media_dias_entrega
FROM workspace.gold.fact_pedidos;

-- gold_nota_vs_atraso  (pergunta 5; associacao observada, nao prova causa)
SELECT
  COUNT(nota)                                                      AS pedidos_com_nota,
  ROUND(AVG(nota), 4)                                              AS nota_media,
  ROUND(AVG(CASE WHEN entregue_apos_prazo     THEN nota END), 3)   AS nota_media_atrasados,
  ROUND(AVG(CASE WHEN NOT entregue_apos_prazo THEN nota END), 3)   AS nota_media_no_prazo
FROM workspace.gold.fact_pedidos;

-- gold_distancia_vs_atraso  (pergunta 6; distancia estimada pelo centro do CEP)
SELECT faixa_distancia,
       COUNT(*) AS pedidos,
       ROUND(100.0 * SUM(CASE WHEN entregue_apos_prazo THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_atraso
FROM workspace.gold.fact_pedidos
WHERE tem_entrega_valida AND faixa_distancia IS NOT NULL
GROUP BY faixa_distancia
ORDER BY faixa_distancia;
