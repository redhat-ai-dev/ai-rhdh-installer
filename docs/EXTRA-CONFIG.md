# Extra Customization Options

## GitLab Integration

To configure RHDH to use GitLab as the git repository source, you will need to first run `export RHDH_GITLAB_INTEGRATION=true` before running any of the configuration scripts. Run `export RHDH_GITHUB_INTEGRATION=false` to disable GitHub integration.

## Lightspeed Plugin Configuration

The Lightspeed plugin is installed as part of the Developer Hub configuration script if the `LIGHTSPEED_INTEGRATION` environment variable is set to `true`. This will require setting the variable `LIGHTSPEED_MODEL_URL` to the desired model endpoint. Optionally, set the variable `LIGHTSPEED_API_TOKEN` for authenticated communication with the model service.

## Setting Environment Variables for Configuration Scripts

For more information regarding where you can obtain these values see [APP-SETUP.md](./APP-SETUP.md).

By running `configure.sh` you have the option of giving your input via CLI or by setting the environment variables listed below. If you opt for manual input, a `private.env` file will be created for you at the end for future use. To preset your `private.env` and avoid manual input via CLI, follow the steps below:

1. Run `cp default-private.env private.env` from the root of the repository to copy the starting point into a private environment variables file
2. Set each of these environment variables to the private values needed for the configuration scripts, surround all multiline values with `''`
    - `GITHUB__APP__ID`
        - GitHub Organization App ID
    - `GITHUB__APP__CLIENT__ID`
        - GitHub Org App Client ID (alternative to `GITLAB__APP__CLIENT__ID`)
    - `GITHUB__APP__CLIENT__SECRET`
        - GitHub Org App Client Secret (alternative to `GITLAB__APP__CLIENT__SECRET`)
    - `GITHUB__APP__WEBHOOK__URL`
        - GitHub App Webhook URL to pipelines as code service
    - `GITHUB__APP__WEBHOOK__SECRET`
        - User set GitHub App Webhook Secret
    - `GITHUB__APP__PRIVATE_KEY`
        - GitHub App Private Key
    - `GITHUB__HOST`
        - Hostname to GitHub service (defaults to `github.com`, alternative to `GITLAB__HOST`)
    - `GITHUB__ORG__NAME`
        - Name of the tied GitHub organization (alternative to `GITLAB__GROUP__NAME`)
    - `GITOPS__GIT_TOKEN`
        - Git Personal Access Token (alternative to `GITLAB__TOKEN`)
    - `GITLAB__APP__CLIENT__ID`
        - GitLab App Client ID (alternative to `GITHUB__APP__CLIENT__ID`)
    - `GITLAB__APP__CLIENT__SECRET`
        - GitLab App Client Secret (alternative to `GITHUB__APP__CLIENT__SECRET`)
    - `GITLAB__TOKEN`
        - GitLab Personal Access Token (alternative to `GITOP__GIT_TOKEN`)
    - `GITLAB__HOST`
        - Hostname to GitLab service (defaults to `gitlab.com`, alternative to `GITHUB__HOST`)
    - `GITLAB__GROUP__NAME`
        - Name of the tied GitLab group (alternative to `GITHUB__ORG__NAME`)
    - `GITLAB__ORG__ENABLED`
        - Indicates whether target GitLab instance has organizations enabled or not - `true` or `false`
    - `QUAY__DOCKERCONFIGJSON`
        - Docker Config JSON File with Authentication Credentials for a given [Quay.io](https://quay.io) Account
    - `QUAY__API_TOKEN`
        - Quay Org API Token
    - `RHDH_GITHUB_INTEGRATION`
        - Toggle GitHub integration (login). Accepts `true` or `false`
    - `RHDH_GITLAB_INTEGRATION`
        - Toggle GitLab integration (login). Accepts `true` or `false`
    - `LIGHTSPEED_INTEGRATION`
        - Toggle installing the lightspeed plugin
    - `LIGHTSPEED_MODEL_URL`
        - Target model URL for lightspeed plugin
    - `LIGHTSPEED_API_TOKEN`
        - API token for lightspeed plugin model service

## Setting Catalogs for Developer Hub Configuration

The [`configure-dh.sh`](../scripts/configure-dh.sh) script uses [`catalogs.yaml`](../catalogs.yaml) by default, you can provide your own custom catalogs URL list instead by following these steps:
1. Create a yaml file to use as your catalogs URL list, content should begin with `catalogs` at root level as follows:
```yaml
catalogs:
```
2. Add the link(s) to the catalog files you wish to include in your developer hub deployment:
```yaml
catalogs:
    - https://github.com/<org-or-user>/ai-lab-template/blob/main/all.yaml
```
3. Export `CATALOGS_FILE` to be set to your file:
```sh
export CATALOGS_FILE=<path-to-your-catalogs-list-file>
```
4. Now when you run `configure-dh.sh` it should use `<path-to-your-catalogs-list-file>` instead

Alternatively, you can edit the existing [`catalogs.yaml`](../catalogs.yaml) file with your updated url(s).