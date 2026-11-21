pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPOSITORY_PREFIX = 'ivolve-devops'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = sh(
                        returnStdout: true,
                        script: 'git rev-parse --short=12 HEAD'
                    ).trim()

                    env.ECR_REGISTRY = sh(
                        returnStdout: true,
                        script: 'aws sts get-caller-identity --region us-east-1 --query Account --output text'
                    ).trim() + ".dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                }
            }
        }

        stage('Login to ECR') {
            steps {
                sh 'aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
            }
        }

        stage('Build and Push Images') {
            steps {
                sh '''
                    set -eu
                    for service in frontend auth-service roadmap-service; do
                        image="${ECR_REGISTRY}/${ECR_REPOSITORY_PREFIX}/${service}:${IMAGE_TAG}"
                        docker build --file "${service}/Dockerfile" --tag "$image" .
                        docker push "$image"
                    done
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout "$ECR_REGISTRY" >/dev/null 2>&1 || true'
        }
    }
}
