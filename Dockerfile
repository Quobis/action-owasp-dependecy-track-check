# Container image that runs your code
FROM ubuntu:noble

# Metadata for CycloneDX-CLI
ARG CDX_CLI_VERSION=0.33.1
ARG CDX_CLI_SHA256=bfc8b2538da86fe239bc53658bbb63c1c8c510a293c1e6891aa5bea5d3c58746

ENV DEBIAN_FRONTEND=noninteractive

# using --no-install-recommends to reduce image size

RUN apt-get update \
    && apt-get install --no-install-recommends -y git golang \
    ca-certificates curl jq build-essential unzip dotnet-sdk-8.0


# Installing Cyclone BoM generates for the different supported languages

RUN go install github.com/ozonru/cyclonedx-go/cmd/cyclonedx-go@latest \
    && cp /root/go/bin/cyclonedx-go /usr/bin/

# download cyclonedx-cli
RUN curl -fsSL -o /usr/bin/cyclonedx-cli \
      "https://github.com/CycloneDX/cyclonedx-cli/releases/download/v${CDX_CLI_VERSION}/cyclonedx-linux-x64" \
    && echo "${CDX_CLI_SHA256}  /usr/bin/cyclonedx-cli" | sha256sum -c - \
    && chmod +x /usr/bin/cyclonedx-cli

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh
# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
