# quorum
A image to run [Quorum](https://github.com/jpmorganchase/quorum) and [Constellation](https://github.com/jpmorganchase/constellation), with _raft consensus_ enabled.

Based on [Quorum Example](https://github.com/jpmorganchase/quorum-examples) install script ([bootstrap.sh](https://github.com/jpmorganchase/quorum-examples/blob/master/vagrant/bootstrap.sh)).

In addition, it is necessary to use [Supervisor](http://supervisord.org/index.html) to allow multiples services inside container.


# hands-on

Just run a container to execute both **Quorum** and **Constellation**:

```bash
docker run bortes/quorum
```

Otherwise specify _geth_ or _constellation-node_ to execute just **Quorum** or **Constellation**, respectively:

```bash
docker run bortes/quorum geth
```


# next steps
Reduce image size by change docker base image from [Linux Ubuntu](https://hub.docker.com/_/ubuntu/) to [Linux Alpine](https://hub.docker.com/_/alpine/).

At this moment this is not possible because we can't compile Haskell at Alpine as discute in issue [#2387](https://github.com/commercialhaskell/stack/issues/2387).


# more info

[Run multiple services in a container](https://docs.docker.com/config/containers/multi-service_container/).

[Running Quorum](https://github.com/jpmorganchase/quorum/blob/master/docs/running.md).

[Connecting to the network](https://github.com/ethereum/go-ethereum/wiki/Connecting-to-the-network).

[Raft-based consensus for Ethereum/Quorum](https://github.com/jpmorganchase/quorum/blob/master/raft/doc.md).
