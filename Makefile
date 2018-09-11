guard-datadir-%:
	@ if [ "${${*}}" = "" ]; then \
        echo "'$*' is missing"; \
		echo "Syntax: make source=sourceimage destination=destination init=<standard-drupal7|standard-drupal8> datadir"; \
        exit 1; \
    fi

build:
	docker build -t datadir-builder-local .

datadir: guard-datadir-source guard-datadir-destination guard-datadir-init build
	docker run \
	  --rm \
	  -v /var/run/docker.sock:/var/run/docker.sock \
	  datadir-builder-local ${source} ${destination} ${init}
	
	
