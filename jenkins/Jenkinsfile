pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: k8s-lstm-pipeline
spec:
  containers:
  - name: docker
    image: docker:latest
    command: ['cat']
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['cat']
    tty: true
  - name: envsubst
    image: linuxserver/moreutils:latest
    command: ['cat']
    tty: true
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
"""
        }
    }
    
    parameters {
        string(name: 'CONFIG_FILE', defaultValue: 'ci/config.properties', description: 'Path to configuration file')
        string(name: 'NAMESPACE', defaultValue: '', description: 'Kubernetes namespace for deployment (overrides config file)')
        string(name: 'DOCKER_IMAGE_TAG', defaultValue: '', description: 'Docker image tag (defaults to build number if empty)')
    }
    
    environment {
        REGISTRY_CREDENTIALS = credentials('docker-registry-credentials')
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }
        
        stage('Load Configuration') {
            steps {
                script {
                    // Load helper script
                    def propertyLoader = load "ci/loadProperties.groovy"
                    
                    // Check if config file exists, use default if not specified
                    def configFile = params.CONFIG_FILE
                    if (!fileExists(configFile)) {
                        echo "Config file not found at ${configFile}, using default values"
                        configFile = "ci/config.properties"
                    }
                    
                    // Load properties from file
                    def props = propertyLoader(configFile)
                    
                    // Set environment variables with priority:
                    // 1. Jenkins parameters (if provided)
                    // 2. Properties file values
                    // 3. Default values
                    
                    env.PROJECT_ROOT = "${WORKSPACE}/k8s-lstm-project"
                    env.PIPELINE_DIR = "${PROJECT_ROOT}/data-pipeline"
                    
                    env.NAMESPACE = params.NAMESPACE ?: props.NAMESPACE ?: "ml-pipeline"
                    env.DOCKER_IMAGE_NAME = props.DOCKER_IMAGE_NAME ?: "metrics-collector"
                    env.DOCKER_IMAGE_TAG = params.DOCKER_IMAGE_TAG ?: "${BUILD_NUMBER}"
                    env.DOCKER_REGISTRY = props.DOCKER_REGISTRY ?: "your-registry"
                    
                    env.PROMETHEUS_URL = props.PROMETHEUS_URL ?: "http://prometheus-service:9090"
                    env.PV_SIZE = props.PV_SIZE ?: "10Gi"
                    env.PV_STORAGE_CLASS = props.PV_STORAGE_CLASS ?: "standard"
                    env.PV_HOST_PATH = props.PV_HOST_PATH ?: "/mnt/data"
                    
                    // Print loaded configuration
                    echo "Using configuration:"
                    echo "NAMESPACE: ${env.NAMESPACE}"
                    echo "DOCKER_IMAGE_NAME: ${env.DOCKER_IMAGE_NAME}"
                    echo "DOCKER_IMAGE_TAG: ${env.DOCKER_IMAGE_TAG}"
                    echo "PROMETHEUS_URL: ${env.PROMETHEUS_URL}"
                    echo "PV_SIZE: ${env.PV_SIZE}"
                    echo "PV_STORAGE_CLASS: ${env.PV_STORAGE_CLASS}"
                    echo "PV_HOST_PATH: ${env.PV_HOST_PATH}"
                }
            }
        }
        
        stage('Setup Project Structure') {
            steps {
                sh "mkdir -p ${PIPELINE_DIR}"
            }
        }
        
        stage('Process Template Files') {
            steps {
                script {
                    // Copy Python collection script
                    sh "cp kubernetes/collect_metrics.py ${PIPELINE_DIR}/collect_metrics.py"
                    
                    // Copy requirements.txt
                    sh "cp kubernetes/requirements.txt ${PIPELINE_DIR}/requirements.txt"
                    
                    // Copy Dockerfile
                    sh "cp kubernetes/Dockerfile ${PIPELINE_DIR}/Dockerfile"
                    
                    // Process Kubernetes template files with environment variable substitution
                    container('envsubst') {
                        // Export all environment variables for envsubst
                        sh """
                            env > /tmp/env_vars
                            mkdir -p ${PIPELINE_DIR}/manifests
                            for template in kubernetes/templates/*.yaml; do
                                filename=\$(basename \$template)
                                cat \$template | envsubst > ${PIPELINE_DIR}/manifests/\$filename
                            done
                        """
                    }
                }
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                container('docker') {
                    sh """
                        echo '${REGISTRY_CREDENTIALS_PSW}' | docker login ${DOCKER_REGISTRY} -u ${REGISTRY_CREDENTIALS_USR} --password-stdin
                        cd ${PIPELINE_DIR}
                        docker build -t ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} .
                        docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
                    """
                }
            }
        }
        
        stage('Apply Kubernetes Manifests') {
            steps {
                container('kubectl') {
                    sh """
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        kubectl apply -f ${PIPELINE_DIR}/manifests/
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo "K8s LSTM Data Pipeline has been successfully deployed!"
            
            // Archive artifacts for future reference
            archiveArtifacts artifacts: "${PIPELINE_DIR}/manifests/*.yaml", allowEmptyArchive: true
        }
        failure {
            echo "Failed to deploy K8s LSTM Data Pipeline. Check the logs for details."
        }
        always {
            // Clean up workspace
            cleanWs()
        }
    }
}
