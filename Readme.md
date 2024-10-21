# CAST AI hibernate v2
This helm chart can be used to trigger hibernate / resume jobs by using the CAST AI hibernate v2 api endpoint

## how to deploy
```
helm upgrade -i mycluster ./charts/castai-hibernate-v2 \
  -n castai-agent \
  --create-namespace \
  --set apiKey="<castai api key>" \
  --set clusterId="<castai cluster id>"
```
