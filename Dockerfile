# Container image that runs your code
FROM ubuntu:latest

# Install git, gitflow  dependencies
RUN apt-get update && apt-get install -y git git-flow curl

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
