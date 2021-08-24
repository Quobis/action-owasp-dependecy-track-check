# action-owasp-dependecy-track-check
This Github action generates a BoM (Bill Of Materials) of your project and uploads it to an OWASP Dependency Track instance to perform a vulnerability check. In order to use it, you will need an OWASP Dependency Track instance and an access Key to be able to use the REST API from Internet. 

One of the main advantages is that you can customize the vulnerability check sources Dependency Track will use, you can easily check the project status of the different versions using the Dependency Track WUI and you can also check the licenses of the different libraries you project is using. 

The project will be uploaded to the OWASP Dependency Track server using the repository name as `project` and the branch or tag name as `version`.

We recommend to use the version tags to chose the specific action version which works fine in your workflow and OWASP Dependency Track version. However the main branch can also be used since we are not expecting to include breaking changes in future versions. 

**OWASP Dependency Track v4.0.1** has been successfully tested with tags **v.1**, **v1.0**,**v1.1** and **1.2**. 

Feedback, contributions, bug reports and improvements issues are really welcome. 

## Input variables
This action requires 3 input variables:
- **url**: URL of the OWASP Dependency Track server
- **key**: KEY used to access the OWASP Dependency Track server, please not that this must no be appropiate for public repositories. This key is confidencial information, so we recommend to [create a secret](https://docs.github.com/en/actions/reference/encrypted-secrets#creating-encrypted-secrets-for-a-repository) in the project settings. In the action example we use the name `SECRET_OWASP_DT_KEY` for this secret.
- **language**: (refer to the next section)

## Output variables
- **riskscore**: this variable will contain the risk score calculated by OWASP Dependency Track based on the found vulnerabilities. This output can be used to make decision such as notify the developer or use it as the input of the next step of the workflow.
## Supported languages
Currently this action supports the generation of upload of projects devloped in the languages as follows:
- **Node.js**: define the language variable as `nodejs`. `npm install` will be executed within the container to gather all the dependencies.  
- **Python**: define the language variable as `python`. It will get the package information from requirements.txt. 
- **Golang**: define the language variable as `golang`. It will get the package information from go.mod, which is typically present in the repository.
- **Ruby**: define the language variable as `ruby`. It will get the package information from Gemfile.lock. 
- **Maven**: define the language variable as `java`. It will get the package information from pom.xml.
- **NuGet (.NET)**: define the language variable as `dotnet`. It will get the package information from a .sln, .csproj, .vbproj, or packages.config file. 
- **Php Composer**: define the language variable as `php`. It will get the package information from composer.json.


Please note that if any of the files above is not available the action will fail when trying to generate the BoM files. 


## How to use it
Github provides really helpful resources to learn to include any action in your workflow. This [Introduction to actions](https://docs.github.com/en/actions/learn-github-actions/introduction-to-github-actions) may be specially useful for beginners. However, we've add some of the steps you'll have to go through in order to get it up and running.

**Step 0: Add CycloneDX plugin to your project (only Maven/Java projects)**
+ Get the cyclonedx-maven-plugin. 
From the [cyclonedx-maven-plugin](https://github.com/CycloneDX/cyclonedx-maven-plugin) repository you'll be able to get the code below. The default information of the plugin shown below is more extense (you could use the simplified one), but this will allow you to modify some useful parameters later on.
```xml
<plugin>
        <groupId>org.cyclonedx</groupId>
        <artifactId>cyclonedx-maven-plugin</artifactId>
        <version>2.5.2</version>
        <executions>
            <execution>
                <phase>package</phase>
                <goals>
                    <goal>makeAggregateBom</goal>
                </goals>
            </execution>
        </executions>
        <configuration>
            <projectType>library</projectType>
            <schemaVersion>1.3</schemaVersion>
            <includeBomSerialNumber>true</includeBomSerialNumber>
            <includeCompileScope>true</includeCompileScope>
            <includeProvidedScope>true</includeProvidedScope>
            <includeRuntimeScope>true</includeRuntimeScope>
            <includeSystemScope>true</includeSystemScope>
            <includeTestScope>false</includeTestScope>
            <includeLicenseText>false</includeLicenseText>
            <outputFormat>all</outputFormat>
            <outputName>bom</outputName>
        </configuration>
    </plugin>
```


+ Edit your `pom.xml` file by adding the plugin. 
Paste the code shown above into the `plugins` secction of your project's pom.xml. For more info visit [here](https://maven.apache.org/guides/mini/guide-configuring-plugins.html). 

![alt text](./docs/cyclonedx-maven-plugin%20install.png)

![alt text](./example-action.yaml)

Note that you must **change** the `<phase>` tag value to `compile` (`package` by default), otherwise the action won't even generate the bom.xml. This action will compile your Maven Java project and expects to find a resulting `bom.xml`. You may also change other values such as the `<schemaVersion>` related to the resulting BoM Format version. 

**Step 1: Get your Dependency Track both URL and Key**

This will let you use the API to upload your projects' bom.xml from this GitHub action.
+ How to get your Key. Go to Configuration -> Teams -> Create Team to create a new team. This will also create a corresponding API Key, although a team might have multiple Keys. You can find more info about this [here](https://docs.dependencytrack.org/integrations/rest-api/).

**Step 2: Set up your action.yml file**
+ Start by creating a `.github/workflows` directory in your repository if it doesn't already exist.
+ In this directory, create a file named `owasp-dt-check.yml`.
+ Copy the example shown below into your `owasp-dt-check.yml` file:
  
```yaml
# This is a basic workflow to help you get started with Actions

name: CI

# Controls when the action will run. 
on: [push]

  # Allows you to run this workflow manually from the Actions tab
  # workflow_dispatch:

# A workflow run is made up of one or more jobs that can run sequentially or in parallel
jobs:
  # This workflow contains a single job called "build"
  build:
    # The type of runner that the job will run on
    runs-on: ubuntu-latest

    # Steps represent a sequence of tasks that will be executed as part of the job
    steps:
      # Checks-out your repository under $GITHUB_WORKSPACE, so your job can access it
      - uses: actions/checkout@v2 
      
      # Generates a BoM and uploads it to OWASP Dependency Track
      - name: Generates BoM and upload to OWASP DTrack
        id: riskscoreFromDT
        uses:  Quobis/action-owasp-dependecy-track-check@main
        with:
          url: 'https://dtrack.quobis.com'
          key: '${{ secrets.SECRET_OWASP_DT_KEY }}'
          language: 'golang'
      
      # Show the risk score output 
      - name: Get the output time
        run: echo "The risk score of the project is ${{ steps.riskscoreFromDT.outputs.riskscore }}"
```

Don't forget to change the `url` `key` and `language` according to your project and Dependecy Track server. As you can see, we're using a secret to save our DT's user valid key. We strongly recommend you to do so.

We also added an example of the `yaml` file which can be included in the workflow to use this action. You can find the file `example-action.yaml` in this repository.

+ Commit changes to your repository `.workflow` directory. Once you finish don't forget to save and commit. This will trigger the workflow is first run as it's configure to start on every push.


## Development notes
The repository files are mounted in the Dockerfile in `/github/workspace` directory. The script generates the BoM from those files and upload them to the OWASP Dependency Track specified as a parameter of the Action. After uploading the BoM it waits for the result and provides it as the output of the script. 

`$GITHUB_WORKSPACE`	stores the GitHub workspace directory path. The workspace directory is a copy of your repository if your workflow uses the actions/checkout action. If you don't use the `actions/checkout` action, the directory will be empty. For example, `/home/runner/work/my-repo-name/my-repo-name`.

## Acknowledgments

This project was made possible thanks to [SCRATCh](https://scratch-itea3.eu/), an ITEA3 project.
