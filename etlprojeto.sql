WITH tb_transacao as (
        SELECT IdTransacao,
        idCliente,
        qtdePontos,
        datetime(substr(dtCriacao, 1,19)) as dtCriacao,
        julianday('now') - julianday(substr(dtCriacao, 1,10)) as diffdate,
        cast (strftime('%H', substr(dtCriacao, 1,19)) as integer) as dtHora

        from transacoes
),

tb_cliente as(

select idCliente,
       datetime(substr(dtCriacao, 1,19)) as dtCriacao, 
        julianday('now') - julianday(substr(dtCriacao, 1,10)) as IdadeBase
from clientes

),

tb_sumario_transacoes  as (

select idCliente,
        count(IdTransacao ) as qtdetransacoesVida,
        count (case WHEn diffdate <= 7 THEN IdTransacao end ) as qtdetransacoes7,
        count (case WHEn diffdate <= 14 THEN IdTransacao end ) as qtdetransacoes14,
        count (case WHEn diffdate <= 28 THEN IdTransacao end ) as qtdetransacoes28,
        count (case WHEn diffdate <= 56 THEN IdTransacao end ) as qtdetransacoes56,
        sum(qtdePontos) as SaldoPontos,
        
        min(diffdate) as DiasultimaInteracao,
        
        sum( case WHEN qtdePontos >0  then qtdePontos else 0 end) as qtdePontosPosiVida,

        sum(case WHEN qtdePontos >0 and diffdate <= 56 then qtdePontos else 0 end)  as qtdepontospos56,
        sum(case WHEN qtdePontos >0 and diffdate <= 28 then qtdePontos else 0 end)  as qtdepontospos28,
        sum(case WHEN qtdePontos >0 and diffdate <= 14 then qtdePontos else 0 end)  as qtdepontospos14,
       sum(case WHEN qtdePontos >0 and diffdate <=  7 then qtdePontos else 0 end)  as qtdepontospos7,

        sum( case WHEN qtdePontos < 0  then qtdePontos else 0 end) as qtdePontosNegiVida,
        sum(case WHEN qtdePontos  < 0 and diffdate <= 56 then qtdePontos else 0 end)  as qtdepontosNeg56,
        sum(case WHEN qtdePontos  < 0 and diffdate <= 28 then qtdePontos else 0 end)  as qtdepontosNeg28,
        sum(case WHEN qtdePontos  < 0 and diffdate <= 14 then qtdePontos else 0 end)  as qtdepontosNeg14,
       sum(case WHEN qtdePontos   < 0 and diffdate <=  7 then qtdePontos else 0 end)  as qtdepontosNeg7
from tb_transacao

group by idCliente
),


tb_transacao_produto as (

select t1.*,
        t3.DescNomeProduto,
        t3.DescCategoriaProduto

from tb_transacao  as t1

left join transacao_produto as t2
on t1.IdTransacao = t2.IdTransacao

left join produtos as t3
on t2.IdProduto = t3.IdProduto
),

tb_cliente_produto as (

select idCliente,
        DescNomeProduto,
        count(*) as qtdeVida,
        count(case WHEN diffdate <=56 then IdTransacao end ) as qtde56,
        count(case WHEN diffdate <=28 then IdTransacao end ) as qtde28,
        count(case WHEN diffdate <=14 then IdTransacao end ) as qtde14,
        count(case WHEN diffdate <=7 then IdTransacao end ) as qtde7
from tb_transacao_produto

group by idCliente, DescNomeProduto
),

tb_cliente_produto_rn as (
select *,
        row_number() over(PARTITION by idCliente order by qtdeVida desc ) as rnVida,
        row_number() over(PARTITION by idCliente order by qtde56 desc ) as rn56,
        row_number() over(PARTITION by idCliente order by qtde28 desc ) as rn28,
        row_number() over(PARTITION by idCliente order by qtde14 desc ) as rn14,
        row_number() over(PARTITION by idCliente order by qtde7 desc ) as rn7

from tb_cliente_produto

),

tb_cliente_dia as (

        select idCliente,
        strftime('%w', DtCriacao) as dtDia,
        count(*) as qtdTransacao
        from tb_transacao
        where diffdate <=28
        group by idCliente, dtDia
),

tb_cliente_dia_rn as(

select *,
        row_number() over (PARTITION by idCliente order by qtdTransacao desc) as Rndia

 FROM tb_cliente_dia
 ),

tb_cliente_periodo as (

        select 
                idCliente,
                case
                        when dtHora BETWEEN 7 and 12 then 'MANHÃ'
                        when dtHora BETWEEN 13 and 18 then 'TARDE'
                        when dtHora BETWEEN 19 and 23 then 'NOITE'
                        else 'MADRUGADA'
                end as periodo,
                count (*) as qtdeTransacao
        from tb_transacao
        where diffdate <= 28
        group by 1, 2
),

tb_cliente_periodo_rn as (

        select *,
                row_number() over(PARTITION by idCliente order by qtdeTransacao desc) as rnPeriodo
        from tb_cliente_periodo

),

 tb_join  as (
        select t1.*,
        t2.IdadeBase,
        t3.DescNomeProduto as produtovida,
        t4.DescNomeProduto as produto56,
        t5.DescNomeProduto as produto28,
        t6.DescNomeProduto as produto14,
        t7.DescNomeProduto as produto7,
        coalesce(t8.dtDia, -1) as dtDia,
        coalesce (t9.periodo, 'SEM INFORMAÇÃO') as periodo

        from tb_sumario_transacoes as t1

        left join  tb_cliente as t2
        on t1.idCliente = t2.IdCliente

        left join tb_cliente_produto_rn as  t3
        on t1.IdCliente = t3.idCliente
        and t3.rnVida = 1 

        left join tb_cliente_produto_rn as  t4
        on t1.IdCliente = t4.idCliente
        and t4.rn56 = 1 

        left join tb_cliente_produto_rn as  t5
        on t1.IdCliente = t5.idCliente
        and t5.rn28 = 1 

        left join tb_cliente_produto_rn as  t6
        on t1.IdCliente = t6.idCliente
        and t6.rn14 = 1 

        left join tb_cliente_produto_rn as  t7
        on t1.IdCliente = t7.idCliente
        and t7.rn7 = 1 

        left join tb_cliente_dia_rn  as t8
        on t1.idCliente = t8.idCliente
        and t8.Rndia = 1 

        left join tb_cliente_periodo_rn as t9
        on t1.idCliente = t9.idCliente
        and t9.rnPeriodo = 1

)

select* from tb_join