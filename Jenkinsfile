pipeline {
    /* -------------------------------------------------------------- *
     *  GLOBAL SETTINGS                                               *
     * -------------------------------------------------------------- */
    agent any                     // just give me any node that has Docker
    options { timestamps() }      // show HH:mm:ss on every log line

    environment {
        IMAGE_NAME  = 'lstm-model'
        IMAGE_TAG   = 'latest'
        REPOSITORY  = 'janortop5'
        FULL_IMAGE  = "${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

        DOCKER_CREDENTIALS     = credentials('dockerhub-pat')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig-prod')
    }

    /* -------------------------------------------------------------- *
     *  STAGES                                                        *
     * -------------------------------------------------------------- */
    stages {

        /* 1. Checkout once, on the host                           */
        stage('Checkout') {
            steps { checkout scm }
        }

        /* 2. Lint inside a Python container                       */
        stage('Lint') {
            agent {
                docker { image 'python:3.11' }
            }
            /* We already checked out the repo, so skip Jenkins’ auto-checkout */
            options { skipDefaultCheckout true }
            steps {
                sh '''
                    pip install --upgrade pip nbqa flake8
                    nbqa flake8 lstm-disaster-recovery.ipynb
                    flake8 k8s-lstm/
                '''
            }
        }

        /* 3. Build & push the image (needs DinD)                   */
        stage('Build') {
            agent {
                docker { image 'docker:24.0.7-dind'; args '--privileged' }
            }
            options { skipDefaultCheckout true }
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

        /* 4. Deploy with kubectl container                         */
        stage('Deploy') {
            agent {
                docker {
                    image 'bitnami/kubectl:latest'
                    args  '-v /etc/timezone:/etc/timezone:ro ' +
                          '-v /etc/localtime:/etc/localtime:ro'
                }
            }
            options { skipDefaultCheckout true }
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

    /* -------------------------------------------------------------- *
     *  PIPELINE-LEVEL POST                                           *
     * -------------------------------------------------------------- */
    post {
        always  { cleanWs() }
        success { echo "✅ Pipeline completed successfully. Image: ${FULL_IMAGE}" }
        failure { echo '❌ Lint, Build or Deploy failed' }
    }
}
