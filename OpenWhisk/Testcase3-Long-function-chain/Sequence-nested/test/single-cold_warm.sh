#!/bin/bash
#
# Copyright (c) 2020 Institution of Parallel and Distributed System, Shanghai Jiao Tong University
# ServerlessBench is licensed under the Mulan PSL v1.
# You can use this software according to the terms and conditions of the Mulan PSL v1.
# You may obtain a copy of Mulan PSL v1 at:
#     http://license.coscl.org.cn/MulanPSL
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR
# PURPOSE.
# See the Mulan PSL v1 for more details.
#

function killPods () {
    echo "Kill the running pods..."
    kubectl -n openwhisk delete pods -l invoker
    sleep 30
    # sinon openwhisk pense que le pod est tjrs en cours d'execution
    # et il tente un warm start, le temps d'expiration des pod invoqués
    # est paramétré sur 15 secondes pour le moment.
}

source eval-config
PRINTLOG=false
WARMUPONLY=false
RUNONLY=false
while getopts "r:m:t:w:lWR" OPT; do
    case $OPT in
    # Mode: cold or warm.
    r)
        RESULT=$OPTARG
        ;;
    m)
        MODE=$OPTARG
        if [[ $MODE != 'cold' && $MODE != 'warm' ]] ;then
            echo "usage: "
            echo "./single-cold_warm -m <mode> -t <loop times> -w <warm ups>"
            echo 'mode: warm, cold'
            exit
        fi
        ;;
    
    # The loop time
    t)
        TIMES=$OPTARG
        expr $TIMES + 0 &>/dev/null
        if [[ $? != 0 ]] || [[ $TIMES -lt 1 ]]; then
            echo "Error: loop times must be a positive integer"
            exit
        fi
        ;;
    
    # The warm up times
    w)
        WARMUP=$OPTARG
        expr $WARMUP + 0 &>/dev/null
        if [[ $? != 0 ]] || [[ $WARMUP -lt 1 ]]; then
            echo "Error: warm up times must be a positive integer"
            exit
        fi
        ;;

    # Output the results to the log with this argument.
    l)
        PRINTLOG=true
        LOGFILE=$ACTIONNAME-$MODE.csv
        ;;

    # "Warm up only" with this argument: warm up and then exit with no output.
    W)
        if [[ $RUNONLY = true || $MODE = "cold" ]]; then
            echo "Error: contradictory arguments"
            exit
        fi
        echo "Warm up only mode."
        WARMUPONLY=true
        ;;
    
    # "Run only" with this argument: invoke the first action without warm up. Paused containers are needed.
    R)
        if [[ $WARMUPONLY = true ]]; then
            echo "Error: contradictory arguments"
            exit
        fi
        # If there's no paused container, the mode should not be supported
        if [[ -z `kubectl -n openwhisk get pods -l invoker -o name` && $containerFactory = "kubernetes" ]]; then
            echo "Error: could not find warmed containers"
            exit
        fi
        echo "Run only mode"
        RUNONLY=true
        WARMUP=0
        ;;
    ?)
        echo "unknown arguments"
    esac
done

if [[ -z $MODE ]];then
    echo "default mode: warm"
    MODE="warm"
fi

if [[ $MODE = "warm" && $prewarm = true ]]; then
    echo "Error : warm mode cannot be used with prewarm"
    exit
fi

if [[ -z $TIMES && $WARMUPONLY = false ]]; then
    if [ $MODE = "warm" ];then
        echo "default warm loop times: 10"
        TIMES=10
    else
        echo "default cold loop times: 3"
        TIMES=3
    fi
fi

if [[ $MODE = "warm" ]] && [[ -z $WARMUP ]] && [[ $RUNONLY = false ]]; then
    echo "default warm up times: 1"
    WARMUP=1
fi

# mode = warm: kill all the running pods and then warm up
if [[ $MODE = "warm" && $RUNONLY = false ]]; then
    echo "Warm up.."
    if [[ -n `kubectl -n openwhisk get pods -l invoker -o name` ]];then
        killPods
    fi
    for i in $(seq 1 $WARMUP)
    do
        echo "The $i-th warmup..."
        wsk -i action invoke $ACTIONNAME -b -r $PARAMS > /dev/null
    done
    echo "Warm up complete"
    if [[ $WARMUPONLY = true ]]; then
        echo "No real action is needed."
        exit
    fi
fi


if [[ $PRINTLOG = true && ! -e $LOGFILE ]]; then
    echo logfile:$LOGFILE
    echo "invokeTime,endTime,latency" > $LOGFILE
fi

LATENCYSUM=0

for i in $(seq 1 $TIMES)
do
    if [[ $MODE = 'cold' && $prewarm = false ]]; then
        if [[ -n `kubectl -n openwhisk get pods -l invoker -o name` ]];then
            killPods
        fi
    fi
    if [[ $containerFactory = "kubernetes" && $prewarm = true && -z `kubectl -n openwhisk get pods -l invoker | grep prewarm` ]]; then
        echo "Error: no prewarm pod found"
        exit
    fi
    if [[ $prewarm = true ]]; then
        echo "cold start with prewarm"
    fi

    echo Measure $MODE start up time: no.$i
    
    invokeTime=`date +%s%3N`
    ActivationIds[$i]=`wsk -i action invoke $ACTIONNAME -b $PARAMS | tail -n +2 | jq -r '.activationId'`
    endTime=`date +%s%3N`
    sleep 5
    OW_SeqDurations[$i]=`wsk -i activation get ${ActivationIds[$i]} | tail -n +2 | jq '.end-.start'`
    echo "invokeTime:$invokeTime, endTime:$endTime, SeqDuration:${OW_SeqDurations[$i]}"

    latency=`expr $endTime - $invokeTime`
    LATENCIES[$i]=$latency

    if [[ $PRINTLOG = true ]];then
        echo "$invokeTime,$endTime,$latency" >> $LOGFILE
    fi
done


if [ ! -z $RESULT ]; then
    echo -e "\n\n------------------ result ---------------------\n" >> $RESULT
    echo "mode: $MODE, loop_times: $TIMES, warmup_times: $WARMUP" >> $RESULT
    echo "Latency (ms): ${LATENCIES[*]}" >> $RESULT
    echo -e "OW_SeqDurations (ms): ${OW_SeqDurations[*]}" >> $RESULT
fi
