#!/bin/bash

mkdir -p "${MAIN_NODE_HOME}/shared"

if [ -f "${HOME_DIR}/config/genesis.json" ]; then
    echo "Genesis file already exist"
else

    archwayd init ${MONIKER} --chain-id ${CHAIN_ID} --home ${HOME_DIR}

    echo -e "12345678\n12345678" | archwayd keys add ${KEY_NAME} --home ${HOME_DIR}

    #------------------------#

    # Let's wait for the main node's genesis init
    # We share the genesis file amongst all nodes to add their accounts to
    if [ "${NODE_SEQ}" != "1" ]; then
        while : ; do
            echo "Waiting for main node init..."
            if [ -f "${MAIN_NODE_HOME}/config/genesis.json" ]; then
                sleep 1
                break
            fi
            sleep 0.5
        done
        echo "Done"
    fi

    # Get the exclusive lock on the genesis
    # Not perfect but yeah :D
    while : ; do
        echo "Waiting for acquiring lock on genesis.json..."
        if ! [ -f "${MAIN_NODE_HOME}/shared/genesis.lock" ]; then
            touch "${MAIN_NODE_HOME}/shared/genesis.lock"
            break
        fi
        sleep 0.5
    done
    echo "Done"

    # Copy the main genesis
    cp "${MAIN_NODE_HOME}/config/genesis.json" "${HOME_DIR}/config/genesis.json"

    archwayd add-genesis-account $(echo -e "12345678\n12345678" | archwayd keys show ${KEY_NAME} -a --home ${HOME_DIR}) ${ACCOUNT_FUND}${DENOM} --home ${HOME_DIR}

    echo -e "12345678\n12345678" | archwayd gentx ${KEY_NAME} ${VALIDATOR_FUND}${DENOM} \
        --commission-rate 0.1 \
        --commission-max-rate 0.1 \
        --commission-max-change-rate 0.1 \
        --pubkey $(archwayd tendermint show-validator --home ${HOME_DIR}) \
        --chain-id ${CHAIN_ID}

    
    # Update the main genesis file
    cp "${HOME_DIR}/config/genesis.json" "${MAIN_NODE_HOME}/config/genesis.json"

    touch "${MAIN_NODE_HOME}/shared/${NODE_SEQ}.genesis_done"
    
    # Release the lock
    rm -f "${MAIN_NODE_HOME}/shared/genesis.lock"

    #------------------------#

    # Wait for all nodes to add their account to genesis
    while : ; do
        echo "Waiting for all genesis accounts..."
        TOTAL_GEN_DONE=0
        for i in $( seq 1 ${TOTAL_NODES} ); do
            if [ -f "${MAIN_NODE_HOME}/shared/${i}.genesis_done" ]; then
                ((TOTAL_GEN_DONE++))
            fi
            sleep 0.2
        done
        sleep 0.5
        if [ ${TOTAL_GEN_DONE} -ge ${TOTAL_NODES} ]; then
            break
        fi
    done
    echo "Done"
    
    # Get the updated genesis
    cp "${MAIN_NODE_HOME}/config/genesis.json" "${HOME_DIR}/config/genesis.json"

    #------------------------#

    # Let's wait for the main node's gentx 
    if [ "${NODE_SEQ}" != "1" ]; then
        
        while : ; do
            echo "Waiting for main node gentx directory..."
            if [ -d "${MAIN_NODE_HOME}/config/gentx" ]; then
                # Copy the gentx
                cp ${HOME_DIR}/config/gentx/gentx-*.json ${MAIN_NODE_HOME}/config/gentx/
                break
            fi
            sleep 0.5
        done
        echo "Done"
    fi

    touch "${MAIN_NODE_HOME}/shared/${NODE_SEQ}.gentx_done"
    
    # Wait for all gentxs to get ready
    while : ; do
        echo "Waiting for all gentx..."
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

    # Copy all gentx to my local dir
    cp ${MAIN_NODE_HOME}/config/gentx/gentx-*.json ${HOME_DIR}/config/gentx/

    archwayd collect-gentxs --home ${HOME_DIR}

    #------------------#

    PEER_ADDR=$(archwayd tendermint show-node-id)@$(hostname -i):${P2P_PORT}
    echo ${PEER_ADDR} > "${MAIN_NODE_HOME}/shared/${NODE_SEQ}.peer"

    #------------------#

fi

# Get the peers addresses 
ALL_PEERS=""
for i in $( seq 1 ${TOTAL_NODES} ); do
    # except myself
    if [ ${i} -ne ${NODE_SEQ} ]; then
        if [ -f "${MAIN_NODE_HOME}/shared/${i}.peer" ]; then
            ALL_PEERS=${ALL_PEERS}$(cat "${MAIN_NODE_HOME}/shared/${i}.peer"),
        fi
    fi
done

archwayd start --p2p.seeds ${ALL_PEERS}
