#!/bin/bash

if [ -f "${HOME_DIR}/config/genesis.json" ]; then
    echo "Genesis file already exist"
else

    archwayd init ${MONIKER} --chain-id ${CHAIN_ID} --home ${HOME_DIR}

    echo -e "12345678\n12345678" | archwayd keys add ${KEY_NAME} --home ${HOME_DIR}

    # Copy the main genesis
    cp "${MAIN_NODE_HOME}/config/genesis.json" "${HOME_DIR}/config/genesis.json"

    archwayd add-genesis-account $(echo -e "12345678\n12345678" | archwayd keys show ${KEY_NAME} -a --home ${HOME_DIR}) ${ACCOUNT_FUND}${DENOM} --home ${HOME_DIR}

    echo -e "12345678\n12345678" | archwayd gentx ${KEY_NAME} ${VALIDATOR_FUND}${DENOM} \
        --commission-rate 0.1 \
        --commission-max-rate 0.1 \
        --commission-max-change-rate 0.1 \
        --pubkey $(archwayd tendermint show-validator --home ${HOME_DIR}) \
        --chain-id ${CHAIN_ID}

    cp ${HOME_DIR}/config/gentx/gentx-*.json ${MAIN_NODE_HOME}/config/gentx/

    mkdir -p "${MAIN_NODE_HOME}/shared"
    touch "${MAIN_NODE_HOME}/shared/${NODE_SEQ}.gentx_done"
    
    PEER_ADDR=$(archwayd tendermint show-node-id)@$(hostname -i):${P2P_PORT}
    echo ${PEER_ADDR} > "${MAIN_NODE_HOME}/shared/${NODE_SEQ}.peer"

    # The first node is the main node that handles gentx collection
    if [ "${NODE_SEQ}" == "1" ]; then
        
        while : ; do
            echo "Waiting for other nodes to get their gentx done..."
            # Check if all nodes have their gentx prepared and copied
            TOTAL_GENTX_DONE=0
            for i in $( seq 1 ${TOTAL_NODES} ); do
                if [ -f "${MAIN_NODE_HOME}/shared/${i}.gentx_done" ]; then
                    ((TOTAL_GENTX_DONE++))
                fi
                sleep 0.2
            done
            sleep 0.5
            if [ ${TOTAL_GENTX_DONE} -ge ${TOTAL_NODES} ]; then
                break
            fi
        done
        echo "Done"

        archwayd collect-gentxs --home ${HOME_DIR}
        touch "${MAIN_NODE_HOME}/shared/genesis_done"
    fi

fi

# Let's wait for the genesis file to be prepared
while : ; do
    echo "Waiting for the main node to get the genesis done..."
    if [ -f "${MAIN_NODE_HOME}/shared/genesis_done" ]; then
        break
    fi
    sleep 0.5
done
echo "Done"

# Copy the genesis
cp "${MAIN_NODE_HOME}/config/genesis.json" "${HOME_DIR}/config/genesis.json"


# Get the peers addresses
ALL_PEERS=""
for i in $( seq 1 ${TOTAL_NODES} ); do
    if [ -f "${MAIN_NODE_HOME}/shared/${i}.peer" ]; then
        ALL_PEERS=${ALL_PEERS}$(cat "${MAIN_NODE_HOME}/shared/${i}.peer"),
    fi
done

archwayd start --p2p.seeds ${ALL_PEERS}
