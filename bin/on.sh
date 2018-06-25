#!/bin/bash

CURRENT_NS=""
on()
{
    local nextns=$1
    if ! [ ${nextns} ]; then
        return
    elif [ "$nextns" == "-" ]; then
        on $OLD_NS
        return
    fi

    oc get ns $nextns || return

    OLD_NS=$(sed -ne 's/^<<\([^>]\+\)>>/\1/p' <<<$PS1 || true)
    if [ "${OLD_NS}" ]; then
        export PS1="${PS1/<<*>> /}"
    fi
    export PS1="<<$1>> $PS1"
    alias o="oc -n ${nextns}"
    CURRENT_NS=$nextns
}
