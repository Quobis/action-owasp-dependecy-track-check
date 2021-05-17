# action-owasp-dependecy-track-check
Github action to generate BoM and upload to OWASP dependency track to perform a vulnerability analysis. In order to use it you need an OWASP Dependency Track instance and an access Key to be able to use the REST API. 
The project will be uploaded to the OWASP Denpendency Track server using the repository name as `project` and the branch or tag name as `version`. 
We recommed to use the main version since we are not expecting to include breaking changes, however you can also use the version tags to use a fix version of the action which works fin in your environment. 

Any feedback, contributions, bug report and improvements issues are welcome. 

## Input variables
This action requires 3 input variables:
- **url**: URL of the OWASP Dependency Track server
- **key**: KEY used to access the OWASP Dependency Track server, please not that this must no be appropiate for public repositories.
- **language**: (refer to the next section)

## Output variables
- **riskscore**: this variable will contain the risk score calculated by OWASP Dependency Track based on the found vulnerabilities. This output can be used to make decision such as notify the developer or use it as the input of the next step of the workflow.
## Supported languages
Currently this action supports the generation of upload of projects devloped in the languages as follows:
- **Node.js**: define the language variable as `nodejs`. `npm install` will be executed within the container to gather all the dependencies.  
- **Python**: define the language variable as `python`. It will get the package information from requirements.txt. 
- **Golang**: define the language variable as `golang`. It will get the package information from go.mod, which is typically present in the repository.

Please note that if any of the files above is not available the action will fail when trying to generate the BoM files. 


## How to use it
Github provides really helpful resources to learn to include any action in your workflow. This [Introduction to actions](https://docs.github.com/en/actions/learn-github-actions/introduction-to-github-actions) may be specially useful for beginners.

We also added an example of the `yaml` file which can be included in the workflow to use this action. You can fint the file in the `example-workflow` folder.

## Development notes
The repository files are mounted in the Dockerfile in `/github/workspace` directory. The script generates the BoM from those files and upload them to the OWASP Dependency Track specified as a parameter of the Action. After uploading the BoM it waits for the result and provides it as the output of the script. 

`$GITHUB_WORKSPACE`	stores the GitHub workspace directory path. The workspace directory is a copy of your repository if your workflow uses the actions/checkout action. If you don't use the `actions/checkout` action, the directory will be empty. For example, `/home/runner/work/my-repo-name/my-repo-name`.

## Acknowledgments

This project was made possible thanks to [SCRATCh](https://scratch-itea3.eu/), an ITEA3 project.
