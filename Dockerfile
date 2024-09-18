# Container image that runs your code
FROM ubuntu:focal

ENV DEBIAN_FRONTEND noninteractive

# using --no-install-recommends to reduce image size

RUN apt-get update \
    && apt-get install --no-install-recommends -y git npm golang \
    curl jq build-essential apt-transport-https unzip \
    libc6 libgcc1 libgssapi-krb5-2 libicu66 libssl1.1 libstdc++6 zlib1g \
    && curl -sS https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -o packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-5.0


# Installing Cyclone BoM generates for the different supported languages

#RUN mkdir /home/dtrack && cd /home/dtrack && git clone git@github.com:SCRATCh-ITEA3/dtrack-demonstrator.git
RUN go mod init deptrack/main
RUN go get github.com/ozonru/cyclonedx-go/cmd/cyclonedx-go && cp /root/go/bin/cyclonedx-go /usr/bin/
RUN rm go.mod

COPY cyclonedx-linux-x64 /usr/bin/cyclonedx-cli
COPY --from=eclipse-temurin:17 /opt/java/openjdk /opt/java/java17
RUN chmod +x /usr/bin/cyclonedx-cli

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh
# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
