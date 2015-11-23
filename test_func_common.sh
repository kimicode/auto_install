#!/bin/bash
#########################################################################
# Author: lincolnlin
# Created Time: Sun 02 Sep 2012 12:34:03 AM CST
# File Name: test_func_common.sh
# Description: 
#########################################################################
WORKDIR=$( dirname $0 )
cd "$WORKDIR"
export WORKDIR="$(pwd)"

if [[ ! -r "$WORKDIR/func-common.sh" ]]; then
    echo "ERROR: $WORKDIR/func-common.sh NOT FOUND"
fi

. "$WORKDIR/func-common.sh"

logmsg "$0 STARTED"


wait

set -x 

$localip=$(get_localip())

logmsg "end";
