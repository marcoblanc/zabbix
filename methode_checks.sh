#!/bin/bash
# version 1.8
#   added a new check on the snapshot size  
# version 1.7
#   bug fix:
#   - eomdb_sessions now correctly connects using the right ior for the specified eomdb
# version 1.6
#   fixed a bug handling the tomcat name, differentiating if the name contains "_" or "-"
# version 1.5
#   for better performance, now it calls an improved version of the SHC python script to check the autonomy indextime
# version 1.4
#   script by Marco Bianchi & Claudio Zumbo & Kabir Sala

# usage NOME_SCRIPT user process check

CHECK=$1
METHUSER=$2

#default functions set
function pidname {
#       if [[ "${PROC}" =~ "DRE"[0-9] ]]
#       then
#               PROC=/${PROC}.exe
        if [[ "${PROC}" == "cleanbe" ]]
        then
                PROC="versant1"
        elif [[ "${PROC}" == "obe" ]]
        then
                PROC="versant2"
#        elif [[ "${PROC}" == "eomnc" ]]
#        then
#                PROC="notification"
#        elif [[ "${PROC}" =~ "eomnc"[0-9] ]]
#        then
#                PROC="notification"$(echo ${PROC} | sed -e 's/[A-Za-z]*//g')
        elif [[ "${PROC}" =~ "eoma"[0-9] ]]
        then
                PROC="alerter"$(echo ${PROC} | sed -e 's/[A-Za-z]*//g')
        elif [[ "${PROC}" =~ "eomja"[0-9] ]]
        then
                PROC="alerter"$(echo ${PROC} | sed -e 's/[A-Za-z]*//g')
        elif [[ "${PROC}" =~ "tomcat" ]]
        then
            if [[ ! -f /methode/${METHUSER}/cluster/pids/${PROC}.pid ]]
            then
                PROC=$(echo ${PROC} | sed -e 's/\-/\_/g')
            fi
        fi
}

function envvar {
        METHUSR=$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^"METHUSR" | sed 's/\"//g' | cut -d "=" -f 2 )
        METHPWD=$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^"METHPWD" | sed 's/\"//g' | cut -d "=" -f 2 )
        BINDIR=$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^"BINDIR" | sed 's/\"//g' | cut -d "=" -f 2 )
        IORDIR=$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^"IORDIR" | sed 's/\"//g' | cut -d "=" -f 2 )
        DB=$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^"DB=" | sed 's/\"//g' | cut -d "=" -f 2 )

}

function getenv {
        local METHUSER=$1; shift
        local VAR=$1; shift

        echo $(runuser -l ${METHUSER} -c "bash -c env | egrep "^${VAR}" | cut -d"=" -f2")
}

function threads {
    pidname
        ps -eo pid,thcount | grep $(cat /methode/${METHUSER}/cluster/pids/${PROC}.pid)| awk '{print $2}'
}
function file_descriptors {
    pidname
        ls -1 /proc/$(cat /methode/${METHUSER}/cluster/pids/${PROC}.pid)/fd/ | wc -l
}
function cpu_usage {
    pidname
        ps -eo pid,%cpu | grep $(cat /methode/${METHUSER}/cluster/pids/${PROC}.pid) | awk '{print $2}'
}
function virtual_memory {
    pidname
        ps -eo pid,vsz | grep $(cat /methode/${METHUSER}/cluster/pids/${PROC}.pid) | awk '{print $2}'
}
function resident_memory {
    pidname
        ps -eo pid,rss | grep $(cat /methode/${METHUSER}/cluster/pids/${PROC}.pid) | awk '{print $2}'
}
function versant_sessions {
        envvar
        /sbin/runuser -l ${METHUSER} -c "dbtool -nosession -sys -info -resource $DB | grep Obe-thrd| wc -l"
}
function versant_rootpages {
        envvar
        /sbin/runuser -l ${METHUSER} -c "dbtool -nosession -AT -info -rootpages $DB | tail -n 2 | head -n 1 | awk '{print \$4}'" 
}
function versant_transactions {
        envvar
        /sbin/runuser -l ${METHUSER} -c "dbtool -nosession -trans -info $DB | grep $(cat /methode/${METHUSER}/cluster/pids/versant1.pid) | wc -l"
}
function versant_freespace {
        envvar
        /sbin/runuser -l ${METHUSER} -c "dbtool -nosession -space -volume -all $DB | grep -i total | cut -d ":" -f 2 | sed -e 's/\ //g' -e 's/KB//g'"
}
function versant_freespace_perc {
        envvar
        /sbin/runuser -l ${METHUSER} -c "dbtool -nosession -space -volume -all $DB | grep -i percentage | cut -d ":" -f 2 | sed -e 's/\ //g' -e 's/\%//g'"
}
function habackup {
        HALOG="$(ls /methode/${METHUSER}/logfiles/ | grep habackup)"
        /sbin/runuser -l ${METHUSER} -c "tac /methode/${METHUSER}/logfiles/habackup_versant.log | grep -m1 -i -A3 shc | grep real | cut -d \"m\" -f 2 | sed -e 's/s//g'"
}
function eomdb_sessions {
        envvar
        PROCNUM="$(echo ${PROC} | sed 's/[^0-9]*//g')"
        PROCVERS="$(ls -l /methode/${METHUSER}/bin/eomdb | rev | cut -d " " -f -1 | rev | cut -d "_" -f 2 | cut -d "." -f 1)"
#       /sbin/runuser -l ${METHUSER} -c "/methode/hotline/shc/scripts/Python/python /methode/hotline/shc/scripts/eomdb_sessions -n ${PROC}NUM -v ${PROC}VERS -i S " 2>/dev/null
        if [ "${PROC}VERS" -le 4 ]
                then 
                /sbin/runuser -l ${METHUSER} -c "$BINDIR/emsessions -outfile /tmp/info_eomdb${PROC}NUM${METHUSER} -eomuser $METHUSR -eompassword $METHPWD -eomrepositoryior $IORDIR/eomdb${PROCNUM}.ior" 2>/dev/null
                grep Session /tmp/info_eomdb${PROC}NUM${METHUSER} | wc -l
                rm -f /tmp/info_eomdb${PROC}NUM${METHUSER}
        else
                /sbin/runuser -l ${METHUSER} -c "$BINDIR/eomutil sessions -outfile /tmp/info_eomdb${PROC}NUM${METHUSER} -eomuser $METHUSR -eompassword $METHPWD -eomrepositoryior $IORDIR/eomdb${PROCNUM}.ior" 2>/dev/null
                grep Session /tmp/info_eomdb${PROC}NUM${METHUSER} | wc -l
                rm -f /tmp/info_eomdb${PROC}NUM${METHUSER}
        fi
}
function eomdb_users {
        envvar
        PROCNUM="$(echo ${PROC} | sed 's/[^0-9]*//g')"
        PROCVERS="$(ls -l /methode/${METHUSER}/bin/eomdb | rev | cut -d " " -f -1 | rev | cut -d "_" -f 2 | cut -d "." -f 1)"
#       /sbin/runuser -l ${METHUSER} -c "/methode/hotline/shc/scripts/Python/python /methode/hotline/shc/scripts/eomdb_sessions -n ${PROC}NUM -v ${PROC}VERS -i S " 2>/dev/null
        if [ "${PROC}VERS" -le 4 ]
                then 
                /sbin/runuser -l ${METHUSER} -c "$BINDIR/emsessions -outfile /tmp/info_eomdb${PROC}NUM${METHUSER} -eomuser $METHUSR -eompassword $METHPWD -eomrepositoryior $IORDIR/eomdb1.ior" 2>/dev/null
                grep User /tmp/info_eomdb${PROC}NUM${METHUSER} | wc -l
                rm -f /tmp/info_eomdb${PROC}NUM${METHUSER}
        else
                /sbin/runuser -l ${METHUSER} -c "$BINDIR/eomutil sessions -outfile /tmp/info_eomdb${PROC}NUM${METHUSER} -eomuser $METHUSR -eompassword $METHPWD -eomrepositoryior $IORDIR/eomdb1.ior" 2>/dev/null
                grep User /tmp/info_eomdb${PROC}NUM${METHUSER} | wc -l
                rm -f /tmp/info_eomdb${PROC}NUM${METHUSER}
        fi
}
function eoma_queue {
        PROCNUM="$(echo ${PROC} | sed 's/[^0-9]*//g')"
        EOMA_INDEXDIR="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^"EOMA${PROCNUM}_INDEXDIR=" | sed 's/\"//g' | cut -d "=" -f 2 )"
        ls -l $EOMA_INDEXDIR | grep -v ^d | wc -l
}
function eomse_queue {
        PROCNUM="$(echo ${PROC} | sed 's/[^0-9]*//g')"
        if [[ -f /methode/${METHUSER}/bin/eomjs.bash ]]
        then
                PID="$(cat /methode/${METHUSER}/cluster/pids/eomjse${PROCNUM}.pid)"
                /sbin/runuser -l ${METHUSER} -c "eomjsestat.bash -p ${PID} | grep '\.QueuesUsedLogicalBlocks' | cut -d ',' -f 2 " 
        else
                EOMSE_INDEXDIR="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^"EOMSE${PROCNUM}_INDEXDIR=" | sed 's/\"//g' | cut -d "=" -f 2 )"
                ls -1 ${EOMSE_INDEXDIR} | wc -l
        fi
        #/sbin/runuser -l ${METHUSER} -c "/methode/hotline/shc/scripts/Python/python /methode/hotline/shc/scripts/eomse_queue -n ${PROC}NUM" 2>/dev/null

}
function autonomy_documents {
    DREIP="$(getenv ${METHUSER} "${PROC}"_IP)"
    DREPORT="$(getenv ${METHUSER} "${PROC}"_PORT)"
        echo $(curl -s "http://${DREIP}:${DREPORT}/action=getStatus&format=html" | grep "documents" | egrep -o "[0-9]*")
}
function autonomy_fragmentation {
    DREIP="$(getenv ${METHUSER} "${PROC}"_IP)"
    DREPORT="$(getenv ${METHUSER} "${PROC}"_PORT)"
        COMMITTED_DOCS=$(curl -s "http://${DREIP}:${DREPORT}/action=getStatus&format=html" | grep "committed document slots" | egrep -o "[0-9]*")
        DOC_SECTIONS=$(curl -s "http://${DREIP}:${DREPORT}/action=getStatus&format=html" | grep "document sections" | egrep -o "[0-9]*")
        if [ "$COMMITTED_DOCS" -eq "0" ] 
                then
                BASE="1"
        else
                BASE="$COMMITTED_DOCS"
        fi
        echo "scale=2; ( $COMMITTED_DOCS - $DOC_SECTIONS ) / $BASE" | bc -l
}
function autonomy_indextime {
    DREIP="$(getenv ${METHUSER} "${PROC}"_IP)"
    DREPORT="$(getenv ${METHUSER} "${PROC}"_PORT)"
###    DURATION_SECS=$(curl -s "http://${DREIP}:${DREPORT}/action=indexergetstatus" | grep -oP "<duration_secs>.*?</duration_secs>" | cut -d ">" -f2 | cut -d "<" -f1 | paste -sd+ - | bc )
###    DOCUMENTS_PROCESSED=$(curl -s "http://${DREIP}:${DREPORT}/action=indexergetstatus" | grep -oP "<documents_processed>.*?</documents_processed>" | cut -d ">" -f2 | cut -d "<" -f1 | paste -sd+ - | bc )
###    DOCUMENTS_DELETED=$(curl -s "http://${DREIP}:${DREPORT}/action=indexergetstatus" | grep -oP "<documents_deleted>.*?</documents_deleted>" | cut -d ">" -f2 | cut -d "<" -f1 | paste -sd+ - | bc )
###    #echo "scale=2; ${DURATION_SECS} / ( ${DOCUMENTS_DELETED} + ${DOCUMENTS_PROCESSED} )" | bc -l
###    echo "${DURATION_SECS} / ( ${DOCUMENTS_DELETED} + ${DOCUMENTS_PROCESSED} )" | bc -l
        /sbin/runuser -l ${METHUSER} -c "/methode/hotline/shc/scripts/Python/python /etc/zabbix/scripts/autonomy_indextime.py -u http://$DREIP:$DREPORT" 2>/dev/null
}
function autonomy_query {
        DREIP="$(getenv ${METHUSER} "${PROC}"_IP)"
    DREPORT="$(getenv ${METHUSER} "${PROC}"_PORT)"
        /sbin/runuser -l ${METHUSER} -c "/methode/hotline/shc/scripts/Python/python /etc/zabbix/scripts/autonomy_query.py -u http://$DREIP:$DREPORT -s 300 -n" 2>/dev/null
}
function autonomy_querytime {
        DREIP="$(getenv ${METHUSER} "${PROC}"_IP)"
    DREPORT="$(getenv ${METHUSER} "${PROC}"_PORT)"
        /sbin/runuser -l ${METHUSER} -c "/methode/hotline/shc/scripts/Python/python /etc/zabbix/scripts/autonomy_query.py -u http://$DREIP:$DREPORT -s 300" 2>/dev/null
}
function goldcopy {
        if grep VOLUME_DB /methode/${METHUSER}/.bash_profile >/dev/null
        then
                DBVOL="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" | grep ^VOLUME_DB= | cut -d "=" -f 2 )"
        elif grep VOLUME /methode/${METHUSER}/.bash_profile >/dev/null
        then
                DBVOL="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" | grep ^VOLUME= | cut -d "=" -f 2 )"
        else
                error_msg
        fi
        NETAPP="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^FILER= | cut -d "=" -f 2 )"
        last_snap=$(/sbin/runuser -l ${METHUSER} -c "rsh $NETAPP snap list -n $DBVOL" 2>/dev/null | grep ${METHUSER} | grep -v "Volume" | grep "goldcopy" | head -1)
#        last_snap=$(/methode/common/backups/goldcopy/listSnap_script ${METHJUSER} | grep GOOD | head -1)
        last_snap_time=$(date --date="$(echo "${last_snap}" | cut -d" " -f-3)" +"%s")
        diff=$(( ( $(date "+%s") - ${last_snap_time} ) ))
        echo "${diff}"
}
function snapshot {
        if grep VOLUME_DB /methode/${METHUSER}/.bash_profile >/dev/null
        then
                DBVOL="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" | grep ^VOLUME_DB= | cut -d "=" -f 2 )"
        elif grep VOLUME /methode/${METHUSER}/.bash_profile >/dev/null
        then
                DBVOL="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" | grep ^VOLUME= | cut -d "=" -f 2 )"
        else
                error_msg
        fi
        NETAPP="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^FILER= | cut -d "=" -f 2 )"
        last_snap=$(/sbin/runuser -l ${METHUSER} -c "rsh $NETAPP snap list -n $DBVOL" 2>/dev/null | grep ${METHUSER} | grep -v "Volume" | head -1)
        last_snap_time=$(date --date="$(echo "${last_snap}" | cut -d" " -f-3)" +"%s")
        diff=$(( ( $(date "+%s") - ${last_snap_time} ) ))
        echo "${diff}"
}
function snapmirror {
        if grep VOLUME_DB /methode/${METHUSER}/.bash_profile >/dev/null
        then
                DBVOL="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" | grep ^VOLUME_DB= | cut -d "=" -f 2 )"
        elif grep VOLUME /methode/${METHUSER}/.bash_profile >/dev/null
        then
                DBVOL="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" | grep ^VOLUME= | cut -d "=" -f 2 )"
        else
                error_msg
        fi
        NETAPP="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^FILER= | cut -d "=" -f 2 )"
        last_snap=$(/sbin/runuser -l ${METHUSER} -c "rsh $NETAPP snapmirror status -l $DBVOL"  | grep "Mirror Timestamp" | perl -pe "s#\s{2,}# #g" | cut -d" " -f3-)
        last_snap_time=$(date --date="${last_snap}" +"%s")
        diff=$(( ( $(date "+%s") - ${last_snap_time} ) ))
        echo "${diff}"
        #/sbin/runuser -l ${METHUSER} -c "/methode/hotline/shc/scripts/get_last_snapmirror.bash ${METHUSER} $DBVOL $NETAPP 1" 2>/dev/null | awk 'FNR==2 {print}'
}
function snapmirror_size {
        if grep VOLUME_DB /methode/${METHUSER}/.bash_profile >/dev/null
        then
                DBVOL="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" | grep ^VOLUME_DB= | cut -d "=" -f 2 )"
        elif grep VOLUME /methode/${METHUSER}/.bash_profile >/dev/null
        then
                DBVOL="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" | grep ^VOLUME= | cut -d "=" -f 2 )"
        else
                error_msg
        fi
        NETAPP="$(/sbin/runuser -l ${METHUSER} -c "bash -c env" 2>/dev/null | grep ^FILER= | cut -d "=" -f 2 )"
        last_snap=$(/sbin/runuser -l ${METHUSER} -c "rsh ${NETAPP} snapmirror status -l ${DBVOL}"  | grep "Last Transfer Size" | perl -pe "s#\s{2,}# #g" | cut -d" " -f4)
        last_snap_mb=$((last_snap*1024))
        echo "${last_snap_mb}"
}

function snap_usage {
        # execute a simple "df -h" on the filer to get the actual percent of the size of the snapshot folder.
        SNAP_CHECK=$(rsh ${FILER} df -h ${1}| grep snapshot | awk '{print $5}' | sed -e 's/%/ /g')
        /sbin/runuser -l ${METHUSER} -c '${SNAP_CHECK}'
}

# check if there are 2 arguments

if [[ -z "$1" ]] || [[ -z "$2" ]] 
then
        error_msg
fi

case "$CHECK" in
        threads)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                threads ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        file_descriptors)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                file_descriptors ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;
         
        cpu_usage)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                cpu_usage ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        virtual_memory)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                virtual_memory ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        resident_memory)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                resident_memory ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        versant_sessions)
            versant_sessions ${METHUSER}
            ;;

        versant_rootpages)
            versant_rootpages ${METHUSER}
            ;;

        versant_transactions)
            versant_transactions ${METHUSER}
            ;;

        versant_freespace)
            versant_freespace ${METHUSER}
            ;;

        versant_freespace_perc)
            versant_freespace_perc ${METHUSER}
            ;;

        habackup)
            habackup ${METHUSER}
            ;;

        eomdb_sessions)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                eomdb_sessions ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        eomdb_users)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                eomdb_users ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        eoma_queue)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                eoma_queue ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        eomse_queue)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                eomse_queue ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        autonomy_documents)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                autonomy_documents ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        autonomy_fragmentation)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                autonomy_fragmentation ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        autonomy_indextime)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                autonomy_indextime ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        autonomy_query)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                autonomy_query ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        autonomy_querytime)
                        if [[ -n "$3" ]]
                        then
                                PROC=$3
                autonomy_querytime ${PROC} ${METHUSER}
                else
                        echo "Missing process name"
                        exit 1
                fi
            ;;

        goldcopy)
            goldcopy ${METHUSER}
            ;;

        snapshot)
            snapshot ${METHUSER}
            ;;

        snapmirror)
            snapmirror ${METHUSER}
            ;;

        snapmirror_size)
            snapmirror_size ${METHUSER}
            ;;

        snap_usage)
            if [[ -n "$3" ]]
            then
                VOL=${3}
                snap_usage ${METHUSER} ${VOL}
            else
            echo "Missing volume name"
            exit 1
            fi
            ;;

        -h)
                        help_usage
                        ;;

        *)
            echo $"Usage: $0 [CHECK_NAME] [USER] ..."
            exit 1
 
esac
exit 0
