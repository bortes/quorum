#!/bin/bash

# finaliza o script quando ocorrer algum erro
set -e

# caminho completo para a configuracao do supervisord
supervisor_config_path="$1"

# caminho completo para o socket de comunicacao interna
constellation_socket_path="$2"

# inicializa constellation via supervisor
supervisorctl --configuration "$supervisor_config_path" start constellation

# verifica se o no do constellation que sera utilizado por este no do quorum ja esta disponivel 
while true
do

    # notifica nova tentativa de conexao
    echo "Wait until Constellation is ready"
    sleep 3

    # verifice se o socket para conexao com constellation existe
    if [ -S "$constellation_socket_path" ]
    then

        break

    fi

done

# inicializa quorum via supervisor
supervisorctl --configuration "$supervisor_config_path" start quorum
