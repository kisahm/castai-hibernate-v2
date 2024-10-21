#!/bin/bash
set -e

if [ "${DEBUG}" == "true" ] ; then
    set -x
fi

if [ -z ${CASTAI_CLUSTER_ID} ] ; then
    echo "ENV variable "CASTAI_CLUSTER_ID" must be defined"
    exit 1
fi

if [ -z ${CASTAI_API_KEY} ] ; then
    echo "ENV variable "CASTAI_API_KEY" must be defined"
    exit 1
fi
CASTAI_API_URL="${CASTAI_API_URL:-https://api.cast.ai}"
CASTAI_HIBERNATE_ACTION="${CASTAI_HIBERNATE_ACTION:-hibernate}"
CASTAI_RESUME_FINAL_RETRIES="${CASTAI_RESUME_FINAL_RETRIES:-10}"
CASTAI_RESUME_FINAL_DELAY="${CASTAI_RESUME_FINAL_DELAY:-30}"
CASTAI_RESUME_INSTANCE_TYPE="${CASTAI_RESUME_INSTANCE_TYPE:-c5a.large}"
CASTAI_RESUME_SPOT_INSTANCE="${CASTAI_RESUME_SPOT_INSTANCE:-false}"
CASTAI_RESUME_SPOT_RETRIES="${CASTAI_RESUME_SPOT_RETRIES:-10}"
CASTAI_RESUME_SPOT_DELAY="${CASTAI_RESUME_SPOT_DELAY:-30}"

wait_for_cluster () {
    local COUNTER=1
    while [ ${COUNTER} -le ${CASTAI_RESUME_SPOT_RETRIES} ]; do 
        echo "$(date) - waiting for cluster (${COUNTER}/${CASTAI_RESUME_SPOT_RETRIES})"
        sleep ${CASTAI_RESUME_SPOT_DELAY}
        CLUSTER_STATUS=$(curl -s -X 'GET' \
            "${CASTAI_API_URL}/v1/kubernetes/external-clusters/${CASTAI_CLUSTER_ID}" \
            -H 'accept: application/json' \
            -H "X-API-Key: ${CASTAI_API_KEY}" | jq -r '.status')
        if [ ${CLUSTER_STATUS} == "ready" ] ; then
            echo "$(date) - cluster is ready"
            return
        fi
        COUNTER=$(( $COUNTER + 1 ))
    done
    SPOT_FAILED=true
}

if [ "${CASTAI_HIBERNATE_ACTION}" == "hibernate" ] ; then
    echo "$(date) - start cluster hibernate"
    curl -s -X 'POST' \
        "${CASTAI_API_URL}/v1/kubernetes/external-clusters/${CASTAI_CLUSTER_ID}/hibernate" \
        -H 'accept: application/json' \
        -H "X-API-Key: ${CASTAI_API_KEY}"
    echo ""
    echo "$(date) - end cluster hibernate"
elif [ "${CASTAI_HIBERNATE_ACTION}" == "resume" ] ; then
    echo "$(date) - start cluster resume"
    curl -s -X 'POST' \
        "${CASTAI_API_URL}/v1/kubernetes/external-clusters/${CASTAI_CLUSTER_ID}/resume" \
        -H 'accept: application/json' \
        -H "X-API-Key: ${CASTAI_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d "{
                \"instanceType\": \"${CASTAI_RESUME_INSTANCE_TYPE}\",
                \"spotConfig\": {
                \"isSpot\": ${CASTAI_RESUME_SPOT_INSTANCE}
                }
            }"
    echo ""
    if [ ${CASTAI_RESUME_SPOT_INSTANCE} ] ; then
        wait_for_cluster
        if [ "${SPOT_FAILED}" == "true" ] ; then
            CLUSTER_STATUS=$(curl -s -X 'GET' \
                "${CASTAI_API_URL}/v1/kubernetes/external-clusters/${CASTAI_CLUSTER_ID}" \
                -H 'accept: application/json' \
                -H "X-API-Key: ${CASTAI_API_KEY}" | jq -r '.status')
            if [ "${CLUSTER_STATUS}" != "ready" ] ; then
                echo "$(date) - fallback to on-demand nodes"
                curl -s -X 'POST' \
                    "${CASTAI_API_URL}/v1/kubernetes/external-clusters/${CASTAI_CLUSTER_ID}/resume" \
                    -H 'accept: application/json' \
                    -H "X-API-Key: ${CASTAI_API_KEY}" \
                    -H 'Content-Type: application/json' \
                    -d "{
                    \"instanceType\": \"${CASTAI_RESUME_INSTANCE_TYPE}\"}"
                echo ""
            fi
            wait_for_cluster
        fi
    fi
    echo "$(date) - end cluster resume"
else
    echo "env variable CASTAI_HIBERNATE_ACTION is not valid"
    exit 1
fi