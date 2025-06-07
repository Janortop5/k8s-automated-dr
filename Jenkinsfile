pipeline {
  agent any

  environment {
    IMAGE_NAME    = "lstm-disaster-recovery"
    IMAGE_TAG     = "latest"
    FULL_IMAGE    = "${env.REGISTRY}/${env.IMAGE_NAME}:${IMAGE_TAG}"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Lint') {
      steps {
        // Install nbQA for linting notebooks, and flake8
        sh '''
          pip install --upgrade pip
          pip install nbqa flake8
          # Run flake8 over the notebook
          nbqa flake8 lstm-disaster-recovery.ipynb --max-line-length=88
        '''
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          // Build the Docker image
          dockerImage = docker.build(FULL_IMAGE)
        }
      }
    }

    stage('Push to Registry') {
      steps {
        script {
          // Log in and push
          docker.withRegistry("https://${env.REGISTRY}", env.REGISTRY_PASSWORD) {
            dockerImage.push(IMAGE_TAG)
          }
        }
      }
    }
  }

  post {
    always {
      cleanWs()
    }
    success {
      echo "✅ Image pushed: ${FULL_IMAGE}"
    }
    failure {
      echo "❌ Build or push failed"
    }
  }
}
