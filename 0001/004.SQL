-- Function: sigilomobile.retorna_saldo_e_movimentacao_contas(integer, text, date, date)

-- DROP FUNCTION sigilomobile.retorna_saldo_e_movimentacao_contas(integer, text, date, date);

CREATE OR REPLACE FUNCTION sigilomobile.retorna_saldo_e_movimentacao_contas(IN pcodempresa integer, IN pid_conta text, IN pdata_ini date, IN pdata_fim date)
  RETURNS TABLE(cod_empresa integer, id character varying, cod_conta integer, nome_conta character varying, redutora boolean, permite_lancar boolean, natureza_conta character, tipo_conta smallint, data_movimento date, cod_lancamento_padrao integer, tipo_movimento character, valor numeric, saldo_inicial numeric, saldo_final numeric) AS
$BODY$
DECLARE

    data_ultimo_fechamento DATE;
    pcodigos_planos        int[];
    sql_text               TEXT;

BEGIN

    SELECT
        array_agg(cod_plano)
    INTO pcodigos_planos
    FROM
        plano_contas pc
        INNER JOIN (SELECT UNNEST(string_to_array(pid_conta, ','::Varchar)) || '%' AS id_conta) AS qry
            ON pc.id ILIKE id_conta;

    -- PEGA DATA DO ULTIMO CHECKPOINT DE CONTAS ATIVO
    SELECT
        fl.data_movimento
    INTO data_ultimo_fechamento
    FROM
        fechamentos_lanc fl
    WHERE
        fl.cod_empresa = pcodempresa AND
        fl.data_movimento < pdata_ini - 1 AND
        fl.data_alteracao < pdata_ini AND
        fl.congelado_empresa
    ORDER BY
        fl.data_movimento DESC,
        fl.data_inclusao  DESC
    LIMIT 1;


    -- PEGA MOVIMENTO A PARTIR DO ULTIMO CHECKPOINT DE CONTAS ATÉ A DATA INI -1
    sql_text =
            'WITH
    movimento_apos_checkpoint AS (SELECT
                                      mc.cod_empresa,
                                      mc.cod_conta,
                                      mc.saldo AS natureza_conta,
                                      SUM(CASE
                                              WHEN mc.tipo_movimento = ''D'' THEN mc.valor
                                              ELSE 0 END) AS debitos,
                                      SUM(CASE
                                              WHEN mc.tipo_movimento = ''C'' THEN mc.valor
                                              ELSE 0 END) AS creditos
                                  FROM
                                      sigilomobile.movimento_contas mc
                                      LEFT JOIN plano_contas pc
                                          ON (mc.cod_conta = pc.cod_plano)
                                  WHERE
                                      mc.cod_empresa = $3 AND
                                      array[pc.cod_plano] <@ $4  AND
                                      mc.data_movimento BETWEEN COALESCE($1::DATE + 1, ''01 / 01 / 1899'') AND $2::DATE - 1
                                  GROUP BY
                                      mc.cod_empresa,
                                      mc.cod_conta,
                                      mc.saldo),

    saldo_inicial             AS
        (SELECT
             mov.cod_empresa,
             mov.cod_conta,
             calcula_saldo_conta_pelo_movimento(CASE
                                                    WHEN mov.natureza_conta = ''C''
                                                                THEN scc.creditos - scc.debitos
                                                    ELSE scc.debitos - scc.creditos END,
                                                COALESCE(mov.creditos, 0),
                                                COALESCE(mov.debitos, 0),
                                                mov.natureza_conta) AS saldo_inicial


         FROM
             movimento_apos_checkpoint mov
             LEFT JOIN saldo_contas_checkpoints scc
                 ON (mov.cod_empresa, mov.cod_conta) = (scc.cod_empresa, scc.cod_conta)
         WHERE
             scc.data_movimento = $1 OR
             $1 IS NULL),

    movimento_deb_cred        AS
        (SELECT
             mc.cod_empresa,
             mc.cod_conta,
             mc.saldo AS natureza_conta,
             SUM(CASE WHEN mc.tipo_movimento = ''D'' THEN mc.valor ELSE 0 END) AS debitos,
             SUM(CASE WHEN mc.tipo_movimento = ''C'' THEN mc.valor ELSE 0 END) AS creditos
         FROM
             sigilomobile.movimento_contas mc
         WHERE
             mc.data_movimento BETWEEN $2 AND $5
         GROUP BY
             mc.cod_empresa,
             mc.cod_conta,
             mc.saldo),

    saldo_final               AS
        (SELECT
             mdb.cod_empresa,
             mdb.cod_conta,
             mdb.natureza_conta,
             calcula_saldo_conta_pelo_movimento(si.saldo_inicial,
                                                COALESCE(mdb.creditos, 0),
                                                COALESCE(mdb.debitos, 0),
                                                mdb.natureza_conta) AS saldo_final
         FROM
             movimento_deb_cred mdb
             LEFT JOIN saldo_inicial si
                 ON (mdb.cod_empresa, mdb.cod_conta) = (si.cod_empresa, si.cod_conta))


SELECT
    mc.cod_empresa,
    pc.id,
    mc.cod_conta,
    pc.nome,
    pc.redutora,
    pc.permite_lancar,
    mc.saldo,
    pc.cod_tipo_conta,
    mc.data_movimento,
    mc.cod_lancamento_padrao,
    mc.tipo_movimento,
    mc.valor,
    si.saldo_inicial,
    sf.saldo_final

FROM
    sigilomobile.movimento_contas mc
    LEFT JOIN plano_contas pc
        ON (mc.cod_conta = pc.cod_plano)
    LEFT JOIN saldo_inicial si
        ON (si.cod_empresa, si.cod_conta) = (mc.cod_empresa, mc.cod_conta)
    LEFT JOIN saldo_final sf
        ON (sf.cod_empresa, sf.cod_conta) = (mc.cod_empresa, mc.cod_conta)
WHERE
    mc.cod_empresa = $3 AND
    array[pc.cod_plano] <@ $4 AND
    mc.data_movimento BETWEEN $2 AND $5;';

    RETURN QUERY EXECUTE sql_text using data_ultimo_fechamento, pdata_ini, pcodempresa, pcodigos_planos, pdata_fim;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 100000;
ALTER FUNCTION sigilomobile.retorna_saldo_e_movimentacao_contas(integer, text, date, date)
  OWNER TO moduladb;
