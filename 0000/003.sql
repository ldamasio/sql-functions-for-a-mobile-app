--- aula roger

select id, nome, saldo from plano_contas 
where id like '1.1.1.2.%' 
order by converte_id_para_comparar(id);



select cod_plano, id, nome, saldo 
from plano_contas 
where id like '1.1.1.2.%' 
order by converte_id_para_comparar(id)

select * from sigilomobile.movimento_contas 
where cod_conta in (select cod_plano from plano_contas where id like '1.1.1.6.%') 
and data_movimento = '20240401'


select cod_empresa, data_movimento, saldo, tipo_movimento, sum(valor) total 
from sigilomobile.movimento_contas 
where cod_conta in (select cod_plano from plano_contas where id like '1.1.1.6.%') 
and data_movimento = '20240401' 
group by cod_empresa, data_movimento, saldo, tipo_movimento 
order by data_movimento


