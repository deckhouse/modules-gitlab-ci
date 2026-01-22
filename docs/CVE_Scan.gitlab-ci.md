# CVE_Scan CI Integration

## Description
This CI file will run a Trivy CVE scan against the module images and its submodule images, and then upload the reports to DefectDojo.
The script will detect release or dev tag of module image is used and then construct registry location by itself. If your module located in registries by not standart paths - you may want to define custom path by *MODULE_PROD_REGISTRY_CUSTOM_PATH* and *MODULE_DEV_REGISTRY_CUSTOM_PATH* variables.
CI Use cases:
- Scan by scheduler
  - Scan main branch and several latest releases 2-3 times a week
- Scan on PR
  - Scan images on pull request to check if no new vulnerabilities are present or to ensure if they are closed.
- Manual scan
  - Scan specified release by entering semver minor version of target release in *release_branch* variable.
  - Scan main branch and several latest releases by setting *SCAN_SEVERAL_LASTEST_RELEASES* to "true" and optionally defining amount of latest minor releases by setting a number into *LATEST_RELEASES_AMOUNT* variable.
  - Scan only main branch just by running pipeline

## Variables

### Pipeline variables section
```
CVE_RELEASE_TO_SCAN - Set minor version of release you want to scan. e.g.: 1.23
CVE_SEVERITY - Set CVE severity levels to scan. Default is: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
CVE_SCAN_SEVERAL_LASTEST_RELEASES - true/false. Whether to scan last several releases or not. For scheduled pipelines override will not work as value is always true.
```

### Job level

#### Mandatory
```
TAG - module image tag
MODULE_NAME - module name
PROD_REGISTRY - must be deckhouse prod read registry, used to get trivy databases and release images
PROD_REGISTRY_USER - username to log in to deckhouse prod read registry
PROD_REGISTRY_PASSWORD - password to log in to deckhouse prod read registry
DEV_REGISTRY - must be deckhouse dev registry, used to get dev images
DEV_REGISTRY_USER - username to log in to deckhouse dev registry
DEV_REGISTRY_PASSWORD - password to log in to deckhouse dev registry
```

#### Optional
The following variables should not be defined if their default values are ok for your needs.
```
SCAN_SEVERAL_LASTEST_RELEASES - true/false. Whether to scan last several releases or not. For scheduled pipelines override will not work as value is always true.
TRIVY_REPORTS_LOG_OUTPUT - true/false. Output Trivy reports into CI job log, default - true
LATEST_RELEASES_AMOUNT - Optional. Number of latest releases to scan. Default is: 3
SEVERITY - Optional. Vulnerabilities severity to scan. Default is: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
MODULE_PROD_REGISTRY_CUSTOM_PATH - Optional. Module custom path in prod registry. Example: flant/modules
MODULE_DEV_REGISTRY_CUSTOM_PATH - Optional. Module custom path in dev registry. Example: flant/modules
```

### GitLab Masked variables
```
DD_URL - URL to defectDojo
DD_TOKEN - token of defectDojo to upload reports
PROD_REGISTRY - must be deckhouse prod read registry, used to get trivy databases and release images
PROD_REGISTRY_USER - username to log in to deckhouse prod read registry
PROD_REGISTRY_PASSWORD - password to log in to deckhouse prod read registry
DEV_REGISTRY - must be deckhouse dev registry, used to get dev images
DEV_REGISTRY_USER - username to log in to deckhouse dev registry
DEV_REGISTRY_PASSWORD - password to log in to deckhouse dev registry
```

## How to include

At the top of your main .gitlab-ci.yml define include section:
```
include:
  - remote: 'https://raw.githubusercontent.com/deckhouse/modules-gitlab-ci/refs/heads/v2.0/templates/CVE_Scan.gitlab-ci.yml'
```

Add global variables with ability to redefine by manual execution in GitLab web UI:
```
variables:
  CVE_RELEASE_TO_SCAN:
    value: ""
    description: "Optional. Set minor version of release you want to scan. e.g.: 1.23"
  CVE_SEVERITY:
    value: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
    description: "Optional. Set CVE severity levels to scan. Default is: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
  CVE_SCAN_SEVERAL_LASTEST_RELEASES:
    value: "false"
    description: "Optional. true/false. Whether to scan last several releases or not. For scheduled pipelines override will not work as value is always true."
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
  before_script:
    # Override default before_script as not needed
    - |
      echo "Executing CVE Scan"
  variables:
    DD_URL: ${DD_URL}
    DD_TOKEN: ${DD_TOKEN}
    TAG: $MODULES_MODULE_TAG
    MODULE_NAME: $MODULES_MODULE_NAME
    DEV_REGISTRY: ${DEV_REGISTRY}
    DEV_REGISTRY_PASSWORD: ${DEV_REGISTRY_PASSWORD}
    DEV_REGISTRY_USER: ${DEV_REGISTRY_LOGIN}
    PROD_REGISTRY: ${PROD_REGISTRY}
    PROD_REGISTRY_USER: ${PROD_REGISTRY_USER}
    PROD_REGISTRY_PASSWORD: ${PROD_REGISTRY_USER}
    SEVERITY: ${CVE_SEVERITY}
    SCAN_SEVERAL_LASTEST_RELEASES: ${CVE_SCAN_SEVERAL_LASTEST_RELEASES}
  extends:
    - .cve_scan
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      needs: ["build_dev"]
      variables:
        TAG: mr${CI_MERGE_REQUEST_IID}
        SEVERITY: "HIGH,CRITICAL"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      needs: ["build_main"]
      variables:
        TAG: ${CI_DEFAULT_BRANCH}
        SEVERITY: "HIGH,CRITICAL"
    - if: $CI_COMMIT_TAG && $CI_COMMIT_BRANCH != "main"
      variables:
        TAG: ${CI_COMMIT_TAG}
        SEVERITY: "HIGH,CRITICAL"
      when: manual
    - if: $CI_PIPELINE_SOURCE == "schedule"
      variables:
        LATEST_RELEASES_AMOUNT: 3
    - if: $CI_PIPELINE_SOURCE == "web"
      variables:
        TAG: ${CVE_RELEASE_TO_SCAN}
```
Please note, that some variables can be used as global in 'variables' section of your .gitlab-ci file.
You can also define required rules to execute this job depend on your workflow needs.
