pipeline {
    /* -------------------------------------------------------------- *
     *  GLOBAL SETTINGS                                               *
     * -------------------------------------------------------------- */


    agent any                     // just give me any node that has Docker
    options {
        timestamps()
    }

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
                docker { image 'python:3.11-bullseye'; args  '-u 0:0' }   // ← run as root:root inside the container
                         
            }
            options { skipDefaultCheckout true }
            steps {
                sh '''
                    # 1. Lightweight virtual environment (lives in workspace, removed by cleanWs())
                    python -m venv .venv
                    . .venv/bin/activate

                    # 2. Tools we need
                    pip install --upgrade pip nbqa flake8 autopep8 nbstripout

                    # 3. Auto-format whitespace first
                    nbqa autopep8 --in-place --aggressive --aggressive k8s-lstm/notebook/lstm-disaster-recovery.ipynb
                    autopep8  --in-place --recursive --aggressive --aggressive k8s-lstm/

                    # 4. strip notebook outputs **in-place**
                    # strip a single notebook
                    nbstripout k8s-lstm/notebook/lstm-disaster-recovery.ipynb
                    # strip every notebook under k8s-lstm/
                    # find k8s-lstm -name '*.ipynb' -exec nbstripout {} +

                    # 5. lint the final artefacts
                    nbqa flake8 k8s-lstm/notebook/lstm-disaster-recovery.ipynb \
                        --max-line-length 120 --extend-ignore E501
                    flake8 k8s-lstm/ --max-line-length 120 --extend-ignore E501
                '''
            }
        }

        /* 3. Build & push the image (needs DinD)                   */
        stage('Build') {
            agent {
                docker { image 'docker:24.0.7-dind'; args '--privileged -u 0:0' }
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
                          '-v /etc/localtime:/etc/localtime:ro' +
                          '-u 0:0' // run as root:root inside the container
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
