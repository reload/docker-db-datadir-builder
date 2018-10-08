# Datadir builder
A Google Cloud Build build of our MariaDB datadirs.

The datadir builder is triggered at the end of our db-dump worker runs via a helper.

You can also build datadirs locally.

## Local builds

### Using make
The easiest way to build datadirs locally is by using the `make datadir` target, run it like so (replacing the `db-data` and `db-datadir` tags with the appropriate ones):
```bash
source=eu.gcr.io/reloaddk-data/db-data:reloaddk-latest destination=eu.gcr.io/reloaddk-data/db-datadir:reloaddk-latest init=standard-drupal8 make datadir
```

*Notice:* You should have a local gcloud configured with access to pulling the required images.

### Using Cloud Build locally
To test the cloud build using Google Cloud SDK locally, you can use a tool called `cloud-build-local`. [Read how to install here](https://cloud.google.com/cloud-build/docs/build-debug-locally#install_the_local_builder)).

Run the local builder like so (replace the `_BASENAME` value with the appropriate project name):
```bash
cloud-build-local \
  --no-source \
  --dryrun=false \
  --config cloudbuild-local-trigger.yaml \
  --substitutions=_BASENAME="ddsdk",_POST_IMPORT_SCRIPT="standard-drupal8"
```

### Checking results
After a successful run you should now have a working datadir image in your local image cache. Run `docker images` to check.

## Cloud builds
You can trigger an **actual** cloud build of a datadir like so (replace the `_BASENAME` value with the appropriate project name):
```bash
gcloud --project=reloaddk-data builds submit \
  --no-source \
  --async \
  --timeout "60m" \
  --config cloudbuild-local-trigger.yaml \
  --substitutions=_BASENAME="ddsdk",_POST_IMPORT_SCRIPT="standard-drupal8"
```
See [gcr.reload.dk/your-reloaddk-username](http://gcr.reload.dk/) for a list of current source images.

After the build you should be able to see the datadir image in GCR [here](https://console.cloud.google.com/gcr/images/reloaddk-data/EU/db-datadir?project=reloaddk-data).

## TODO
- Consider how to support custom init sql-scripts (right now you have to go with our standard drupal7 / drupal8 reset.sql scripts). Maybe let the user pass in an url where we could fetch the sql from?
