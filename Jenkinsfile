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
        REPOSITORY  = 'freshinit'
        FULL_IMAGE  = "${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

        DOCKER_CREDENTIALS     = credentials('dockerhub-pat')
    }

    /* -------------------------------------------------------------- *
     *  STAGES                                                        *
     * -------------------------------------------------------------- */
    stages {

        /* 1. Checkout once, on the host                           */
        stage('Prepare') {
          steps {
            cleanWs()      // kill stale workspace
            checkout scm   // fresh code
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

        /* 4. Deploy with kubectl pod                         */
        stage('Deploy') {
            agent {
                kubernetes {
                cloud 'k8s-automated-dr'
                yaml """
            apiVersion: v1
            kind: Pod
            spec:
              serviceAccountName: jenkins-agent
              containers:
              - name: jnlp
                image: jenkins/inbound-agent:latest
              - name: kubectl
                image: bitnami/kubectl:latest
                command: ["sleep"]
                args: ["99d"]
                tty: true
                securityContext:
                    runAsUser: 1000
                    runAsGroup: 1000
            """
                defaultContainer 'kubectl'   // so steps run here unless you say otherwise
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
                    if kubectl api-resources | grep -q "stresschaos"; then
                        echo "▶️  Applying Chaos Mesh experiments"
                        kubectl apply -R -f k8s-manifests/
                    else
                        echo "⚠️  Skipping StressChaos objects (CRDs not installed)"
                    fi
                '''
                }
            }
            post {
                success {
                echo '✅ Kubernetes manifests applied successfully.'
                }
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
