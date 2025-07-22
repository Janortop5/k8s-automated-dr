pipeline {
    agent any
    options {
        timestamps()
    }
    
    parameters {
        booleanParam(name: 'DEPLOY_STANDBY_ONLY', defaultValue: false, description: 'Deploy only standby environment')
        booleanParam(name: 'DESTROY_AFTER_APPLY', defaultValue: false, description: 'Destroy resources after apply')
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

        // /* 2. Lint inside a Python container                       */
        // stage('Lint') {
        //     agent {
        //         docker { image 'python:3.11-bullseye'; args  '-u 0:0' }   // ← run as root:root inside the container
                         
        //     }
        //     steps {
        //         sh '''
        //             # 1. Lightweight virtual environment (lives in workspace, removed by cleanWs())
        //             python -m venv .venv
        //             . .venv/bin/activate

        //             # 2. Tools we need
        //             pip install --upgrade pip nbqa flake8 autopep8 nbstripout

        //             # 3. Auto-format whitespace first
        //             nbqa autopep8 --in-place --aggressive --aggressive k8s-lstm/notebook/lstm-disaster-recovery.ipynb
        //             autopep8  --in-place --recursive --aggressive --aggressive k8s-lstm/

        //             # 4. strip notebook outputs **in-place**
        //             # strip a single notebook
        //             nbstripout k8s-lstm/notebook/lstm-disaster-recovery.ipynb
        //             # strip every notebook under k8s-lstm/
        //             # find k8s-lstm -name '*.ipynb' -exec nbstripout {} +

        //             # 5. lint the final artefacts
        //             nbqa flake8 k8s-lstm/notebook/lstm-disaster-recovery.ipynb \
        //                 --max-line-length 120 --extend-ignore E501,F401,F821
        //             flake8 k8s-lstm/ --max-line-length 120 --extend-ignore E501,E999
        //         '''
        //     }
        // }

        // /* 3. Build & push the image (needs DinD)                   */
        // stage('Build') {
        //     agent {
        //         docker { image 'docker:24.0.7'; args  '-v /var/run/docker.sock:/var/run/docker.sock -u 0:0' }
        //     }
        //     steps {
        //         withCredentials([usernamePassword(
        //                 credentialsId: 'dockerhub-pat',
        //                 usernameVariable: 'DOCKER_USR',
        //                 passwordVariable: 'DOCKER_PSW')]) {

        //             sh '''
        //                 cd k8s-lstm
        //                 echo "$DOCKER_PSW" | docker login -u "$DOCKER_USR" --password-stdin
        //                 docker build -t $FULL_IMAGE .
        //                 docker push  $FULL_IMAGE
        //             '''
        //         }
        //     }
        //     post {
        //         success { echo "✅ Image built and pushed: ${FULL_IMAGE}" }
        //     }
        // }

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
// metadata:
//   labels:
//     jenkins: agent
// spec:
//   serviceAccountName: jenkins-agent
//   containers:
//   - name: jnlp
//     image: jenkins/inbound-agent:latest
//     resources:
//       requests:
//         memory: "256Mi"
//         cpu: "100m"
//       limits:
//         memory: "512Mi"
//         cpu: "500m"
//   - name: kubectl
//     image: bitnami/kubectl:latest
//     command: ["sleep"]
//     args: ["99d"]
//     tty: true
//     securityContext:
//       runAsUser: 1000
//       runAsGroup: 1000
//     resources:
//       requests:
//         memory: "128Mi"
//         cpu: "50m"
//       limits:
//         memory: "256Mi"
//         cpu: "200m"
//   restartPolicy: Never
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
                        
//                         # Check if we can connect to the cluster
//                         if ! kubectl get nodes; then
//                             echo "❌ Cannot connect to Kubernetes cluster"
//                             exit 1
//                         fi
                        
//                         # Check if Chaos Mesh CRDs are available
//                         if kubectl api-resources | grep -q "stresschaos"; then
//                             echo "▶️  Applying Chaos Mesh experiments"
//                             kubectl apply -R -f k8s-manifests/ --validate=false
//                         else
//                             echo "⚠️  Skipping StressChaos objects (CRDs not installed)"
//                             # Apply non-chaos manifests only
//                             find k8s-manifests/ -name "*.yaml" -o -name "*.yml" | while read file; do
//                                 if ! grep -q "kind: StressChaos\\|kind: PodChaos\\|kind: NetworkChaos" "$file"; then
//                                     kubectl apply -f "$file"
//                                 fi
//                             done
//                         fi
//                     '''
//                 }
//             }
//             post {
//                 success {
//                     echo '✅ Kubernetes manifests applied successfully.'
//                 }
//                 failure {
//                     echo '❌ Failed to apply Kubernetes manifests'
//                 }
//             }
//         }
        
        stage('Deploy Standby Terraform') {
            when {
                anyOf {
                    expression { return params.DEPLOY_STANDBY_ONLY }
                }
            }
            agent {
                docker {
                    image 'freshinit/jenkins-agent-with-tools:latest'
                    args '-u root:root'  // Run as root to avoid permission issues
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
                        sh """
                            set -e  # Exit immediately on error

                            echo "[INFO] Setting up environment variables..."
                            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
                            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
                            export VELERO_BUCKET_NAME=${BACKUP_BUCKET}
                            export VELERO_REGION=${BACKUP_BUCKET_REGION}
                            export TF_VAR_aws_access_key_id=${AWS_ACCESS_KEY}
                            export TF_VAR_aws_secret_access_key=${AWS_SECRET_KEY}
                            export TF_VAR_velero_bucket_name=${BACKUP_BUCKET}
                            export TF_VAR_velero_aws_region=${BACKUP_BUCKET_REGION}

                            if [ -z "\${AWS_ACCESS_KEY}" ] || [ -z "\${AWS_SECRET_KEY}" ]; then
                                echo "[ERROR] AWS credentials not provided"
                                exit 1
                            fi

                            echo "[INFO] Setting up safe HOME directory..."
                            export HOME="\$WORKSPACE/tmp_home"
                            mkdir -p "\$HOME"

                            echo "[INFO] HOME set to: \$HOME"
                            echo "[INFO] Current user:"
                            whoami || echo "[WARN] Unable to resolve username for UID \$(id -u)"

                            if [ -d ".terraform" ] || [ -f ".terraform.lock.hcl" ] || [ -f "terraform.tfstate" ] || [ -f "terraform.tfstate.backup" ]; then
                                # Remove files/folders if present
                                rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
                            fi
                            
                            echo "[INFO] Initializing Terraform..."
                            terraform init

                            echo "[INFO] Planning Terraform deployment..."
                            terraform plan -out=tfplan
                                
                            # Apply the plan
                            echo "[INFO] Applying Terraform plan..."
                            if terraform apply tfplan; then
                                echo "[INFO] Terraform apply successful"
                                
                                # Check if user requested destruction after apply
                                if [ "${params.DESTROY_AFTER_APPLY}" = "true" ]; then
                                    echo "[INFO] DESTROY_AFTER_APPLY is enabled - destroying resources..."
                                    echo "[INFO] Waiting for 15 minutes before destroying resources..."
                                    echo "[INFO] This is to ensure all resources are fully provisioned and stable before destruction"
                                    sleep 900 && echo "15 minutes elapsed!"
                                    terraform destroy -auto-approve
                                else
                                    echo "[INFO] DESTROY_AFTER_APPLY is disabled - resources will remain deployed"
                                fi
                            else
                                echo "[ERROR] Terraform apply failed"
                                echo "[INFO] Attempting to destroy any partially created resources..."
                                terraform destroy -auto-approve || echo "[WARN] Destroy failed, manual cleanup may be required"
                                exit 1
                            fi
                        """
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
