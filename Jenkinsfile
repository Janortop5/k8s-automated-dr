pipeline {
    /* ------------------------------------------------------------------ *
     *  GLOBAL AGENT (Docker-in-Docker)                                   *
     * ------------------------------------------------------------------ */
    agent {
        docker {
            /* You can reference variables declared in `environment`,
               but use ${DOCKER_VERSION}, not ${env.DOCKER_VERSION}.      */
            image "docker:${DOCKER_VERSION}-dind"
            args  '--privileged'
        }
    }

    /* ------------------------------------------------------------------ *
     *  GLOBAL ENVIRONMENT                                                *
     * ------------------------------------------------------------------ */
    environment {
        DOCKER_VERSION = '24.0.7'
        IMAGE_NAME     = 'lstm-model'
        IMAGE_TAG      = 'latest'
        REPOSITORY     = 'janortop5'
        FULL_IMAGE     = "${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

        /* If you only need the username & password later via
           $DOCKER_CREDENTIALS_USR / _PSW, you can declare just this:     */
        DOCKER_CREDENTIALS    = credentials('dockerhub-pat')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig-prod')
    }

    /* ------------------------------------------------------------------ *
     *  STAGES                                                            *
     * ------------------------------------------------------------------ */
    stages {

        /* -------------------- 1. Checkout ----------------------------- */
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        /* -------------------- 2. Lint --------------------------------- */
        stage('Lint') {
            /* Override the global agent: run linting in a slim Python image */
            agent {
                docker { image 'python:3.11' }
            }
            steps {
                sh '''
                    pip install --upgrade pip
                    pip install nbqa flake8

                    nbqa flake8 lstm-disaster-recovery.ipynb
                    flake8 k8s-lstm/
                '''
            }
        }

        /* -------------------- 3. Build & Push ------------------------- */
        stage('Build') {
            steps {
                /* Re-expose Docker Hub creds inside the container */
                withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-pat',
                        usernameVariable: 'DOCKER_CREDENTIALS_USR',
                        passwordVariable: 'DOCKER_CREDENTIALS_PSW')]) {

                    sh '''
                        cd k8s-lstm
                        echo "$DOCKER_CREDENTIALS_PSW" | \
                             docker login -u "$DOCKER_CREDENTIALS_USR" --password-stdin

                        docker build -t $FULL_IMAGE .
                        docker push  $FULL_IMAGE
                    '''
                }
            }
            post {
                success {
                    echo "✅ Image built and pushed: ${FULL_IMAGE}"
                }
            }
        }

        /* -------------------- 4. Deploy ------------------------------- */
        stage('Deploy') {
            agent {
                docker {
                    image 'bitnami/kubectl:latest'
                    /* Time-zone mounts are optional */
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
                success {
                    echo '✅ Kubernetes manifests applied successfully.'
                }
            }
        }
    } /* -------- end stages -------- */

    /* ------------------------------------------------------------------ *
     *  PIPELINE-LEVEL POST                                               *
     * ------------------------------------------------------------------ */
    post {
        always {
            cleanWs()
        }
        success {
            echo "✅ Pipeline completed successfully. Image: ${FULL_IMAGE}"
        }
        failure {
            echo '❌ Lint, Build or Deploy failed'
        }
    }
}
