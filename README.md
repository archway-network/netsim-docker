# netsim-docker
This mini project simulates a network of multiple nodes joining at genesis


# How to start

```bash
git clone git@github.com:archway-network/netsim-docker.git
cd netsim-docker
docker-compose up -d
```

# How to reach to the nodes

to reach `node1` for example copy this command:

```bash
docker exec -it node1 sh
```

Then simply use `archwayd` commands of the node