# CVE_Scan CI Integration

## Description
This CI file will run a Trivy CVE scan against the module images and its submodule images, and then upload the reports to DefectDojo.

## Variables

### Job level
```
IMAGE - URL to a registry image, e.g., registry.example.com/deckhouse/modules/module_name
TAG - module image tag
MODULE_NAME - module name
```

### GitLab Masked variables
```
DD_URL - URL to defectDojo
DD_TOKEN - token of defectDojo to upload reports
TRIVY_REGISTRY - must be deckhouse prod registry, used to get trivy databases
TRIVY_REGISTRY_USER - username to log in to deckhouse prod registry
TRIVY_REGISTRY_PASSWORD - password to log in to deckhouse prod registry
```

## How to include

At the top of your main .gitlab-ci.yml define include section:  
```
include:
  - remote: 'https://raw.githubusercontent.com/deckhouse/modules-gitlab-ci/refs/heads/main/templates/CVE_Scan.gitlab-ci.yml'
```

Add cve_scan stage in a propper place in stages sequence (usually after build stage):  
```
stages:
  - cve_scan
```

Then choose a propper place in your pipeline to put CVE scan job (usually after build stage) and add required variables.  
Example:  
```
cve_scan:
  stage: cve_scan
  needs: ['build_dev']
  variables:
    IMAGE: registry.example.com/path/to/module
    TAG: moduleImageTag
    MODULE_NAME: module-name
  extends:
    - .cve_scan
```
Please note, that some variables can be used as global in 'variables' section of your .gitlab-ci file.  
You can also define required rules to execute this job depend on your workflow needs.
