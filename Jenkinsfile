pipeline {
    agent {
        docker {
            image 'docker:24.0.7-dind' 
            args '--privileged'
        }
    }

  environment {
    IMAGE_NAME    = "lstm-model"
    IMAGE_TAG     = "latest"
    REPOSITORY    = "janortop5"
    FULL_IMAGE    = "${env.REPOSITORY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
    DOCKER_CREDENTIALS = credentials('dockerhub-pat')
    KUBECONFIG_CREDENTIALS = credentials('kubeconfig-prod')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
    stage('Lint') {
      agent {
          docker {
              image 'python:3.11'
          }
      }
      steps {
        // Install nbQA for linting notebooks, and flake8
        sh '''
          pip install --upgrade pip
          pip install nbqa flake8
          
          # Lint notebook
          nbqa flake8 lstm-disaster-recovery.ipynb 

          # Lint Python application code
          flake8 k8s-lstm/
        '''
      }
    }

    stage('Build') {
      steps {
        sh '''
          # change to working directory
          cd k8s-lstm
          
          # docker user login
          echo "$DOCKER_CREDENTIALS_PSW" | docker login -u "$DOCKER_CREDENTIALS_USR" --password-stdin
          
          # build the docker image
          docker build -t $FULL_IMAGE .

          # push the docker image
          docker push $FULL_IMAGE
        '''
      }
    }

    stage('Deploy') {
      agent {
        docker {
          image 'bitnami/kubectl:latest' 
          args '-v /etc/timezone:/etc/timezone:ro -v /etc/localtime:/etc/localtime:ro' // Optional: timezone sync
        }
      }
      steps {
        withCredentials([file(credentialsId: 'kubeconfig-prod', variable: 'KUBECONFIG')]) {
          sh '''
            echo "🔧 Applying Kubernetes manifests..."
            kubectl version --short
            kubectl config view
            kubectl apply -f k8s-manifests/
          '''
        }
      }
    }

  post {
    always {
      cleanWs()
    }
    success {
      echo "✅ Image pushed: ${FULL_IMAGE}"
      echo "K8s manifests applied."
    }
    failure {
      echo "❌ Build or deploy failed"
    }
  }
}