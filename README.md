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

# Configs
currently configs are stored in `.env` and `docker-compose.yaml` files.

The ENV vars stored in `.env` file has precedence over the same 
vars defined in the `docker-compose.yaml`.

## `.env` file
**Note:** `.env` keeps the ENV vars that are common amongst all containers.

```bash
CHAIN_ID=arch-1
DENOM=stake
TOTAL_NODES=3
MAIN_NODE_HOME=/root/main_node_home
```
* `CHAIN_ID` and `DENOM` are clear. 
* `TOTAL_NODES` indicates how many nodes we are running. This is an important parameter to set. Because if it does not correspond to the actual number of running nodes, all nodes might be waiting forever or misbehave.
* `MAIN_NODE_HOME` refers to the home directory (_e.g._ `~/.archway`) of the initial node which is the node with `NODE_SEQ=1`


## `docker-compose.yaml` file

### Ports
```yaml
ports:
    - 9093:9090
    - 20003:26657
```
This configures the forwarding ports of each node

### ENV vars

```yaml
P2P_PORT: "20003"
CHAIN_ID: ${CHAIN_ID:-my-chain}
DENOM: ${DENOM:-uarch}
ACCOUNT_FUND: 10000000000000
VALIDATOR_FUND: 1000000000
HOME_DIR: "/root/.archway"
MONIKER: "node3"
KEY_NAME: "key3"
NODE_SEQ: 3
TOTAL_NODES: ${TOTAL_NODES:-4}
MAIN_NODE_HOME: ${MAIN_NODE_HOME:-/root/main_node_home}
```

* `P2P_PORT` has to be the same port number that we defined in the ports section of this node
* `CHAIN_ID` this is read by default from `.env` file. `my-chain` applies if the `.env` file is not accessible or the ENV var is not present there.
* `DENOM` same as the `CHAIN_ID` it is read from `.env` file.
* `ACCOUNT_FUND` is the amount of tokens that will be funded initially in the validator account
* `VALIDATOR_FUND` is the initial delegation (self bonded) of the validator that will be deducted from `ACCOUNT_FUND`
* `HOME_DIR` is the home directory path withing the container
* `MONIKER` denotes the moniker for this node
* `KEY_NAME` is the key name for the validator account
* `NODE_SEQ` is the node sequence in the list of nodes. This has to be a positive integer starting from 1
* `TOTAL_NODES` determines the total number of nodes. Tis is read from `.env` file and it is a very important parameter for node sync.
* `MAIN_NODE_HOME` refers to the home directory (_e.g._ `~/.archway`) of the initial node which is the node with `NODE_SEQ=1` which is mapped to a different directory within the current node.

### Volumes

```yaml    
- ./start.sh:/root/start.sh:z
- ./node3/home:/root/.archway:z
- ./node3/contracts:/contracts:z
- ./node1/home:/root/main_node_home:z
```

* `./start.sh:/root/start.sh`: maps the start bash script to each container. Each node joining at genesis runs this script.
* `./node3/home:/root/.archway`: maps the home directory of the node `#3` to the container. Please note that this has to be mapped to the exact path that indicated in `HOME_DIR` variable.
* `./node3/contracts:/contracts:z`: probably used to store wasm contracts
* `./node1/home:/root/main_node_home:z`: maps the first node's home directory _e.g._ `node1` to the container to a specific path that has to match the path defined in `MAIN_NODE_HOME` variable.


# How to add more nodes

Simply copy the last node and change the variables. For example change `node3` to `node4`