-- Function: sigilomobile.g_retorna_saldo_contas_na_data(integer, date)

-- DROP FUNCTION sigilomobile.g_retorna_saldo_contas_na_data(integer, date);

CREATE OR REPLACE FUNCTION sigilomobile.g_retorna_saldo_contas_na_data(IN p_cod_empresa integer, IN p_data date)
  RETURNS TABLE(cod_empresa integer, id text, nome character varying, saldo_conta numeric, credibilidade integer) AS
$BODY$
BEGIN
    RETURN QUERY
    WITH
    saldos AS (
        SELECT DISTINCT ON (sd.cod_empresa, converte_id_para_comparar(sd.id))
            sd.cod_empresa,
            sd.id,
            sd.cod_conta,
            sd.nome_conta,
            sd.redutora,
            sd.permite_lancar,
            CASE WHEN sd.redutora THEN -sd.saldo_final ELSE sd.saldo_final END AS saldo_conta
        FROM
            sigilomobile.retorna_saldo_e_movimentacao_contas(
                p_cod_empresa, 
                '2.1.,1.1.1.1.,1.1.1.2.,1.1.1.3.,1.1.1.4.,1.1.2.,1.1.2.2.', 
                p_data, 
                p_data
            ) sd
        ORDER BY
            sd.cod_empresa,
            converte_id_para_comparar(sd.id)
    )
    SELECT
        sd.cod_empresa,
        pc.id::text,
        pc.nome,
        SUM(sd.saldo_conta) AS saldo_conta,
        NULL::integer AS credibilidade
    FROM
        plano_contas pc
        INNER JOIN saldos sd
            ON (sd.id ILIKE pc.id || '%')
    WHERE
        get_hierarchy_level(pc.id) >= (get_hierarchy_level(sd.id) - 1)
    GROUP BY
        sd.cod_empresa,
        pc.id,
        pc.nome
    ORDER BY
        pc.id;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION sigilomobile.g_retorna_saldo_contas_na_data(integer, date)
  OWNER TO moduladb;


