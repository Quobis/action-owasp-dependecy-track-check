# Container image that runs your code
FROM ubuntu:focal

ENV DEBIAN_FRONTEND noninteractive

# using --no-install-recommends to reduce image size
RUN apt-get update && apt-get install -y software-properties-common && add-apt-repository ppa:ondrej/php \
    && apt-get update && apt-get install --no-install-recommends -y git nodejs npm \
    python3 python3-pip golang curl jq default-jdk php7.3 php7.3-xml php7.3-mbstring \
    && curl -sS "https://getcomposer.org/installer" -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/bin --version=2.0.14 --filename=composer \
    && apt-get update

# Installing Cyclone BoM generates for the different supported languages
RUN npm install -g @cyclonedx/bom && pip install cyclonedx-bom && go get github.com/ozonru/cyclonedx-go/cmd/cyclonedx-go && cp /root/go/bin/cyclonedx-go /usr/bin/
#RUN mkdir /home/dtrack && cd /home/dtrack && git clone git@github.com:SCRATCh-ITEA3/dtrack-demonstrator.git

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]