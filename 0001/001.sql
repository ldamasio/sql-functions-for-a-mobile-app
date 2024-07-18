-- Function: sigilomobile.l_retorna_movimentacao_contas(integer)

-- DROP FUNCTION sigilomobile.l_retorna_movimentacao_contas(integer);

CREATE OR REPLACE FUNCTION sigilomobile.l_retorna_movimentacao_contas(IN param_cod_empresa integer)
  RETURNS TABLE(cod_empresa integer, valor numeric) AS
$BODY$ 
BEGIN
    CREATE TEMPORARY TABLE temp_movimento____ AS 
        SELECT 
            m.cod_empresa, 
            m.cod_conta, 
            p.id, 
            m.valor 
        FROM sigilomobile.movimento_contas m
            LEFT JOIN plano_contas p
                ON (p.cod_plano = m.cod_conta)
            LEFT JOIN lancamentos_padrao l
                ON (m.cod_lancamento_padrao = l.cod_lancamento_padrao)
        WHERE m.cod_empresa = $1
        LIMIT 50;
    RETURN QUERY
        SELECT cod_plano, mv.valor 
        FROM plano_contas pc
            LEFT JOIN temp_movimento____ mv
                ON (mv.id ILIKE pc.id || '%')
        WHERE pc.id ILIKE '1.1.1.1.%'
        LIMIT 50;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION sigilomobile.l_retorna_movimentacao_contas(integer)
  OWNER TO moduladb;
