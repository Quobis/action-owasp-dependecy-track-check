#!/bin/sh -l

DTRACK_URL=$1
DTRACK_KEY=$2
LANGUAGE=$3
DIRECTORY="${4:-.}"
NODE_VERSION="${5:-22.14.0}"

DEPTRACK_RETRIES_TIMEOUT=50
INSECURE="--insecure"
VERBOSE="--verbose"

# Access directory where GitHub will mount the repository code
# $GITHUB_ variables are directly accessible in the script
cd $GITHUB_WORKSPACE

# for monorepos : change directory to a sub directory specified by the user
cd "$GITHUB_WORKSPACE/$DIRECTORY" || { echo "[-] Directory not found: $DIRECTORY"; exit 1; }

# for monorepos : change project name with sub-directory
DIRECTORY_NAME_CLEAN=$(echo "$DIRECTORY" | sed -e 's#^\(\./\)*##' -e 's#/*$##')
if [ -z "$DIRECTORY_NAME_CLEAN" ] || [ "$DIRECTORY_NAME_CLEAN" = "." ]; then
    PROJECT_NAME="$GITHUB_REPOSITORY"
else
    PROJECT_NAME="$GITHUB_REPOSITORY-$DIRECTORY_NAME_CLEAN"
    echo "[*] Using Dependency Track project : $PROJECT_NAME"
fi

# Validate node version
case "$NODE_VERSION" in
    ""|*[!0-9.]*) echo "[-] Invalid node_version: $NODE_VERSION"; exit 1 ;;
esac

install_specific_node_version() {
    (
        cd /tmp \
        && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
        && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
           | grep " node-v${NODE_VERSION}-linux-x64.tar.xz\$" | sha256sum -c - \
        && tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" -C /usr/local --strip-components=1
    ) || { echo "[-] Node.js installation failed. Stopping the action!"; exit 1; }
}

case $LANGUAGE in
    "nodejs"|"npm")
        lscommand=$(ls)
        echo "[*] Processing NodeJS BoM"
        install_specific_node_version
        npm install
        if [ ! $? = 0 ]; then
            echo "[-] Error executing npm install. Stopping the action!"
            exit 1
        fi
        npm install -g @cyclonedx/cyclonedx-npm
        path="bom.xml"
        cyclonedx-npm --help
        BoMResult=$(cyclonedx-npm --output-format XML --output-file bom.xml)
        ;;

    "npm-ci")
        lscommand=$(ls)
        echo "[*] Processing NodeJS BoM"
        install_specific_node_version
        # npm clean-install --ignore-scripts
        # if [ ! $? = 0 ]; then
        #     echo "[-] Error executing npm install. Stopping the action!"
        #     exit 1
        # fi
        [ -f package-lock.json ] || { echo "[-] package-lock.json not found. Stopping the action!"; exit 1; }
        npm install -g @cyclonedx/cyclonedx-npm
        path="bom.xml"
        cyclonedx-npm --help
        BoMResult=$(cyclonedx-npm --output-format XML --output-file bom.xml --package-lock-only)
        ;;
    
    "python")
        echo "[*]  Processing Python BoM"
        apt-get install --no-install-recommends -y python3 python3-pip
        # freeze=$(pip freeze > requirements.txt)
        # if [ ! $? = 0 ]; then
        #     echo "[-] Error executing pip freeze to get a requirements.txt with frozen parameters. Stopping the action!"
        #     exit 1
        # fi
        # this is acceptable because the container will be thrown away, otherwise ubuntu noble will not let a pip install without virtualenv
        pip install --break-system-packages cyclonedx-bom 
        path="bom.xml"
        BoMResult=$(cyclonedx-py requirements --output-format XML -o bom.xml)
        ;;
    
    "golang")
        echo "[*]  Processing Golang BoM"
        if [ ! $? = 0 ]; then
            echo "[-] Error executing go build. Stopping the action!"
            exit 1
        fi
        path="bom.xml"
        BoMResult=$(cyclonedx-go -o bom.xml)
        ;;

    "ruby")
        echo "[*]  Processing Ruby BoM"
        if [ ! $? = 0 ]; then
            echo "[-] Error executing Ruby build. Stopping the action!"
            exit 1
        fi
        apt-get install --no-install-recommends -y build-essential ruby-dev
        gem install cyclonedx-ruby
        path="bom.xml"
        BoMResult=$(cyclonedx-ruby -p ./ -o bom.xml)
        ;;

    "java")
        echo "[*]  Processing Java BoM"
        if [ ! $? = 0 ]; then
            echo "[-] Error executing Java build. Stopping the action!"
            exit 1
        fi
        apt-get install --no-install-recommends -y build-essential default-jdk maven
        path="target/bom.xml"
        BoMResult=$(mvn compile)
        ;;
        
    "dotnet")
        echo "[*]  Processing Golang BoM"
        if [ ! $? = 0 ]; then
            echo "[-] Error executing NuGet (Dotnet) build. Stopping the action!"
            exit 1
        fi
        path="bom.xml/bom.xml"
        dotnet tool install --global CycloneDX
        apt-get update
        # The path to a .sln, .csproj, .vbproj, or packages.config file or the path to 
        # a directory which will be recursively analyzed for packages.config files
        BoMResult=$(dotnet CycloneDX . -o bom.xml)
        ;;
        
    "php")
        echo "[*]  Processing Php Composer BoM"
        if [ ! $? = 0 ]; then
            echo "[-] Error executing Php build. Stopping the action!"
            exit 1
        fi
        apt-get install --no-install-recommends -y build-essential php php-xml php-mbstring
        curl -sS "https://getcomposer.org/installer" -o composer-setup.php
        php composer-setup.php --install-dir=/usr/bin --version=2.0.14 --filename=composer
        composer require --dev cyclonedx/cyclonedx-php-composer
        path="bom.xml"
        BoMResult=$(composer make-bom --spec-version="1.2")
        ;;

    *)
        echo "[-] Project type not supported: $LANGUAGE"
        exit 1
        ;;
esac    

if [ ! $? = 0 ]; then
    echo "[-] Error generating BoM file: $BomResult. Stopping the action!"
    exit 1
fi

echo "[*] BoM file succesfully generated"

if [ -z $VERBOSE ]; then
    cat $BomResult
fi

# Cyclonedx CLI conversion
echo "[*] Cyclonedx CLI conversion"
#Does not upload to dtrack when output format = xml (every version available)
cyclonedx-cli convert --input-file $path --input-format xml --output-file sbom.json --output-format json --output-version v1_5  || { echo "[-] CycloneDX CLI conversion failed. Stopping the action!"; exit 1; }

# UPLOAD BoM to Dependency track server
echo "[*] Uploading BoM file to Dependency Track server"
upload_bom=$(curl $INSECURE $VERBOSE -s --location --request POST $DTRACK_URL/api/v1/bom \
--header "X-Api-Key: $DTRACK_KEY" \
--header "Content-Type: multipart/form-data" \
--form "autoCreate=true" \
--form "projectName=$PROJECT_NAME" \
--form "projectVersion=$GITHUB_REF" \
--form "bom=@sbom.json")

token=$(echo $upload_bom | jq ".token" | tr -d "\"")
echo "[*] BoM file succesfully uploaded with token $token"


if [ -z $token ]; then
    echo "[-]  The BoM file has not been successfully processed by OWASP Dependency Track"
    exit 1
fi

echo "[*] Checking BoM processing status"
processing=$(curl $INSECURE $VERBOSE -s --location --request GET $DTRACK_URL/api/v1/bom/token/$token \
--header "X-Api-Key: $DTRACK_KEY" | jq '.processing')


while [ "$processing" = "true" ]; do
    sleep 5
    processing=$(curl  $INSECURE $VERBOSE -s --location --request GET $DTRACK_URL/api/v1/bom/token/$token \
--header "X-Api-Key: $DTRACK_KEY" | jq '.processing')
    c=$((c + 1))
    if [ "$c" -eq $DEPTRACK_RETRIES_TIMEOUT ]; then
        echo "[-]  Timeout while waiting for processing result. Please check the OWASP Dependency Track status."
        exit 1
    fi
done

echo "[*] OWASP Dependency Track processing completed"

# wait to make sure the score is available, some errors found during tests w/o this wait
sleep 5

echo "[*] Retrieving project information"
project=$(curl  $INSECURE $VERBOSE -s --location --get "$DTRACK_URL/api/v1/project/lookup" \
--data-urlencode "name=$PROJECT_NAME" \
--data-urlencode "version=$GITHUB_REF" \
--header "X-Api-Key: $DTRACK_KEY")

echo "$project"

project_uuid=$(echo $project | jq ".uuid" | tr -d "\"")
risk_score=$(echo $project | jq ".lastInheritedRiskScore")
echo "Project risk score: $risk_score"

echo "riskscore=$risk_score" >> "$GITHUB_OUTPUT"
