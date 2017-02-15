connect system/system@orcl
set feedback off

declare 
  a number := 1; 
begin
  dbms_application_info.set_action(action_name => 'CPUG V1 Run');
  --for i in 1..5000
  for i in 1..50000000 
    loop
      a := ( tan(a) / i )/DBMS_RANDOM.RANDOM*0.333333/0.1511125*(sin(a)/i)/DBMS_RANDOM.RANDOM*0.333333/DBMS_RANDOM.RANDOM*0.333333; 
    end loop;
  dbms_application_info.set_action(null);
end;
/

exit;
/
