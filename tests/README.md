# Integration Test Databases

Start the databases and wait until they are healthy:

```sh
docker compose -f tests/docker-compose.yml up -d --wait
moon test
```

Stop the services after testing:

```sh
docker compose -f tests/docker-compose.yml down
```

Use `down -v` to also remove the test data volumes.
