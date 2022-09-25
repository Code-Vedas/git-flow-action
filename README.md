# Gitflow Action

This action will help you to manage your gitflow workflow.

## Usage

```yaml
name: Gitflow
on:
  issue_comment:
    types: [created]
jobs:
  gitflow:
    runs-on: ubuntu-latest
    name: Gitflow
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Checkout Pull Request
        run: hub pr checkout ${{ github.event.issue.number }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Gitflow
        uses: Code-Vedas/git-flow-action
        with:
          allowed-authors: '["Code-Vedas"]'
          dry-run: false
          develop-branch: "develop"
          production-branch: "master"
          feature-branch-prefix: "feature/"
          release-branch-prefix: "release/"
          hotfix-branch-prefix: "hotfix/"
          version-tag-prefix: "v"
```
