# CVE_Scan CI Integration

## Description
This ci file will run Trivy CVE scan against module image and its submodules images and then upload reports to defectDojo.

## Variables

### Job level
```
IMAGE - full path for module image. e.g.: regestryType.deckhouse.io/path/to/module
TAG - module image tag
MODULE_NAME - module name
DECKHOUSE_PROD_REGISTRY - must be deckhouse read registry, used to get trivy databases
```

### GitLab Masked variables
```
DD_TOKEN - token of defectDojo to upload reports
DECKHOUSE_PROD_REGISTRY_USER - username to log in to deckhouse read registry
DECKHOUSE_PROD_REGISTRY_PASSWORD - password to log in to deckhouse read registry
```

## How to include

At the top of your main .gitlab-ci.yml define include section:  
```
include:
  - project: 'deckhouse/modules/gitlab-ci'
    ref: main
    file: 'templates/CVE_Scan.gitlab-ci.yml'
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
    IMAGE: regestryType.deckhouse.io/path/to/module
    TAG: moduleImageTag
    MODULE_NAME: module-name
    DECKHOUSE_PROD_REGISTRY: registry.deckhouse.io
  extends:
    - .cve_scan
```
Please note, that some variables can be used as global in 'variables' section of your .gitlab-ci file.  
You can also define required rules to execute this job depend on your workflow needs.