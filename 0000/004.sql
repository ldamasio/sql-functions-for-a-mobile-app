SELECT cod_empresa, cod_conta, saldo, data_movimento, data_inclusao, 
       cod_lancamento_padrao, tipo_movimento, valor, md5
  FROM sigilomobile.movimento_contas

	where cod_conta = 449
	AND data_movimento = '20240430'
  ;
