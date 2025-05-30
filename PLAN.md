
## Non-Negotiable Reality Check (read twice)

| Truth                                                                                                               | Consequence                                                                               |
| ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **“Automated DR”** means the system must **decide** and **act** on a live cluster, not just chart pretty anomalies. | Detection **plus** at least **one** safe remediation loop *must ship*.                    |
| Jenkins isn’t optional.                                                                                             | A declarative Jenkinsfile has to build, test, and push every component.                   |
| Your thesis clock is ticking.                                                                                       | Anything that isn’t required for the above two bullets is a distraction and must die now. |

If you can’t defend those statements, **stop** and renegotiate scope with your supervisor today.

---


## Component Specs (no more, no less)

| Component                  | Responsibilities                                                                                                                                                                                                                     | Tech Choice                                                               |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| **etcd metrics collector** | scrape `https://127.0.0.1:2381/metrics` on master, push `db_size_bytes`, `etcd_server_leader_changes_seen_total`, etc. to Pushgateway every 60 s.                                                                                    | Tiny Go binary or Python + `prometheus-client`.                           |
| **detector service**       | Pull last 30 × 60 s vectors from Prometheus HTTP API, feed into PyTorch LSTM auto-encoder, return anomaly score.                                                                                                                     | PyTorch 2.3, TorchScript export; runs as ClusterIP service.               |
| **Kopf DR operator**       | Subscribe to detector via HTTP polling or PrometheusRule + Alertmanager webhook.<br>When `score > τ` **and** `etcd_health==ok` → 1) `etcdctl snapshot save …`, 2) `etcdctl defrag`, 3) if health bad after X sec → restore snapshot. | Python 3.11, Kopf 1.x.                                                    |
| **Helm charts**            | 3 sub-charts with sane defaults; single parent `dr-stack`.                                                                                                                                                                           | Values.yaml, kube-score clean.                                            |
| **Notebook**               | • Load 24 h Prometheus dump (CSV).<br>• Explain RNN math with minimal calculus (chain rule, gradients).<br>• Train AE, tune τ via ROC.<br>• TorchScript export block.                                                                | PyTorch; optional TensorBoard.                                            |
| **Jenkins Pipeline**       | Stages: lint → unit-tests → build images → spin kind → helm install → functional test (failure injection) → push images.                                                                                                             | Jenkinsfile (Declarative Pipeline), `docker --network host kindest/node`. |

---

## Jenkins CI Design (Standard)

```groovy
pipeline {
  agent { label 'docker-large' }

  environment {
    REG = 'ghcr.io/yourorg'
    KIND_CLUSTER = 'ci-dr'
  }

  stages {
    stage('Lint')      { steps { sh 'helm lint charts/*' } }
    stage('Unit')      { steps { sh 'pytest -q collector tests/' } }
    stage('Build')     { steps { sh './scripts/build_all.sh $REG $BUILD_NUMBER' } }
    stage('Kind Up')   { steps { sh './ci/kind_up.sh $KIND_CLUSTER' } }
    stage('E2E Test')  { steps { sh './ci/e2e_test.sh $KIND_CLUSTER' } }
    stage('Push')      { when { branch 'main' }
                         steps { sh './scripts/push_all.sh $REG $BUILD_NUMBER' } }
  }

  post { always { sh './ci/kind_down.sh $KIND_CLUSTER' } }
}
```

*Everything* goes through this pipeline—no manual docker pushes, no “works-on-my-laptop.”

---

## How the Automated DR Flow Demonstrates Itself

1. Jenkins E2E stage spins `kind`, installs chart.
2. Script induces etcd stress (`etcdctl put bigkey …` in loop).
3. Detector score crosses τ → Alert fires → Kopf operator snapshot+restore.
4. Test asserts cluster returns to Ready within 120 s (`kubectl get cs`).
5. Pipeline marks build green. **That artifact is your proof of DR automation.**

---

## Notebook Learning Outcomes 

| Step                       | Core Concept                                                                        |
| -------------------------- | ----------------------------------------------------------------------------------- |
| **Vector prep**            | Normalisation, windowing – why time-series differ from tabular.                     |
| **LSTM cell recap**        | Show equations, but rely on PyTorch autograd; emphasise gates, hidden state.        |
| **Auto-Encoder rationale** | Reconstruction error, MSE as anomaly score.                                         |
| **Threshold selection**    | ROC, AUC, Youden’s J – *basic yet rigorous*.                                        |
| **Export**                 | `traced = torch.jit.trace(model, dummy); traced.save()` – integrates with detector. |

PyTorch handles gradients.

---

## Deliverables

| Day | Deliverable                                                     | “Definition of Done” Check                           |
| --- | --------------------------------------------------------------- | ---------------------------------------------------- |
| 1   | Repo purge + new structure                                      | `git status` clean; README with north-star sentence. |
| 2   | Terraform single node                                           | `kubectl get nodes` Ready on AWS.                    |
| 3   | Ansible installs kube-prometheus & etcd metric endpoint exposed | Prometheus chart UI accessible.                      |
| 4   | Collector image & Helm chart                                    | `snapshot_success_total` increments in Prometheus.   |
| 5   | Jenkinsfile skeleton runs Lint + Unit + Kind-up                 | Jenkins green build #1.                              |
| 6   | Notebook sections 0-3 complete, sample data committed (≤10 MB)  | Colab runtime < 5 min.                               |
| 7   | PyTorch AE training + TorchScript export + detector image       | Local `curl /score` returns float.                   |
| 8   | Kopf operator minimal restore action (fake) + Helm chart        | Kind E2E script asserts operator callback.           |
| 9   | Real restore using `etcdctl` snapshot in kind                   | E2E green, MTTR < 120 s.                             |
| 10  | Polish docs, tag `v0.1.0`                                       | Fresh clone → pipeline green first try.              |



---

## Plan

*No extra `YAML`, or rewrite of `Ansible` smartness.*

Stick to **one metric, one model, one action, one CI pipeline**. To end with:

1. A working automated DR loop on kubeadm.
2. A Jenkins pipeline your supervisor can run.
3. A PyTorch notebook that actually teaches AI fundamentals.

Finish that, and the “harshest critic” (future interviewers, reviewers, or even yourself) will have nothing left to hate.
