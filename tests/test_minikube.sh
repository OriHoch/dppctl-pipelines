#!/usr/bin/env bash

! ID=$(python -c 'import re;import uuid;print(re.sub("-","",str(uuid.uuid4())))') && echo failed to get ID && exit 1
echo ID=$ID

INSTALL_ARGS=". -n dppctl-pipelines-$ID --set id=$ID \
              --set workload=minio --set dataSyncer=minio \
              --set dppRunParams=./noise --set postPipelinesSleepSeconds=600 \
              --set enableInfo=1"

! helm install $INSTALL_ARGS --dry-run --debug && echo failed helm install dry run && exit 1

! helm install $INSTALL_ARGS && echo failed helm install && exit 1

echo waiting for minio container
while ! kubectl logs pipeline-$ID -c minio; do sleep 1; done
sleep 1

! kubectl logs pipeline-$ID -c sync && exit 1

! [ -e ./mc ] && curl https://dl.minio.io/client/mc/release/linux-amd64/mc > ./mc && chmod +x ./mc

kubectl port-forward pipeline-$ID 9000 &
PID=$!

./mc config host add dppctl http://localhost:9000 admin 12345678

while ! ./mc ls dppctl/workload/.__dppctl_ready_for_workload__; do sleep 1; done

! ( ./mc cp -q examples/noise/workload/pipeline-spec.yaml dppctl/workload/ &&\
    ./mc cp -q examples/noise/workload/noise.py dppctl/workload/ &&\
    echo "" | ./mc pipe dppctl/workload/.__dppctl_workload_ready__ ) && echo failed to copy the workload && exit 1

kill $PID

sleep 2

while ! kubectl logs pipeline-$ID -c pipeline | tee -a /dev/stderr | grep "done with exit code 0"; do
    sleep 2
done

! kubectl delete pod pipeline-$ID && echo failed to delete pod && exit 1

echo Great Success!
exit 0
