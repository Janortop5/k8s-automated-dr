// pipeline {
//     /* -------------------------------------------------------------- *
//      *  GLOBAL SETTINGS                                               *
//      * -------------------------------------------------------------- */


//     agent any                     // just give me any node that has Docker
//     options {
//         timestamps()
//     }
    
//     parameters {
//         booleanParam(name: 'DEPLOY_STANDBY_ONLY', defaultValue: false, description: 'Deploy only standby environment')
//         booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip test stages')
//     }

//     environment {
//         IMAGE_NAME  = 'lstm-model'
//         IMAGE_TAG   = 'latest'
//         REPOSITORY  = 'freshinit'
//         FULL_IMAGE  = "${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

//         DOCKER_CREDENTIALS     = credentials('dockerhub-pat')
//     }

//     /* -------------------------------------------------------------- *
//      *  STAGES                                                        *
//      * -------------------------------------------------------------- */
//     stages {

//         /* 1. Checkout once, on the host                           */
//         stage('Prepare') {
//           steps {
//             cleanWs()      // kill stale workspace
//             checkout scm   // fresh code
//             stash name: 'repo-source', includes: '**'
//           }
//         }

//         // /* 2. Lint inside a Python container                       */
//         // stage('Lint') {
//         //     agent {
//         //         docker { image 'python:3.11-bullseye'; args  '-u 0:0' }   // ← run as root:root inside the container
                         
//         //     }
//         //     steps {
//         //         sh '''
//         //             # 1. Lightweight virtual environment (lives in workspace, removed by cleanWs())
//         //             python -m venv .venv
//         //             . .venv/bin/activate

//         //             # 2. Tools we need
//         //             pip install --upgrade pip nbqa flake8 autopep8 nbstripout

//         //             # 3. Auto-format whitespace first
//         //             nbqa autopep8 --in-place --aggressive --aggressive k8s-lstm/notebook/lstm-disaster-recovery.ipynb
//         //             autopep8  --in-place --recursive --aggressive --aggressive k8s-lstm/

//         //             # 4. strip notebook outputs **in-place**
//         //             # strip a single notebook
//         //             nbstripout k8s-lstm/notebook/lstm-disaster-recovery.ipynb
//         //             # strip every notebook under k8s-lstm/
//         //             # find k8s-lstm -name '*.ipynb' -exec nbstripout {} +

//         //             # 5. lint the final artefacts
//         //             nbqa flake8 k8s-lstm/notebook/lstm-disaster-recovery.ipynb \
//         //                 --max-line-length 120 --extend-ignore E501,F401,F821
//         //             flake8 k8s-lstm/ --max-line-length 120 --extend-ignore E501,E999
//         //         '''
//         //     }
//         // }

//         // /* 3. Build & push the image (needs DinD)                   */
//         // stage('Build') {
//         //     agent {
//         //         docker { image 'docker:24.0.7'; args  '-v /var/run/docker.sock:/var/run/docker.sock -u 0:0' }
//         //     }
//         //     steps {
//         //         withCredentials([usernamePassword(
//         //                 credentialsId: 'dockerhub-pat',
//         //                 usernameVariable: 'DOCKER_USR',
//         //                 passwordVariable: 'DOCKER_PSW')]) {

//         //             sh '''
//         //                 cd k8s-lstm
//         //                 echo "$DOCKER_PSW" | docker login -u "$DOCKER_USR" --password-stdin
//         //                 docker build -t $FULL_IMAGE .
//         //                 docker push  $FULL_IMAGE
//         //             '''
//         //         }
//         //     }
//         //     post {
//         //         success { echo "✅ Image built and pushed: ${FULL_IMAGE}" }
//         //     }
//         // }

//         /* 4. Deploy with kubectl pod                         */
//         stage('Deploy') {
//             when {
//                 expression { return !params.DEPLOY_STANDBY_ONLY }
//             }
//             agent {
//                 kubernetes {
//                     cloud 'k8s-automated-dr'
//                     yaml """
// apiVersion: v1
// kind: Pod
// spec:
//   serviceAccountName: jenkins-agent
//   containers:
//   - name: jnlp
//     image: jenkins/inbound-agent:latest
//     args: ['\$(JENKINS_SECRET)', '\$(JENKINS_NAME)']
//   - name: kubectl
//     image: bitnami/kubectl:latest
//     command: ["sleep"]
//     args: ["99d"]
//     tty: true
//     securityContext:
//       runAsUser: 1000
//       runAsGroup: 1000
// """
//                     defaultContainer 'kubectl'
//                 }
//             }
//             options { skipDefaultCheckout() }
//             steps {
//                 unstash 'repo-source'
//                 container('kubectl') {
//                     sh '''
//                         echo "🔧 Applying Kubernetes manifests..."
//                         kubectl version
//                         kubectl config view
//                         if kubectl api-resources | grep -q "stresschaos"; then
//                             echo "▶️  Applying Chaos Mesh experiments"
//                             kubectl apply -R -f k8s-manifests/
//                         else
//                             echo "⚠️  Skipping StressChaos objects (CRDs not installed)"
//                         fi
//                     '''
//                 }
//             }
//             post {
//                 success {
//                     echo '✅ Kubernetes manifests applied successfully.'
//                 }
//             }
//         }
        
//         stage('Deploy Standby Terraform') {
//             when {
//                 anyOf {
//                     expression { return params.DEPLOY_STANDBY_ONLY }
//                     // add other conditions if needed
//                 }
//             }

//             agent {
//                 kubernetes {
//                     cloud 'k8s-automated-dr'
//                     yaml """
// apiVersion: v1
// kind: Pod
// spec:
//   serviceAccountName: jenkins-agent
//   containers:
//   - name: jnlp
//     image: jenkins/inbound-agent:latest
//     args: ['\$(JENKINS_SECRET)', '\$(JENKINS_NAME)']

//   - name: tools
//     image: freshinit/jenkins-agent-with-tools:latest
//     command: ["sleep"]
//     args: ["90d"]
//     tty: true
//     securityContext:
//       runAsUser: 1000
//       runAsGroup: 1000
// """
       
//                     defaultContainer 'tools'
//                 }
//             }
//             options { skipDefaultCheckout() }
//             steps {
//                 withCredentials([
//                     file(credentialsId: 'my-ssh-key', variable: 'PEM_KEY_PATH'),
//                     string(credentialsId: 'aws_access_key', variable: 'AWS_ACCESS_KEY'),
//                     string(credentialsId: 'aws_secret_key', variable: 'AWS_SECRET_KEY'),
//                     string(credentialsId: 'backup_bucket', variable: 'BACKUP_BUCKET'),
//                     string(credentialsId: 'backup_bucket_region', variable: 'BACKUP_BUCKET_REGION')
//                 ]) {
//                     dir('./infra/terraform/standby_terraform') {
//                         sh '''
//                             export TF_VAR_aws_access_key=$AWS_ACCESS_KEY
//                             export TF_VAR_aws_secret_key=$AWS_SECRET_KEY
//                             export TF_VAR_backup_bucket=$BACKUP_BUCKET
//                             export TF_VAR_backup_bucket_region=$BACKUP_BUCKET_REGION

//                             terraform init
//                             terraform plan -var-file=standby.tfvars
//                             terraform apply -var-file=standby.tfvars -var "private_key_path=$PEM_KEY_PATH" -auto-approve
//                         '''
//                     }
//                 }
//             }
//         }
//     }  
//     /* -------------------------------------------------------------- *
//     *  PIPELINE-LEVEL POST                                           *
//     * -------------------------------------------------------------- */
//     post {
//         always  { cleanWs() }
//         success { echo "✅ Pipeline completed successfully. Image: ${FULL_IMAGE}" }
//         failure { echo '❌ Lint, Build or Deploy failed' }
//     }
// }

pipeline {
    agent any
    options {
        timestamps()
    }
    
    parameters {
        booleanParam(name: 'DEPLOY_STANDBY_ONLY', defaultValue: false, description: 'Deploy only standby environment')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip test stages')
    }

    environment {
        IMAGE_NAME  = 'lstm-model'
        IMAGE_TAG   = 'latest'
        REPOSITORY  = 'freshinit'
        FULL_IMAGE  = "${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"
        DOCKER_CREDENTIALS = credentials('dockerhub-pat')
    }

    stages {
        stage('Prepare') {
            steps {
                cleanWs()
                checkout scm
                stash name: 'repo-source', includes: '**'
            }
        }

        stage('Deploy') {
            when {
                expression { return !params.DEPLOY_STANDBY_ONLY }
            }
            agent {
                kubernetes {
                    cloud 'k8s-automated-dr'
                    yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  serviceAccountName: jenkins-agent
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["sleep"]
    args: ["99d"]
    tty: true
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
    resources:
      requests:
        memory: "128Mi"
        cpu: "50m"
      limits:
        memory: "256Mi"
        cpu: "200m"
  restartPolicy: Never
"""
                    defaultContainer 'kubectl'
                }
            }
            options { skipDefaultCheckout() }
            steps {
                unstash 'repo-source'
                container('kubectl') {
                    sh '''
                        echo "🔧 Applying Kubernetes manifests..."
                        kubectl version 
                        kubectl config view 
                        
                        # Check if we can connect to the cluster
                        if ! kubectl get nodes; then
                            echo "❌ Cannot connect to Kubernetes cluster"
                            exit 1
                        fi
                        
                        # Check if Chaos Mesh CRDs are available
                        if kubectl api-resources | grep -q "stresschaos"; then
                            echo "▶️  Applying Chaos Mesh experiments"
                            kubectl apply -R -f k8s-manifests/ --validate=false
                        else
                            echo "⚠️  Skipping StressChaos objects (CRDs not installed)"
                            # Apply non-chaos manifests only
                            find k8s-manifests/ -name "*.yaml" -o -name "*.yml" | while read file; do
                                if ! grep -q "kind: StressChaos\\|kind: PodChaos\\|kind: NetworkChaos" "$file"; then
                                    kubectl apply -f "$file"
                                fi
                            done
                        fi
                    '''
                }
            }
            post {
                success {
                    echo '✅ Kubernetes manifests applied successfully.'
                }
                failure {
                    echo '❌ Failed to apply Kubernetes manifests'
                }
            }
        }
        
        stage('Deploy Standby Terraform') {
            when {
                anyOf {
                    expression { return params.DEPLOY_STANDBY_ONLY }
                }
            }
            agent {
                kubernetes {
                    cloud 'k8s-automated-dr'
                    yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  serviceAccountName: jenkins-agent
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  - name: tools
    image: freshinit/jenkins-agent-with-tools:latest
    command: ["sleep"]
    args: ["90d"]
    tty: true
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
    resources:
      requests:
        memory: "512Mi"
        cpu: "200m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
  restartPolicy: Never
"""
                    defaultContainer 'tools'
                }
            }
            options { skipDefaultCheckout() }
            steps {
                unstash 'repo-source'
                withCredentials([
                    // file(credentialsId: 'my-ssh-key', variable: 'PEM_KEY_PATH'),
                    string(credentialsId: 'aws_access_key', variable: 'AWS_ACCESS_KEY'),
                    string(credentialsId: 'aws_secret_key', variable: 'AWS_SECRET_KEY'),
                    string(credentialsId: 'backup_bucket', variable: 'BACKUP_BUCKET'),
                    string(credentialsId: 'backup_bucket_region', variable: 'BACKUP_BUCKET_REGION')
                ]) {
                    dir('./infra/terraform/standby_terraform') {
                        sh '''
                            set -e

                            export TF_VAR_aws_access_key=$AWS_ACCESS_KEY
                            export TF_VAR_aws_secret_key=$AWS_SECRET_KEY
                            export TF_VAR_backup_bucket=$BACKUP_BUCKET
                            export TF_VAR_backup_bucket_region=$BACKUP_BUCKET_REGION

                            terraform init

                            terraform plan -out .terraform.plan

                            if terraform apply .terraform.plan; then
                                echo "✅ Terraform apply succeeded."
                            else
                                echo "❌ Terraform apply failed. Running terraform destroy..."
                                terraform destroy -auto-approve || echo "⚠️ Terraform destroy also failed."
                                exit 1
                            fi
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always { cleanWs() }
        success { echo "✅ Pipeline completed successfully." }
        failure { echo '❌ Pipeline failed' }
    }
}

// -var "private_key_path=$PEM_KEY_PATH"