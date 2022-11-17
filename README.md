# lftp-mirror-action

🚀 GitHub action to mirror files via SFTP.

## Table of Contents

* [Usage](#usage)
* [Inputs](#inputs)
* [Bugs & Features](#bugs--features)
* [License](#license)

## Usage

```yaml
name: Deploy via SFTP
on:
  push:
    branches:
      - main
jobs:
  deploy:
    name: Deploy
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - name: Checkout
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Deploy files via SFTP
        uses: pressidium/lftp-mirror-action@v1
        with:
          # SFTP credentials
          host: ${{ secrets.SFTP_HOST }}
          port: ${{ secrets.SFTP_PORT }}
          user: ${{ secrets.SFTP_USER }}
          pass: ${{ secrets.SFTP_PASS }}
          # lftp settings
          onlyNewer: true
          settings: 'sftp:auto-confirm=yes'
          # Mirror command options
          localDir: '.'
          remoteDir: '/var/www/html/example.com/public'
          reverse: true
          ignoreFile: '.lftp_ignore'
          options: '--verbose'
```

## Inputs

| Parameter           | Description                                                               | Required | Default            |
|---------------------|---------------------------------------------------------------------------|----------|--------------------|
| `host`              | The hostname of the SFTP server                                           | Yes      | N/A                |
| `port`              | The port of the SFTP server                                               | No       | `'22'`             |
| `user`              | The username to use for authentication                                    | Yes      | N/A                |
| `pass`              | The password to use for authentication                                    | Yes      | N/A                |
| `forceSSL`          | Refuse to send password in clear when server does not support SSL         | No       | `'true'`           |
| `verifyCertificate` | Verify server’s certificate to be signed by a known Certificate Authority | No       | `'true'`           |
| `fingerprint`       | Key fingerprint of the host we want to connect to                         | No       | `''`               |
| `onlyNewer`         | Only transfer files that are newer than the ones on the remote server     | No       | `'true'`           |
| `restoreMTime`      | Restore the modification time of the files (if necessary)                 | No       | `'true'`           |
| `parallel`          | Number of parallel transfers                                              | No       | `'1'`              |
| `settings`          | Any additional lftp settings to configure                                 | No       | `''`               |
| `localDir`          | The local directory to copy from (assuming `reverse` is set to `true`)    | No       | `'.'`              |
| `remoteDir`         | The remote directory to copy to (assuming `reverse` is set to `true`)     | No       | `'/var/www/html/'` |
| `reverse`           | Whether to copy from the remote to the local or the other way around      | No       | `'true'`           |
| `ignoreFile`        | The name of the file to use as the ignore list                            | No       | `'.lftp_ignore'`   |
| `options`           | Any additional `mirror` command options to configure                      | No       | `''`               |

### Fingerprint

Omitting the `fingerprint` input, defaults to accepting any fingerprint
(i.e. automatically adding the host/port to the `known_hosts` file)

### Restoring modification times

:warning: Read this section if `lftp-mirror-action` uploads _all_ files every time it runs.

Git does not preserve the original modification time of committed files.
When repositories are cloned, branches are checked out, etc., the modification time
of the files is updated to the current time. This means that the modification time
of the files on the GitHub runner will always be newer than the files on the SFTP server,
which will result in the `mirror` command always uploading all files (since `lftp` determines
whether a file has changed based on its file size and timestamp).

To prevent this, if `onlyNewer` is set to `true`, we restore the modification time of the files
based on the date of the most recent commit that modified them. You can disable this behavior
by setting `restoreMTime` to `false` (useful if you've already run an action like
[`git-restore-mtime-action`](https://github.com/chetan/git-restore-mtime-action)
in your GitHub Actions workflow).

If you're using [`actions/checkout`](https://github.com/actions/checkout) ≥ `v2` you _must_ set
`fetch-depth` to `0` in order to fetch the entire Git history.

## Bugs & Features

If you've spotted any bugs, or would like to request additional features from this
GitHub Action, please [open an issue](https://github.com/pressidium/lftp-mirror-action/issues).

## License

The MIT License, check the `LICENSE` file.
