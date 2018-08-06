# Datadir builder
A Google Cloud Build build of our mariddb datadirs.

**Currently a work in progress**

## Status
- The builder itself works, but is has to be triggered manually. A build can be performed by prepare a cloudbuild.yaml, eg:
```yaml
steps:
- name: 'eu.gcr.io/reloaddk-data/datadir-builder'
  args: ['eu.gcr.io/reloaddk-data/db-data:ddsdk-latest', 'eu.gcr.io/reloaddk-data/db-datadir:ddsdk-latest', 'standard-drupal8']
```

And execute it like so:
```bash
gcloud builds submit --no-source --config cloudbuild.yaml
```

The build can be parametrized:
```yaml
steps:
- name: 'eu.gcr.io/reloaddk-data/datadir-builder'
  args: ['eu.gcr.io/reloaddk-data/db-data:${_BASENAME}-latest', 'eu.gcr.io/reloaddk-data/db-datadir:${_BASENAME}-latest', '${_POST_IMPORT_SCRIPT}']
```

In which case you execute it like this:
```bash
gcloud builds submit \
  --no-source \
  --async \
  --config cloudbuild.yaml \
  --substitutions=_BASENAME="ddsdk",_POST_IMPORT_SCRIPT="standard-drupal8"
```

## TODO
- Consider how to support custom init sql-scripts (right now you have to go with our standard drupal7 / drupal8 reset.sql scripts). Maybe let the user pass in an url where we could fetch the sql from?
