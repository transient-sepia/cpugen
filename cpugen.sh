#!/usr/bin/env bash
#
# cpugen-chan
# version 1.0
#
# / *surrounded by fire* this is fine. /
#

# usage
USAGE="\n\tCPUGen - generate cpu load.\n\n \
\tcpugen.sh [-h] -s <ORACLE_SID> -p <NUMBER_OF_PROCESSES>\n\n \
\t-h - print this message\n \
\t-p - number of processes to generate\n \
\t-s - database name\n\n \
\tExample:\n\n \
\t- generate 30 processes on database orcl:\n\n \
\t  cpugen.sh -s orcl -p 30\n"

trap "ctrl_c; exit" INT

function ctrl_c () {
  echo "** Trapped CTRL-C"
}

# options
while getopts 'hs:p:' opt
do
  case $opt in
    h) echo -e "${USAGE}"
       exit 0
       ;;
    s) SID=${OPTARG}
       ;;
    p) PROCESS=${OPTARG}
       ;;
    :) echo "option -$opt requires an argument"
       ;;
    *) echo -e "${USAGE}"
       exit 1
       ;;
  esac
done
shift $(($OPTIND - 1))

# env
export PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/sfw/bin:/usr/bin:/bin
CURRDIR="/u01/app/oracle/scripts/cpu"
LOGDIR="/u01/log/oracle"
if [[ ! -d ${LOGDIR} ]]; then
  printf "Standard log directory is not available, attempting to create.\n"
  mkdir -p ${LOGDIR}
  if [[ $? != 0 ]]; then
    printf "Operation failed.\n"
    exit 1
  fi
fi
LOG=${LOGDIR}/cpugen_${SID}.log

# error handling
function errck () {
  printf "\n\n*** $(date +%Y.%m.%d\ %H:%M:%S)\n${ERRMSG} Stop.\n" >> ${LOG} 2>&1
  exit 1
}

# current directory check
if [[ ! -d ${CURRDIR} ]]; then
  printf "*** $(date +%Y.%m.%d\ %H:%M:%S) Non-standard script directory found, please place cpugen.sh and cpu.sql files to /u01/app/oracle/scripts/cpu. If it does not exist, create it.\n" >> ${LOG} 2>&1
fi
cd ${CURRDIR}

# sql file
if [[ ! -f "${CURRDIR}/cpu.sql" ]]; then
  ERRMSG="Additional file cpu.sql was not found."
  errck
fi

# os-dependent variables
case $(uname -s) in
  "Linux")    ORATAB=/etc/oratab
              PSCHECK="$(ps -aeo args | grep '[s]qlplus -s /nolog @${CURRDIR}/cpu.sql')"
              ;;
  "HP-UX")    ORATAB=/etc/oratab
              PSCHECK="$(ps -fe comm | grep '[s]qlplus -s /nolog @${CURRDIR}/cpu.sql')"
              ;;
  "AIX")      ORATAB=/etc/oratab
              PSCHECK="$(ps -feo args | grep '[s]qlplus -s /nolog @${CURRDIR}/cpu.sql')"
              ;;
  "SunOS")    ORATAB=/var/opt/oracle/oratab
              PSCHECK="$(ps -fe -o comm | grep '[s]qlplus -s /nolog @${CURRDIR}/cpu.sql')"
              ;;
  *)          ERRMSG="WARNING - Unknown OS. Cannot proceed."
              errck
              ;;
esac

# set oracle environment
function setora () {
  ERRMSG="SID ${1} not found in ${ORATAB}."
  if [[ $(cat ${ORATAB} | grep "^$1:") ]]; then
    unset ORACLE_SID ORACLE_HOME ORACLE_BASE
    export ORACLE_BASE=/u01/app/oracle
    export ORACLE_SID=${1}
    export ORACLE_HOME=$(cat ${ORATAB} | grep "^${ORACLE_SID}:" | cut -d: -f2)
    export PATH=${ORACLE_HOME}/bin:${PATH}
  else
    errck
  fi
}

# check if zero
function check () {
  if [[ $? != 0 ]]; then
    printf "\n\n*** $(date +%Y.%m.%d\ %H:%M:%S)\n${ERRMSG} Stop.\n" >> ${LOG} 2>&1
    exit 1
  fi
}

# sid check
if [[ ${#SID} == 0 ]]; then
  ERRMSG="No SID was specified."
  errck
fi

# process check
if [[ ${#PROCESS} == 0 ]]; then
  ERRMSG="You should specify amount of processes to create."
  errck
fi

# db check
setora ${SID}
ERRMSG="Cannot get the number of session(s) running with CPU Gen action."
ACTSES=$(printf "
  set head off verify off trimspool on feed off line 2000 pagesize 100 newpage none
  set numformat 9999999999999999999
  set pages 0
  select count(*) from v\$session where action = 'CPUG V1 Run' and status = 'ACTIVE';
  exit
  " | sqlplus -s / as sysdba | awk '{print $1}')
check

# main
if [[ ! ${PSCHECK} ]]; then
  if [[ ${ACTSES} == 0 ]]; then
    ERRMSG="Error(s) encountered while initiating CPU Gen processes."
    printf "\n==============================================\n" >> ${LOG} 2>&1
    printf "No active sessions were found of the previous iteration of the script so we can assume that it ended.\n" >> ${LOG} 2>&1
    printf "==============================================\n\n" >> ${LOG} 2>&1
    printf "==============================================\n" >> ${LOG} 2>&1
    printf "Starting a new one on ${SID} at $(date "+%d %b %Y %H:%M:%S") with ${PROCESS} processes.\n" >> ${LOG} 2>&1
    printf "==============================================\n" >> ${LOG} 2>&1
    for (( count=0; count<${PROCESS}; count++ )); do
sqlplus -s /nolog @${CURRDIR}/cpu.sql << EOF &
EOF
    done
    check
    sleep 30
    PIDS=$(printf "
    set head off verify off trimspool on feed off line 2000 pagesize 100 newpage none
    set numformat 9999999999999999999
    set pages 0
    with s as
    (select b.spid as c
      from v\$session a, v\$process b
      where a.action = 'CPUG V1 Run' and a.status = 'ACTIVE'
      and a.paddr = b.addr
    )
    select str
      from
      (select ltrim(sys_connect_by_path(c, ' '), ' ') str, connect_by_isleaf islf
        from (select rownum rn, c from s)
        start with rn = 1  
        connect by prior rn = rn - 1
      )  
    where islf = 1;
    exit
    " | sqlplus -s / as sysdba | grep .)
    if [[ ${#PIDS} != 0 ]]; then
      printf "CPU Gen started with these pid(s):\n" >> ${LOG} 2>&1
      printf "${PIDS}\n\n" >> ${LOG} 2>&1
      KILLPS=$(echo "kill -9 ${PIDS}")
      printf "You can kill them with the following command:\n" >> ${LOG} 2>&1
      printf "${KILLPS}\n" >> ${LOG} 2>&1
    fi
  fi
fi
