# Hoofbeat load test action

Run a [Hoofbeat](https://hoofbeat.dev/?utm_source=github&utm_medium=action) load test on every pull request. The job fails when the run breaks its pass/fail criteria (p95, errors…), the job summary shows the numbers, and cancelling the job stops the run.

## Usage

1. In Hoofbeat, create an API token under **Settings → API tokens** and save it as the repository secret `HOOFBEAT_TOKEN`.
2. Copy the flow id from the flow's page.

```yaml
# .github/workflows/load-test.yml
name: Load test
on: pull_request

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: elvinaqalarov99/hoofbeat-action@v1
        with:
          token: ${{ secrets.HOOFBEAT_TOKEN }}
          flow: <your flow id>
          # base-url: ${{ steps.deploy.outputs.preview-url }}  # test the PR's preview
```

| Input | Default | |
| --- | --- | --- |
| `token` | – | API token (required) |
| `flow` | – | Flow id (required) |
| `url` | `https://hoofbeat.dev` | Your Hoofbeat URL |
| `timeout-minutes` | `60` | Stop the run and fail after this long |
| `environment` | flow's default | Project environment, e.g. `staging` |
| `base-url` | flow's target | Test another URL on the verified host, e.g. a preview deployment |

Outputs: `run-url`, `passed`.

New to load testing in CI? Read [Load testing in CI](https://hoofbeat.dev/blog/load-testing-in-ci).

## License

MIT
