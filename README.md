# Datadir builder
A Google Cloud Build build of our mariddb datadirs.

The datadir builder is triggered at the end of our db-dump worker runs via a helper.

You can also build datadirs locally.

## Local builds - via make
The easiest way to build datadirs locally is by using the `make datadir` target, run it like so:
```
source=eu.gcr.io/reloaddk-data/db-data:reloaddk-latest destination=eu.gcr.io/reloaddk-data/db-datadir:reloaddk-latest init=standard-drupal8 make datadir
```

*Notice* You should have a local gcloud configured with access to pulling the required images.

After a successful run you should now have a working datadir image in your local image cache.

## Cloud builds
You can trigger a cloud build of at data dir like so:
```bash
gcloud --project=reloaddk-data builds submit \
  --no-source \
  --async \
  --config cloudbuild-local-trigger.yaml \
  --substitutions=_BASENAME="ddsdk",_POST_IMPORT_SCRIPT="standard-drupal8"
```
For building a datadir for the "ddsdk" projekt. See [gcr.reload.dk/your-reloaddk-username](http://gcr.reload.dk/) for a list of current source images.

## TODO
- Consider how to support custom init sql-scripts (right now you have to go with our standard drupal7 / drupal8 reset.sql scripts). Maybe let the user pass in an url where we could fetch the sql from?
