#!/bin/bash
if [[ "$1" != "normaltest" ]]; then
    isVersiontest=1
    logfile="versiontest.log"
    tmplog=./versiontest_tmp.log
else
    isVersiontest=0
    logfile="gotest.log"
    tmplog=./gotest_tmp.log
fi

rm -f $logfile

go env -w GO111MODULE=off
export PATH=$PATH:`pwd`/../../../build/bin:`pwd`/../../../bin

srcroot=`pwd`/../../../
govendor=`pwd`/../../thirdparty/govendor/
export GOPATH=$srcroot:$govendor
echo $GOPATH
function lm_traverse_dir(){
    for file in `ls $1`
    do
        if [ -d $1"/"$file ]
        then
            lm_traverse_dir $1"/"$file
        else  
            file_name=$1"/"$file
            echo "===== $file_name ====="
            cat $file_name
            rm -rf $file_name
        fi
    done
}

function runOne() {
    rm $tmplog
    if [[ "${isVersiontest}" == "1" ]]; then
    cmd=$@
    ./clear.sh versiontest
    else
    cmd=$1
    ./clear.sh
    fi
    echo "" >> $logfile
    echo "###### $cmd begin ######" >> $logfile

    $cmd >> $tmplog 2>&1
    cat $tmplog
    cat $tmplog >> $logfile

    lm_traverse_dir running

    passcnt=`grep "go passed" $tmplog|wc -l`
    if [ $passcnt -lt 1 ]; then
        echo grep 'go passed' failed
        echo "##### $cmd execute failed, no find passed in $tmplog"
        exit 1
    fi
}

if [[ "${isVersiontest}" == "1" ]]; then
    rm -rf versiontest
    go build versiontest.go common.go common_cluster.go
    runOne "./versiontest $@"
else
    rm -rf adminHeartbeat repl repltest restore restoretest clustertest clustertestRestore clustertestFailover deletefilesinrange dts/dts dts/dts_sync memorylimit
    go build adminHeartbeat.go common.go common_cluster.go
    go build repl.go common.go
    go build repltest.go common.go
    go build restore.go common.go
    go build restoretest.go common.go
    go build clustertest.go common.go common_cluster.go
    go build clustertestRestore.go common.go common_cluster.go
    go build clustertestFailover.go common.go common_cluster.go
    go build deletefilesinrange.go common.go common_cluster.go
    go build -o dts/dts dts/dts.go
    go build -o dts/dts_sync dts/dts_sync.go
    go build memorylimit.go common.go

    testNum=12

    runOne ./adminHeartbeat
    runOne ./repl
    runOne ./repltest
    runOne ./restore
    runOne ./restoretest
    runOne './clustertest -benchtype=set -clusterNodeNum=5 -num1=10000'
    #runOne './clustertest -benchtype=sadd -clusterNodeNum=5 -num1=10000'
    #runOne './clustertest -benchtype=hmset -clusterNodeNum=5 -num1=10000'
    #runOne './clustertest -benchtype=rpush -clusterNodeNum=5 -num1=10000'
    #runOne './clustertest -benchtype=zadd -clusterNodeNum=5 -num1=10000'
    runOne './clustertestRestore -benchtype=set'
    runOne './clustertestFailover -benchtype=set'
    runOne './dts/dts'
    runOne './dts/dts_sync'
    runOne './deletefilesinrange -benchtype=set'
    runOne ./memorylimit
fi

grep "go passed" $logfile
grep -E "\[error\]|\[fatal\]" $logfile
