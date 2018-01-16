# Docker-in-Docker Image

This image lets you run Docker within Docker.

Additionally this image supports Docker Compose.

This is an updated version of https://quay.io/repository/cosee-concourse/dind/status which adds in support for the
ECR credentials helper so you can docker pull from ECS to prime docker for docker-compose execution when using
images from ECR.

## Example: Usage with ConcourseCI
### Docker Compose
Pipeline definition:
```yaml
...

jobs:
- name: docker-compose-job
  plan:
  - get: source
    trigger: true
  - task: runDockerCompose
    privileged: true        # required
    file: source/path_to_task_definition/taskDefinition.yml
    
... 
```

Task definition (e.g. taskDefinition.yml):

``` yaml
platform: linux

image_resource:
        type: docker-image
        source: {
        repository: quay.io/cosee-concourse/dind,
        tag: "latest" }

run:
        path: sh
        args:
        - -exc
        - |
          source /docker-lib.sh               # required
          start_docker                        # required
          cd source/path_to_dockercompose_yml
          docker-compose up -d
          # execute your tasks e.g.
          docker-compose -f docker-compose-runTasks.yml run testservice echo "Hello World"
          rc=$?                               # exit code of testservice
          docker-compose down                 # required
          exit $rc

inputs:
    - name: source
```

### Docker in Docker
Pipeline definition:
```yaml
...

jobs:
- name: docker-job
  plan:
  - get: source
    trigger: true
  - task: runDockerContainer
    privileged: true        # required
    file: source/path_to_task_definition/taskDefinition.yml
    
... 
```

Task definition (e.g. taskDefinition.yml):

``` yaml
platform: linux

image_resource:
        type: docker-image
        source: {
        repository: quay.io/cosee-concourse/dind,
        tag: "latest" }

run:
        path: sh
        args:
        - -exc
        - |
          source /docker-lib.sh               # required
          start_docker                        # required
          # for own Dockerfiles:
          cd source/path_to_dockerfile
          docker build -t testimage .
          docker run -it --rm testimage parameter
          # other example: use image from Docker Hub:
          docker run -it --rm ubuntu echo "Hello World"

inputs:
    - name: source
```

## Contributing
This project uses code of [mumoshu/dcind](https://github.com/mumoshu/dcind)
