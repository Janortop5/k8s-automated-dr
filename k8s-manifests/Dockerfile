# Dockerfile
FROM bitnami/kubectl:latest

USER root
# bitnami images come with an install helper; if yours doesn't you can apt-get update && apt-get install -y coreutils bash
RUN install_packages coreutils bash

USER 1001
