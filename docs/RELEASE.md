## Automated

Run the release helper script:

```bash
bash scripts/release.sh
```

It walks through the steps below for each package, in publish order:

- `hive_io`
- `hive_generator_io`
- `hive_flutter_io`

For every package it reads the release version from `CHANGELOG.md` in the
format of a `### X.Y.Z` heading and uses it to update
`pubspec.yaml`, the `README.md` install versions, and the dependents'
`hive_io` constraint. It then runs `dart pub publish`. You can skip any package.

## Manual

Per package (`hive_io`, then `hive_generator_io` and `hive_flutter_io`):

- Update version in `pubspec.yaml`
- Update install version in `README.md`
- Update `CHANGELOG.md`
- Run `dart pub publish`

`hive_io` must be published first; the other two depend on it, so bump their
`hive_io:` constraint and wait for `hive_io` to appear on pub.dev before
publishing them.
