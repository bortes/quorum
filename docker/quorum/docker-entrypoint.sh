#!/bin/bash

# finaliza o script quando ocorrer algum erro
set -e

# ip do container necessario para exposicao do nos
my_ip=$( hostname --ip-address )

# caminho completo para o repositorio dos dados dos nos
nodes_var=/var/opt/nodes

# nome no servico que response pelo quorum
quorum_service_name=quorum

# caminho completo para o repositorio dos dados do quorum
quorum_var=/var/opt/quorum

# caminho completo para o repositorio das configuracoes do quorum
quorum_etc=/etc/opt/quorum

# caminho completo para o arquivo que define o bloco genesis
genesis_path="$quorum_etc/genesis.json"

# caminho completo para a chave privada
quorum_prv_key_path="$quorum_var/prv.key"

# caminho completo para a chave publica
quorum_pub_key_path="$quorum_var/pub.key"

# caminho completo para o socket de comunicacao interna
quorum_socket_path="$quorum_var/quorum.ipc"

# caminho completo para a lista de nos que fazem parte da rede privada - podem se conectar uns com os outros
static_node_path="$quorum_var/static-nodes.json"

# caminho completo para a lista de nos que podem transacionar entre si
permissioned_node_path="$quorum_var/permissioned-nodes.json"

# nome no servico que response pelo constellation
constellation_service_name=quorum

# caminho completo para o repositorio dos dados do constellation
constellation_var=/var/opt/constellation

# caminho completo para o repositorio das configuracoes do constellation
constellation_etc=/etc/opt/constellation

# caminho completo para a chave privada
constellation_prv_key_path="$constellation_var/prv.key"

# caminho completo para a chave publica
constellation_pub_key_path="$constellation_var/pub.key"

# caminho completo para o socket de comunicacao interna
constellation_socket_path="$constellation_var/constellation.ipc"

# caminho completo para o repositorio dos dados do supervisor
supervisor_var=/var/run/supervisor

# caminho completo para a configuracao do supervisord
supervisor_config_path="$supervisor_var/supervisor.conf"

echo "CONTAINER IP $my_ip"
echo

# gera as chaves Enclave do no - para (des)critografia das transacoes privadas realizadas pelo no
constellation_generate_keys()
{

    # verifica se sera necessario criar as chaves publicas e privadas utilizadas pelo no
    if [ ! -f "$constellation_prv_key_path" ]
    then

        # notificao comando executado
        echo "CONSTELLATION KEYS"
        echo "  constellation-node --workdir=$constellation_var --generatekeys=prv"
        echo

        # cria as chaves publicas e privadas
        constellation-node --workdir=$constellation_var --generatekeys=prv

        # ajusta o nome das chaves para o padrao esperado
        mv $constellation_var/prv.pub $constellation_pub_key_path

        echo
        echo

    fi

}

# inicializa bloco genesis do no
quorum_generate_genesis()
{

    # verifica se foi mapeado o arquivo que define o bloco genesis
    if [ -f "$genesis_path" ]
    then

        # notificao comando executado
        echo "QUORUM GENESIS"
        echo "  geth --datadir $quorum_var init $genesis_path"
        echo

        # inicializa o bloco genesis
        geth --datadir "$quorum_var" init "$genesis_path"

        echo

    fi

}

# gera as chaves P2P do no
quorum_generate_keys()
{

    # verifica se sera necessario criar as chaves publicas e privadas utilizadas pelo no
    if [ ! -f "$quorum_prv_key_path" ]
    then

        # notificao comando executado
        echo "QUORUM KEYS"
        echo "  bootnode -genkey=$quorum_prv_key_path"
        echo

        # cria chave privada
        bootnode -genkey=$quorum_prv_key_path

        # cria chave publica
        bootnode -nodekey=$quorum_prv_key_path -writeaddress > $quorum_pub_key_path

        # URL para acesso ao no
        enode=$( quorum_generate_node_scheme )

        # persiste a URL de acesso para compartilhar com os demais nos da rede
        mkdir -p "$nodes_var/$my_ip"
        echo "$enode" > "$nodes_var/$my_ip/enode"

    fi

}

# gera a lista de nos estaticos que compoem a rede privada
quorum_generate_static_nodes()
{

    # verifica se sera necessario criar a lista de nos que fazem parte da rede privada
    if [ ! -f "$quorum_etc/static-nodes.json" ]
    then

        # URL para acesso ao no
        enode=$( quorum_generate_node_scheme )

        # notificao comando executado
        echo "QUORUM STATIC NODE"
        echo "  $enode"
        echo

        # intera sobre a lista de nos registrados
        for node in $nodes_var/**/*
        do

            # obtem a URL para acesso ao no
            enode=$(cat $node)

            # consiste lista de nos nao inicializada
            if [ -z "$quorum_nodes_list" ]
            then

                quorum_nodes_list="    \"$enode\""

            else

                quorum_nodes_list="$quorum_nodes_list,
    \"$enode\""

            fi

        done

        # gera relacao de nos que se conectam com este no
        echo "[
$quorum_nodes_list
]" > $static_node_path

    fi

}

# gera a lista de nos que possuem permissao para transacionar com este no da rede privada
quorum_generate_permissioned_nodes()
{

    # verifica se sera necessario criar a lista de nos que fazem parte da rede privada
    if [ ! -f "$quorum_etc/permissioned-nodes.json" ]
    then

        # gera relacao de nos que se transacionam com este no
        cp $static_node_path $permissioned_node_path

    fi

}

# gera a URL para acesso ao no no formato enode - https://github.com/ethereum/wiki/wiki/enode-url-format
quorum_generate_node_scheme()
{

    # obtem a chave publica
    pub_key="$( cat $quorum_pub_key_path )"

    # gera chave de acesso no formato ENODE para comunicacao com outros nos
    enode="enode://$pub_key@$my_ip:30303?discport=30303&raftport=50400"

    echo "$enode"

}

# gera o comando utilizado para executar o quorum
quorum_generate_command()
{

    # GETH
    #   https://github.com/ethereum/go-ethereum/wiki/command-line-options
    #   https://github.com/jpmorganchase/quorum/blob/master/cmd/utils/flags.go

    # ACCOUNT FLAGS
    # --unlock 0               = define a lista de contas para serem desbloqueadas - contas separadas por virgula
    #                              https://github.com/ethereum/go-ethereum/wiki/Managing-your-accounts#non-interactive-use
    set -- "$@" --unlock 0

    # GENERAL FLAGS
    # --datadir                = define o diretorio para armazenamento dos dados do no
    # --nodiscover             = desativa o mecanismo de discoberta de outros nos
    # --password passwords.txt = define arquivo contendo a senha da conta
    #
    set -- "$@" --datadir "$quorum_var" --nodiscover

    # NETWORK FLAGS
    # --bootnodes              = define a lista de nos utilizados para conexao P2P durante a inicializacao deste no - modo "discovery"
    # --nodekey                = define o arquivo com a chave privada utilizada na conexao P2P
    # --port 21000             = define a porta utilizada para comunicacao com outros nos da rede (padrao: 30303)
    #
    set -- "$@" --nodekey "$quorum_var/prv.key" --port 30303

    # RPC FLAGS
    # --ipcpath                = nome do arquivo socket utilizado para comunicacao via IPC
    # --rpc                    = ativa o servidor de HTTP-RPC
    # --rpcaddr 0.0.0.0        = define as interfaces nas quais o servidor de HTTP-RPC ira aceita conexao (padrao: localhost)
    # --rpcapi                 = define as interfaces disponiveis no servidor HTTP-RPC
    #                              https://github.com/ethereum/go-ethereum/wiki/management-apis
    #     admin                = ativa API para administracao do no
    #                              https://github.com/ethereum/go-ethereum/wiki/management-apis#admin
    #     db                   = ativa API para manipuacao do banco de dados
    #                              https://github.com/ethereum/wiki/wiki/json-rpc#json-rpc-methods
    #     eth                  = ativa API para manipuacao de ETH
    #                              https://github.com/ethereum/wiki/wiki/json-rpc#json-rpc-methods
    #     debug                = ativa API para debug em tempo de execucao
    #                              https://github.com/ethereum/go-ethereum/wiki/management-apis#debug
    #     miner                = ativa API para mineracao
    #                              https://github.com/ethereum/go-ethereum/wiki/management-apis#miner
    #     net                  = ativa API para gestao da rede
    #                              https://github.com/ethereum/wiki/wiki/json-rpc#json-rpc-methods
    #     shh                  = ativa API para utilizacao do protocolo whisper para troca de mensagens entre usuarios dentro da mesma rede
    #                              https://github.com/ethereum/wiki/wiki/json-rpc#json-rpc-methods
    #                              https://github.com/ethereum/wiki/wiki/Whisper
    #     txpool               = ativa API para inspecao das transacoes pendentes
    #                              https://github.com/ethereum/go-ethereum/wiki/management-apis#txpool
    #     personal             = ativa API para gestao das chaves privadas
    #                              https://github.com/ethereum/go-ethereum/wiki/management-apis#personal
    #     web3                 = ativa API para manipulacao do Ethereum via JS
    #                              https://github.com/ethereum/wiki/wiki/json-rpc#json-rpc-methods
    #     quorum               = ativa API para manipulacao do Quorum via JS
    #                              https://github.com/web3j/quorum
    # --rpccorsdomain "*"      = define os dominios que podem acessar o servidor HTTP-RPC
    #                              https://github.com/ethereum/go-ethereum/blob/master/README.md#programatically-interfacing-geth-nodes
    # --rpcport 22000          = define a porta utilizada para servidor de HTTP-RPC (padrao: 8545)
    #                          =   https://github.com/jpmorganchase/quorum/wiki/using-quorum#setting-up-a-permissioned-network
    #
    set -- "$@" --ipcpath "$quorum_socket_path" --rpc --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum --rpcport 8545

    # RAFT FLAGS
    # --emitcheckpoints        = ativa a emissao de pontos de verificacao formatados
    # --raft                   = ativa o consenso RAFT (padrao: quorum chain)
    # --raftport 50401         = define a porta utilizada para o consenso RAFT (padrao: 50400)
    #
    set -- "$@" --emitcheckpoints --raft --raftport 50400

    # QUORUM FLAGS
    # --permissioned           = define a lista de nos que podem se conectar neste no para compor uma rede privada

    # WHISPER FLAGS
    # --shh                    = ativa o protocolo Whisper
    # set -- --shh "$@"

    # inicializa o geth com os parametros informados
    set -- geth "$@"

    # retorna o comando
    echo "$@"

}

# gera o comando utilizado para executar o constellation
constellation_generate_command()
{

    # define o protocolo de acesso ao constellation
    constellation_protocol=https

    # recupera todos os IP associados ao servico
    for ip in $(dig +noall +answer "${constellation_service_name:-0}" | awk '{print $5}')
    do

        node=$constellation_protocol://$ip:9001/

        # consiste lista de nos nao inicializada
        if [ -z "$constellation_nodes_list" ]
        then

            constellation_nodes_list="$node"

        else

            constellation_nodes_list="$constellation_nodes_list,$node"

        fi

    done

    # consiste lista de nos nao inicializada
    if [ -z "$constellation_nodes_list" ]
    then

        constellation_nodes_list=$constellation_protocol://$my_ip:9001/

    fi

    # CONSTELLATION
    #   https://github.com/jpmorganchase/constellation/blob/master/sample.conf

    # GENERAL FLAGS
    # --workdir=$DDIR                      define o diretorio para armazenamento dos dados do no (padrao: o diretorio atual)
    #
    set -- "$@" --workdir="$constellation_var"

    # NETWORK FLAGS
    # --port=9001                          define a porta utilizada acesso a API publica do no (padrao: 9001)
    # --url=https://127.0.0.1:9001/        define a URL para o acesso externo a API publica do no (padrao: http://127.0.0.1:9001/)
    # --othernodes=https://127.0.0.1:9001/ define a lista dos nos da rede - lista inicial, nao precisa possuir todos os nos da rede
    #
    set -- "$@" --port=9001 --url=$constellation_protocol://$my_ip:9001/ --othernodes=$constellation_nodes_list

    # TRANSACTION MANAGER FLAGS
    # --publickeys=tm.pub                  define a lista de chaves publicas utilizadas para ler as transacoes privadas
    # --privatekeys=tm.key                 define a lista de chaves privadas correspondentes as chaves publics utilizadas para assinar as transacoes privadas
    # --socket=tm.ipc                      define o arquivo soquete utilizado para acesso a API privada
    #
    set -- "$@" --publickeys="$constellation_var/pub.key" --privatekeys="$constellation_var/prv.key" --socket="$constellation_socket_path"

    # TRANSPORT LAYER SECURITY
    #
    # --tls=off                            define o modo autenticacao TLS utilizados pelas conexoes de entrada e saida do no (padrao: strict)
    #set -- "$@" --tls=off

    # inicializa o constellation com os parametros informados
    set -- constellation-node "$@"

    # retorna o comando
    echo "$@"

}

# verifica se nenhum parametro foi informado - neste caso sera executado o supervisorctl
if [[ -z "$1" ]]
then

    # declarado apenas os servicos que serao executados para correta comparacao
    run_constellation=1
    run_geth=1
    run_supervisor=1

fi

# verifica se foi solicitado a execucao do geth - neste caso sera executado com a configuracao padrao para o geth
if [[ "$@" = "geth" ]]
then

    # declarado apenas os servicos que serao executados para correta comparacao
    # run_constellation=0
    run_geth=1
    # run_supervisor=0

fi

# verifica se foi solicitado a execucao do constellation - neste caso sera executado com a configuracao padrao para o constellation
if [[ "$@" = "constellation-node" ]]
then

    # declarado apenas os servicos que serao executados para correta comparacao
    run_constellation=1
    # run_geth=0
    # run_supervisor=0

fi

# tratamento para execucao do constellation
if [[ "$run_constellation" ]]
then

    constellation_generate_keys
    sleep 1

fi

# tratamento para execucao do geth
if [[ "$run_geth" ]]
then

    quorum_generate_keys
    sleep 5

    quorum_generate_static_nodes
    sleep 3

    quorum_generate_permissioned_nodes
    sleep 1

    quorum_generate_genesis
    sleep 1

fi

# tratamento para execucao do supervisor
if [[ "$run_supervisor" ]]
then

    # verifica se sera necessario criar o arquivo de configuracao do supervisor
    if [ ! -f "$supervisor_config_path" ]
    then

        # criar arquivo de configuracao - http://supervisord.org/configuration.html
        cat > $supervisor_config_path << EOF
[program:controller]
command=/usr/local/bin/controller.sh $supervisor_config_path $constellation_socket_path

[program:constellation]
autorestart=false
autostart=false
command=$( constellation_generate_command )
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0

[program:quorum]
autorestart=false
autostart=false
command=$( quorum_generate_command )
environment=PRIVATE_CONFIG=$constellation_socket_path
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0

[rpcinterface:supervisor]
supervisor.rpcinterface_factory=supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor/supervisor.sock

[supervisord]
directory=/var/run/supervisor
logfile=$supervisor_var/supervisord.log
nodaemon=true
pidfile=$supervisor_var/supervisord.pid
user=quorum

[unix_http_server]
chmod=0700
file=/var/run/supervisor/supervisor.sock
EOF

    fi

    set -- supervisord --configuration "$supervisor_config_path"

# tratamento para execucao do constellation
elif [[ "$run_constellation" ]]
then

    set -- $( constellation_generate_command )

# tratamento para execucao do geth
elif [[ "$run_geth" ]]
then

    set -- $( quorum_generate_command )

fi

# notificao comando executado
echo "EXEC"
echo "  $@"
echo

# executa o comando
exec "$@"
