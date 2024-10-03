## Lightspeed Plugin Configuration

You can install and configure the RHDH lightspeed plugin by running the `scripts/install-lightspeed-plugin.sh` file in your terminal.

### Prerequisites

The installation requires the following:
 - an instance of RHDH installed with this project's helm chart
 - `yq`
 - `kubectl`
 - URL to an existing AI model
 - for authenticated access to AI models, an access token

If you installed RHDH using the `install.sh` script, there is no additional configuration.

If you installed by directly calling `helm upgrade`, the default backstage config map needs to be updated before installing additional plugins, with the following data:

```yaml
default.app-config.yaml: |
  app:
    baseURL: <route to RHDH frontend>
    title: Red Hat Developer Hub
  backend:
    auth:
      keys:
        - secret: <secret>
    baseUrl: <route to RHDH frontend>
    cors:
      origin: <route to RHDH frontend>
```

### Installation

To install the plugin follow these steps:
 1. export `LIGHTSPEED_TARGET` variable with the URL of your AI model service
 2. export `LIGHTSPEED_TOKEN` variable with access token for authenticated access to your AI model
 3. run `scripts/install-lightspeed-plugin.sh` script in a shell

The script applies all the required configuration, and then rolls out a new RHDH pod.