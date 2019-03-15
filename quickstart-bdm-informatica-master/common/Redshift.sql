create table public.orders_presenter (
  o_orderkey integer ,
  o_custkey integer ,
  o_orderstatus varchar(1) ,
  o_totalprice decimal(10,2) ,
  o_orderdate timestamp ,
  o_orderpriority varchar(15) ,
  o_clerk varchar(15) ,
  o_shippriority integer ,
  o_comment varchar(79) ,
  l_orderkey integer ,
  l_partkey integer ,
  l_suppkey integer ,
  l_linenumber integer ,
  l_quantity decimal(10,2) ,
  l_extendedprice decimal(10,2) ,
  l_discount decimal(10,2) ,
  l_tax decimal(10,2) ,
  l_returnflag varchar(1) ,
  l_linestatus varchar(1) ,
  l_shipdate timestamp ,
  l_commitdate timestamp ,
  l_receiptdate timestamp ,
  l_shipinstruct varchar(25) ,
  l_shipmode varchar(10) ,
  l_comment varchar(44) 
 );
 

