pipeline {
    /* ---------------- GLOBAL AGENT ---------------- */
    agent {
        docker {
            // <-- the fix is right here
            image "docker:${env.DOCKER_VERSION}-dind"
            args  '--privileged'
        }
    }

    /* -------------- ENVIRONMENT VARS -------------- */
    environment {
        DOCKER_VERSION = '24.0.7'
        IMAGE_NAME     = 'lstm-model'
        IMAGE_TAG      = 'latest'
        REPOSITORY     = 'janortop5'
        FULL_IMAGE     = "${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

        DOCKER_CREDENTIALS     = credentials('dockerhub-pat')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig-prod')
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Lint') {
            /* run linting inside a Python container */
            agent { docker { image 'python:3.11' } }
            steps {
                sh '''
                    pip install --upgrade pip nbqa flake8
                    nbqa flake8 lstm-disaster-recovery.ipynb
                    flake8 k8s-lstm/
                '''
            }
        }

        stage('Build') {
            steps {
                withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-pat',
                        usernameVariable: 'DOCKER_USR',
                        passwordVariable: 'DOCKER_PSW')]) {

                    sh '''
                        cd k8s-lstm
                        echo "$DOCKER_PSW" | docker login -u "$DOCKER_USR" --password-stdin
                        docker build -t $FULL_IMAGE .
                        docker push  $FULL_IMAGE
                    '''
                }
            }
            post {
                success { echo "✅ Image built and pushed: ${FULL_IMAGE}" }
            }
        }

        stage('Deploy') {
            agent {
                docker {
                    image 'bitnami/kubectl:latest'
                    args  '-v /etc/timezone:/etc/timezone:ro ' +
                          '-v /etc/localtime:/etc/localtime:ro'
                }
            }
            steps {
                withCredentials([file(
                        credentialsId: 'kubeconfig-prod',
                        variable: 'KUBECONFIG')]) {

                    sh '''
                        echo "🔧 Applying Kubernetes manifests..."
                        kubectl version --short
                        kubectl config view
                        kubectl apply -f k8s-manifests/
                    '''
                }
            }
            post {
                success { echo '✅ Kubernetes manifests applied successfully.' }
            }
        }
    }

    /* -------------- PIPELINE-LEVEL POST ------------ */
    post {
        always  { cleanWs() }
        success { echo "✅ Pipeline completed successfully. Image: ${FULL_IMAGE}" }
        failure { echo '❌ Lint, Build or Deploy failed' }
    }
}
