pipeline {
    agent any
    
    options {
        timestamps()
        // Remove build retention for queue-triggered jobs
        buildDiscarder(logRotator(numToKeepStr: '50'))
    }

    // Remove SCM polling - triggers come from webhooks only
    // triggers { pollSCM('H/0.5 * * * *') }
    
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
        JENKINS_TRIGGER_URL = credentials('jenkins-url')
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    // Log the job trigger source and parameters
                    echo "🚀 DR Pipeline Started"
                    echo "Parameters received:"
                    echo "  DEPLOY_STANDBY_ONLY: ${params.DEPLOY_STANDBY_ONLY}"
                    echo "  DESTROY_AFTER_APPLY: ${params.DESTROY_AFTER_APPLY}"
                    echo "  SKIP_TESTS: ${params.SKIP_TESTS}"
                    
                    // Update job status in Redis (optional tracking)
                    updateJobStatus('started')
                }
                
                cleanWs()
                checkout scm
                stash name: 'repo-source', includes: '**'
            }
        }

        // stage('Lint') {
        //     when {
        //         expression { !params.SKIP_TESTS }
        //     }
        //     agent {
        //         docker { 
        //             image 'python:3.11-bullseye'
        //             args '-u 0:0'
        //         }   
        //     }
        //     steps {
        //         unstash 'repo-source'
        //         sh '''
        //             # Lightweight virtual environment
        //             python -m venv .venv
        //             . .venv/bin/activate

        //             # Install tools
        //             pip install --upgrade pip nbqa flake8 autopep8 nbstripout

        //             # Auto-format whitespace first
        //             nbqa autopep8 --in-place --aggressive --aggressive k8s-lstm/notebook/lstm-disaster-recovery.ipynb
        //             autopep8 --in-place --recursive --aggressive --aggressive k8s-lstm/

        //             # Strip notebook outputs
        //             nbstripout k8s-lstm/notebook/lstm-disaster-recovery.ipynb

        //             # Lint the final artifacts
        //             nbqa flake8 k8s-lstm/notebook/lstm-disaster-recovery.ipynb \
        //                 --max-line-length 120 --extend-ignore E501,F401,F821
        //             flake8 k8s-lstm/ --max-line-length 120 --extend-ignore E501,E999
        //         '''
        //     }
        //     post {
        //         success { echo "✅ Linting completed successfully" }
        //         failure { echo "❌ Linting failed" }
        //     }
        // }

        stage('Build & Push') {
            when {
                expression { !params.SKIP_TESTS }
            }
            agent {
                docker { 
                    image 'docker:24.0.7'
                    args '-v /var/run/docker.sock:/var/run/docker.sock -u 0:0'
                }
            }
            steps {
                unstash 'repo-source'
                withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-pat',
                        usernameVariable: 'DOCKER_USR',
                        passwordVariable: 'DOCKER_PSW')]) {

                    sh '''
                        cd k8s-lstm
                        echo "$DOCKER_PSW" | docker login -u "$DOCKER_USR" --password-stdin
                        docker build -t $FULL_IMAGE .
                        docker push $FULL_IMAGE
                    '''
                }
            }
            post {
                success { 
                    echo "✅ Image built and pushed: ${FULL_IMAGE}"
                    script { updateJobStatus('build_complete') }
                }
                failure { echo "❌ Docker build/push failed" }
            }
        }

        stage('Process YAML') {
            steps {
                script {
                                
                sh """
                    # Use sed to replace placeholders in place
                    sed -i 's|JENKINS_TRIGGER_URL|${JENKINS_TRIGGER_URL}|g' "k8s-manifest/collector/metrics_collector_deployment.yaml"
                    
                    # Now the file is modified in the workspace
                    cat "k8s-manifest/collector/metrics_collector_deployment.yaml" 
                """
                }
            }
        }
        stage('Deploy Production') {
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
                        echo "🔧 Applying Kubernetes manifests to PRODUCTION..."
                        kubectl version 
                        
                        # Check cluster connectivity
                        if ! kubectl get nodes; then
                            echo "❌ Cannot connect to Kubernetes cluster"
                            exit 1
                        fi
                        
                        # Apply manifests with Chaos Mesh support
                        if kubectl api-resources | grep -q "stresschaos"; then
                            echo "▶️ Applying Chaos Mesh experiments"
                            kubectl apply -R -f k8s-manifests/ --validate=false
                        else
                            echo "⚠️ Skipping StressChaos objects (CRDs not installed)"
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
                    echo '✅ Production deployment completed successfully'
                    script { updateJobStatus('production_deployed') }
                }
                failure {
                    echo '❌ Production deployment failed'
                }
            }
        }
        
        stage('Deploy Standby') {
            when {
                anyOf {
                    expression { return params.DEPLOY_STANDBY_ONLY }
                    expression { return !params.DEPLOY_STANDBY_ONLY } // Always deploy standby for DR
                }
            }
            agent {
                docker {
                    image 'freshinit/jenkins-agent-with-tools:latest'
                    args '-u root:root'
                }
            }
            options { skipDefaultCheckout() }
            steps {
                unstash 'repo-source'
                withCredentials([
                    string(credentialsId: 'aws_access_key', variable: 'AWS_ACCESS_KEY'),
                    string(credentialsId: 'aws_secret_key', variable: 'AWS_SECRET_KEY'),
                    string(credentialsId: 'backup_bucket', variable: 'BACKUP_BUCKET'),
                    string(credentialsId: 'backup_bucket_region', variable: 'BACKUP_BUCKET_REGION')
                ]) {
                    dir('./infra/terraform/standby_terraform') {
                        script {
                            def deploymentType = params.DEPLOY_STANDBY_ONLY ? "STANDBY ONLY" : "STANDBY (DR)"
                            echo "🏗️ Deploying ${deploymentType} environment with Terraform"
                            
                            sh """
                                set -e

                                echo "[INFO] Setting up environment variables..."
                                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY}
                                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_KEY}
                                export TF_VAR_aws_access_key_id=${AWS_ACCESS_KEY}
                                export TF_VAR_aws_secret_access_key=${AWS_SECRET_KEY}
                                export TF_VAR_velero_bucket_name=${BACKUP_BUCKET}
                                export TF_VAR_velero_aws_region=${BACKUP_BUCKET_REGION}

                                # Validate credentials
                                if [ -z "\${AWS_ACCESS_KEY}" ] || [ -z "\${AWS_SECRET_KEY}" ]; then
                                    echo "[ERROR] AWS credentials not provided"
                                    exit 1
                                fi

                                # Setup safe HOME directory
                                export HOME="\$WORKSPACE/tmp_home"
                                mkdir -p "\$HOME"

                                # Clean previous Terraform state
                                rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
                                
                                echo "[INFO] Initializing Terraform..."
                                terraform init

                                echo "[INFO] Planning Terraform deployment..."
                                terraform plan -out=tfplan
                                    
                                echo "[INFO] Applying Terraform plan..."
                                if terraform apply tfplan; then
                                    echo "[SUCCESS] Terraform apply successful"
                                    
                                    # Handle destroy after apply option
                                    if [ "${params.DESTROY_AFTER_APPLY}" = "true" ]; then
                                        echo "[INFO] DESTROY_AFTER_APPLY enabled - destroying resources in 15 minutes..."
                                        sleep 900
                                        terraform destroy -auto-approve
                                        echo "[INFO] Resources destroyed as requested"
                                    else
                                        echo "[INFO] DESTROY_AFTER_APPLY disabled - resources remain deployed"
                                    fi
                                else
                                    echo "[ERROR] Terraform apply failed"
                                    echo "[INFO] Attempting cleanup of partial resources..."
                                    terraform destroy -auto-approve || echo "[WARN] Destroy failed"
                                    exit 1
                                fi
                            """
                        }
                    }
                }
            }
            post {
                success {
                    echo '✅ Standby environment deployed successfully'
                    script { updateJobStatus('standby_deployed') }
                }
                failure {
                    echo '❌ Standby deployment failed'
                }
            }
        }
    }
    
    post {
        always { 
            cleanWs()
            script { updateJobStatus('completed') }
        }
        success { 
            echo "✅ DR Pipeline completed successfully"
            script { updateJobStatus('success') }
        }
        failure { 
            echo '❌ DR Pipeline failed'
            script { updateJobStatus('failed') }
        }
    }
}

// Helper function to update job status in Redis (optional)
def updateJobStatus(String status) {
    try {
        // Only update if we have build parameters indicating this was triggered by the Node.js service
        if (env.BUILD_CAUSE?.contains('GenericWebHookCause') || params.containsKey('DEPLOY_STANDBY_ONLY')) {
            sh """
                pip3 install --quiet redis
                python3 -c "
import redis
import json
import os
from datetime import datetime

try:
    r = redis.Redis(host='localhost', port=6379, decode_responses=True)
    
    job_update = {
        'build_number': '${env.BUILD_NUMBER}',
        'build_url': '${env.BUILD_URL}',
        'status': '${status}',
        'timestamp': datetime.now().isoformat(),
        'parameters': {
            'DEPLOY_STANDBY_ONLY': '${params.DEPLOY_STANDBY_ONLY}',
            'DESTROY_AFTER_APPLY': '${params.DESTROY_AFTER_APPLY}',
            'SKIP_TESTS': '${params.SKIP_TESTS}'
        }
    }
    
    # Store job status with build number as key
    r.hset('jenkins_jobs', '${env.BUILD_NUMBER}', json.dumps(job_update))
    print(f'Updated job status: ${status}')
    
except Exception as e:
    print(f'Failed to update job status: {e}')
"
            """
        }
    } catch (Exception e) {
        echo "Warning: Could not update job status in Redis: ${e.getMessage()}"
    }
}