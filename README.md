# action-owasp-dependecy-track-check
Github action to generate BoM and upload to OWASP dependency track for vulnerability analysis

The project will be uploaded to the OWASP Denpendency Track server using the repository name as `project` and the branch or tag name as `version`. 

## Supported languages
Currently this action supports the generation of upload of projects devloped in the languages as follows:
- Node.js: define the language variable as `nodejs`. `npm install` will be executed within the container to gather all the dependencies.  
- Python: define the language variable as `python`. It will get the package information from requirements.txt. 
- Golang: define the language variable as `golang`. It will get the package information from go.mod, which is typically present in the repository.

Please note that if any of the files above is not available the action will fail when trying to generate the BoM files. 

## Development notes
The repository files are mounted in the Dockerfile in `/github/workspace` directory. The script generates the BoM from those files and upload them to the OWASP Dependency Track specified as a parameter of the Action. After uploading the BoM it waits for the result and provides it as the output of the script. 

`$GITHUB_WORKSPACE`	stores the GitHub workspace directory path. The workspace directory is a copy of your repository if your workflow uses the actions/checkout action. If you don't use the `actions/checkout` action, the directory will be empty. For example, `/home/runner/work/my-repo-name/my-repo-name`.