!!! WARNING !!!
DBA DISCRETION IS ADVISED. USE THIS ON A PRODUCTION DATABASE WITH CAUTION.

This script bundle allows you to generate CPU load on a given Oracle database instance.

        CPUGen - generate cpu load.

        cpugen.sh [-h] -s <ORACLE_SID> -p <NUMBER_OF_PROCESSES>

        -h - print this message
        -p - number of processes to generate
        -s - database name

        Example:

        - generate 30 processes on database orcl:

          cpugen.sh -s orcl -p 30

Generated sessions are marked with "CPUG V1 Run" in ACTION field of v$session. If you are having
performance problems you can safely kill them. Note that supplied "cpu.sql" script is necessary for
proper execution.
