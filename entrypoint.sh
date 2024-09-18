#!/bin/sh -l

DTRACK_URL=$1
DTRACK_KEY=$2
LANGUAGE=$3
PATHS=$(echo "$4" | jq -r '.[]')
output=""

INSECURE="--insecure"
#VERBOSE="--verbose"

# Access directory where GitHub will mount the repository code
# $GITHUB_ variables are directly accessible in the script
cd $GITHUB_WORKSPACE

# Loop through each path
for path in $PATHS; do
    echo "[*] Processing path: $path"

    # Ensure the project is Java-based
    case $LANGUAGE in
        "java")
            echo "[*]  Processing Java BoM for $path"
            if [ ! $? = 0 ]; then
                echo "[-] Error executing Java build. Stopping the action!"
                exit 1
            fi

            # Go to the project path and build using Maven
            cd "$path"
            apt-get install --no-install-recommends -y build-essential default-jdk maven
            BoMResult=$(mvn package -DskipUT=true)
            bom_file="target/bom.xml"
            ;;
        *)
            echo "[-] Project type not supported: $LANGUAGE"
            exit 1
            ;;
    esac    

    if [ ! $? = 0 ]; then
        echo "[-] Error generating BoM file in path $path: $BoMResult. Stopping the action!"
        exit 1
    fi

    echo "[*] BoM file successfully generated at $bom_file"

    # Cyclonedx CLI conversion
    echo "[*] Cyclonedx CLI conversion for $path"
    cyclonedx-cli convert --input-file "$bom_file" --output-file sbom.json --output-format json_v1_2

    # UPLOAD BoM to Dependency Track server
    echo "[*] Uploading BoM file for $path to Dependency Track server"
    upload_bom=$(curl $INSECURE $VERBOSE -s --location --request POST $DTRACK_URL/api/v1/bom \
    --header "X-Api-Key: $DTRACK_KEY" \
    --header "Content-Type: multipart/form-data" \
    --form "autoCreate=true" \
    --form "projectName=$GITHUB_REPOSITORY-$path" \
    --form "projectVersion=$GITHUB_REF" \
    --form "bom=@sbom.json")

    token=$(echo $upload_bom | jq ".token" | tr -d "\"")
    echo "[*] BoM file successfully uploaded with token $token for path $path"

    if [ -z "$token" ]; then
        echo "[-] The BoM file for $path has not been successfully processed by OWASP Dependency Track"
        exit 1
    fi

    echo "[*] Checking BoM processing status for $path"
    processing=$(curl $INSECURE $VERBOSE -s --location --request GET $DTRACK_URL/api/v1/bom/token/$token \
    --header "X-Api-Key: $DTRACK_KEY" | jq '.processing')

    counter=0
    while [ "$processing" = true ]; do
        sleep 5
        processing=$(curl  $INSECURE $VERBOSE -s --location --request GET $DTRACK_URL/api/v1/bom/token/$token \
        --header "X-Api-Key: $DTRACK_KEY" | jq '.processing')
        if [ $((++counter)) -eq 10 ]; then
            echo "[-] Timeout while waiting for processing result for path $path. Please check the OWASP Dependency Track status."
            exit 1
        fi
    done

    echo "[*] OWASP Dependency Track processing completed for $path"

    # Wait to make sure the score is available
    sleep 5

    echo "[*] Retrieving project information for $path"
    project=$(curl  $INSECURE $VERBOSE -s --location --request GET "$DTRACK_URL/api/v1/project/lookup?name=$GITHUB_REPOSITORY-$path&version=$GITHUB_REF" \
    --header "X-Api-Key: $DTRACK_KEY")

    echo "$project"

    project_uuid=$(echo $project | jq ".uuid" | tr -d "\"")
    risk_score=$(echo $project | jq ".lastInheritedRiskScore")
    echo "Project risk score for $path: $risk_score"

    # Append this path and its risk score to the output string
    output="${output}Path: $path, Risk Score: $risk_score\n"
done

# Output the final result with all paths and their risk scores
echo -e "::set-output name=riskscores::$output"