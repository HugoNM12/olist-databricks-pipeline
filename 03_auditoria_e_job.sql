-- Consultas sobre a tabela de auditoria do projeto (workspace.audit.pipeline_audit).
-- A auditoria do projeto e diferente do historico de execucoes do Databricks:
-- ela so registra o que executou (uma tarefa bloqueada nao gera linha).

-- audit_historico_cargas
SELECT camada, tabela, status, linhas_esperadas, linhas_gravadas,
       round(duracao_seg, 1) AS segundos, run_id
FROM workspace.audit.pipeline_audit
ORDER BY inicio;

-- audit_falhas
SELECT tabela, status, linhas_esperadas, linhas_gravadas, inicio
FROM workspace.audit.pipeline_audit
WHERE status <> 'OK';

-- audit_falhas_detalhe
SELECT camada, tabela, status, mensagem_erro, inicio
FROM workspace.audit.pipeline_audit
WHERE status <> 'OK'
ORDER BY inicio DESC;

-- audit_resumo_por_execucao
SELECT run_id,
       MIN(inicio)                                    AS inicio,
       COUNT(*)                                       AS tabelas,
       SUM(CASE WHEN status = 'OK' THEN 1 ELSE 0 END) AS ok,
       ROUND(SUM(duracao_seg), 1)                     AS total_seg
FROM workspace.audit.pipeline_audit
GROUP BY run_id
ORDER BY inicio;

-- audit_silver_ultima_execucao
SELECT tabela, status, linhas_esperadas, linhas_gravadas,
       round(duracao_seg, 1) AS segundos
FROM workspace.audit.pipeline_audit
WHERE camada = 'silver'
  AND run_id = (SELECT run_id FROM workspace.audit.pipeline_audit
                WHERE camada = 'silver' ORDER BY inicio DESC LIMIT 1)
ORDER BY tabela;

-- audit_ultima_execucao_por_camada
-- (esperado depois de uma execucao completa: bronze 9/9, silver 9/9, gold 7/7,
--  com o inicio de cada camada posterior ao da anterior)
WITH execucoes AS (
  SELECT camada, run_id, MIN(inicio) AS inicio_exec
  FROM workspace.audit.pipeline_audit
  GROUP BY camada, run_id
),
ultimas AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY camada ORDER BY inicio_exec DESC) AS rn
  FROM execucoes
)
SELECT a.camada,
       COUNT(*)                                        AS tabelas,
       SUM(CASE WHEN a.status = 'OK' THEN 1 ELSE 0 END) AS ok,
       ROUND(SUM(a.duracao_seg), 1)                    AS segundos_somados,
       MIN(a.inicio)                                   AS inicio
FROM workspace.audit.pipeline_audit a
JOIN ultimas u
  ON a.run_id = u.run_id AND a.camada = u.camada AND u.rn = 1
GROUP BY a.camada
ORDER BY inicio;

-- job_conferir_idempotencia  (esperado depois de varias execucoes: 99441, 99441, 99441 e 13494400.74)
SELECT
  (SELECT COUNT(*) FROM workspace.bronze.orders)      AS bronze_orders,
  (SELECT COUNT(*) FROM workspace.silver.orders)      AS silver_orders,
  (SELECT COUNT(*) FROM workspace.gold.fact_pedidos)  AS gold_pedidos,
  (SELECT ROUND(SUM(valor_receita), 2) FROM workspace.gold.fact_itens_pedido) AS receita;
