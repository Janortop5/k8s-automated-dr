# Key Features

Custom Resource Handling: Uses RecoveryConfig CRD to define declarative DR plans
ML Integration Point: Reacts to anomalyScore field changes (where your LSTM model outputs would be fed)
Graduated Recovery Actions: Implements the 4-tier approach you mentioned:

Pod restart (lightest)
Deployment rollback
Node drain (placeholder)
Full Velero restore (placeholder)


Continuous Monitoring: Timer-based health checks that would integrate with Prometheus
SLA-driven Policy: Threshold-based decision making based on anomaly scores

### To use this operator:

Install dependencies:
```bash
pip install kopf kubernetes
```

Create the CRD (you'd need to define this YAML):
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: recoveryconfigs.disasters.k8s-failsafe.io
spec:
  group: disasters.k8s-failsafe.io
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              anomalyThreshold:
                type: number
              targetDeployment:
                type: string
              recoveryActions:
                type: array
```

Run the operator:

```bash
python operator.py
```
This provides a solid foundation that you can extend with your LSTM model integration, Prometheus metrics collection, and Velero backup orchestration as outlined.
