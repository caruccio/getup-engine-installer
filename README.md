# Getup Engine Installer

This project holds scripts and tools for Getup Engine cluster installer.

The installer runs inside a docker contrainer, built for a specific version.
Supported versions are based on [Openshift Origin](https://github.com/openshift/origin) releases:

- v3.6
- v3.7
- v3.9

The full install process comprises the following steps:

1. [Preparing the environment](#1-preparing-the-environment)
    - [Generate installer container images](#generate-installer-container-images)
    - [Create cluster config](#create-cluster-config)
    - [Copy Getup Engine private keys](#copy-getup-engine-private-keys)
    - [Start installer container](#start-installer-container)


2. [Deploying the infrastructure](#2-deploying-the-infrastructure)
    - [Create Base Image](#create-base-image-packer-or-terraform) (packer or terraform)
    - [SSL certificates](#ssl-certificates) (optional)
    - [Create the infrastructure](#create-the-infrastructure-terraform) (terraform)


3. [Installing the cluster](#3-installing-the-cluster)
    - [Install and provision the cluster](#install-the-cluster-ansible) (ansible)


4. [Upgrade the cluster](#4-upgrade-the-cluster-ansible) (ansible)
    - [Control plain](#control-plan)
    - [Application nodes](#application-nodes)

## 1. Preparing the environment

### Generate installer container images

Run the command `./build-all` to create all available versions of the installer:

```
$ ./build-all
```

The build runs in parallel. Each different version uses an specific color in terminal.

When finished, the images will be generated as `getup-engine:[version]`:

```
$ docker images | grep getup-engine
getup-engine                         v3.9                3cecca9ab451        17 minutes ago      2.3 GB
getup-engine                         latest              3cecca9ab451        17 minutes ago      2.3 GB
getup-engine                         v3.7                c9b776eff6e0        17 minutes ago      1.92 GB
getup-engine                         v3.6                98c083fbcb9e        17 minutes ago      1.91 GB

```

Alternativelly, to generate only the version `v3.7`, use:

```
$ ./build v3.7
```

### Create cluster config

All information about a cluster is stored inside the so-called `state dir` (var $STATE_DIR inside the scripts).
This dir is responsible for holding any non-volatile bit of information about the cluster. By default, the dir
`state/[cluster-name]` is assumed, but you can specify somewhere else to be the state dir.

First, create the folder to store the cluster state files (config, certificates, ssh keys, terraform.tfstate, etc).

```
$ export CLUSTER_NAME=mateus
$ mkdir -p state/$CLUSTER_NAME
```

It's a good practice to create the folder with the same name of the cluster. Prefer short and simple names (i.e. [a-z0-9]).
This folder should persist during cluster lifecycle.

Use the script `bin/gen-config [cluster-name]` to create the configuration file used as input by the installer.
This will create the file `./state/$CLUSTER_NAME/getupengine.env`. The installer expects to find it there.

```
$ bin/gen-config $CLUSTER_NAME
```
**Note the name of the cluster is `mateus`, which is also the name of the directory for the state dir.**

To use another state dir, provide a valid full path:

```
$ bin/gen-config /another/state-dir/$CLUSTER_NAME
```

> You can cancel the script at any moment with `^C`. The next execution reuses most of the values.
> Each execution generates a backup file `getupengine.env.[timestamp].bkp`
> based in `getupengine.env` current values.

Create a new pair of SSH keys to be used to access the hosts.
**The ssh key should not have a passphrase.**

```
$ ssh-keygen -f state/$CLUSTER_NAME/id_rsa
```

Alternativelly, you can use your own local key:

```
$ cp ~/.ssh/id_rsa state/$CLUSTER_NAME/
```

> Make sure this key is added to the provider.
> This is required for AWS and GCE.

For AWS, upload the key you created in the previous step like so:
```
aws ec2 import-key-pair --key-name default --public-key-material file://./state/$CLUSTER_NAME/id_rsa.pub
```

> On Azure, the keys are loaded during host instantiation.

### Copy Getup Engine private keys

In order to install getup-api and getup-billing, you must copy both keys to the installer state dir.
Those keys are provider to you when you purchase the product. If you don't have one, please contact sales@getupcloud.com

```
$ cp /path/for/getup-api-id_rsa state/$CLUSTER_NAME/getup-api-id_rsa
$ cp /path/for/getup-billing-id_rsa state/$CLUSTER_NAME/getup-billing-id_rsa
```

### Start installer container

Start the installer container with command `./run [cluster-name] [version] <docker-run-parameters...>`.

```
$ ./run $CLUSTER_NAME v3.9
```

> Tip: You can add the parameters `-d` to execute the container as a daemon. That way, it's possible to
> close the current session and go back later. To enter the container again, use the command
> `./enter [cluster-name]`.

Inside the container, the terminal prompt will looks like this:

```
[mateus @ 3.9.0] 05/23/18 21:07:08 /getup-engine $
 ^^^^^^   ^^^^^  ^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^
   |       |             |              |
   |       |             +-- date/hour  +-- $PWD
   |       +-- target version to install/update
   +-- cluster name
```

A new container named `getup-engine-[cluster-name]` is created on the host (your local host). You can check it with:

```
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
61545a414aee        getup-engine:v3.9   "/getup-engine/bin..."   14 minutes ago      Up 14 minutes                           getup-engine-mateus
```

## 2. Deploying the infrastructure

### Create Base Image (packer or terraform)

First we need to generate the base images. This must be done only once, or when there is a critical update in the CentOS image provided
by the underlying IaaS.

Execute the command `/getup-engine/images/deploy` and wait it finishes.

> It may be required for you to explicitly accept usage terms like EULA in order to start CentOS instances.
> If that is the case, read the error message and follow the instructions.

### SSL Certificates

The cluster serves public certificates to clients reaching its domains (cluster and apps) using wildcard certificates for each zone.

You can provide your own certificates or generate free certificates from Let's Encrypt.

#### Provide own certificates

For each zone (cluster and apps), place the certificates in $CERTS_DIR as follow:

- Certificate: $CERTS_DIR/${zone}.crt
- Certificate Key: $CERTS_DIR/${zone}.key
- CA Certificate: $CERTS_DIR/ca-${zone}.crt

For example, if your `Cluster zone` is `bussiness.com` and your `Apps zone` is `bussinessapps.io`, the files should be:

- $CERTS_DIR/bussiness.com.crt
- $CERTS_DIR/bussiness.com.key
- $CERTS_DIR/ca-bussiness.com.crt
- $CERTS_DIR/bussinessapps.io.crt
- $CERTS_DIR/bussinessapps.io.key
- $CERTS_DIR/ca-bussinessapps.io.crt

#### Lets Encrypt SSL certificates (optional)

In order to generate Lets Encrypt certificates, execute the command `gen-certificates`.

All required files will be created in the right place.

Please keep in mind these certificates last on for 3 months. It's on you to renew the certificates and update the
cluster before they expire. A self-renew version of this installer is comming soon.

### Create the infrastructure (terraform)

Create ths underlying IaaS infrastructure to install the cluster onto.

Execute the script `/getup-engine/terraform/deploy` and confirm. Use the flag `--yes` to avoid asking for confirmation.

At this point any infra requirement should be provisioned. From networking to computing instances.

Both zones will be created and populated as necessary. The following dns entries should be created:

**Cluster zone**

- api.${cluster_zone}: openshift/kubernetes api
- gapi.${cluster_zone}: getupcloud api
- portal.${cluster_zone}: getupcloud portal

**Apps zone**

- *.${apps_zone}: points to apps ELB
- infra.${apps_zone}: friendly CNAME to apps zone

## 3. Installing the cluster

This step will install any software components of the cluster.

### Install the cluster (ansible)

Execute the script `/getup-engine/ansible/deploy` to install the cluster.

The default behavior is to install the cluster, but different `stages` can be
used for specific tasks:

- pre: pre-install tasks, like preparing nodes and copy basic files.
- install: the main openshift ansible installer (default).
- post: post-install tasks, like config updates and cleanups.
- getup: deploys getupcloud stack, like billing, monitoring, backup and the web console.
- gen-hosts: generates ansible hosts file and exit.
- playbook: executes an user-specified playbook.
- uninstall: removes the cluster, keeps the infrastructure.
- upgrade-control-plane & upgrade-nodes: rolling upgrade the cluster version

To run an specific stage:

```
$ ansible/deploy stage=<name> [ansible-options...]
```

## 4. Upgrade the cluster (ansible)

Automatic upgrades can be made between versions, but never skip a version. Example: v3.6 -> V3.7` then `v3.7 -> v3.9` is
ok, but `v3.6 -> v3.9` is not possible.

Start the installer container the same way as described in step 1 above, using the image version you want to upgrate to.
For example, if the cluster was created in version `v3.7`, execute the following command to upgrade to `v3.9`:

```
$ ./run $CLUSTER_NAME v3.9
```

The upgrade is done in two steps:

### Control plan

During the upgrade, nodes and masters will be unavailable.

> If possible, enable firewall at port 443 in order to __block external access to the **Cluster API**__.
> **The nodes of the cluster still need access to the cluster API**.
> Please note the apps routers (infra nodes) do not need to be blocked.
> After upgrade completes, disable the firewall to give access to users on the cluster API again.

Start the control plane upgrade:

```
$ /getup-engine/ansible/deploy stage=upgrade-control-plane
```

You can watch nodes being upgraded from another terminal:

```
$ ./enter $CLUSTER_NAME ssh master watch oc get nodes
```

### Application nodes

After upgrading control plane, it's time to upgrade the application nodes.
This is a rolling operation, meaning each app node will be marked as
unschedulable, drained, upgraded and marked as schedulable again.

Start the applicatoin nodes upgrade:

```
$ /getup-engine/ansible/deploy stage=upgrade-nodes
```

> Tip: after upgrading, the pods of the cluster may be unbalanced. You can use
> [descheduler](https://github.com/kubernetes-incubator/descheduler) in order to
> redistribute the pods evenly among the nodes.

## Tools reference

The commands below must run **outside** the installer container:

```
[build, build-all] Create docker images of the installer
  Input: installer version or none
  Output: docker images

[run] Start the container
  Input: installer name and version
  Output: N/A

[enter]
  Input: cluster-name or none for cluster-name list (running containers only)
  Output: N/A
```

The commands below must run **inside** the installer container:

```
[bin/run-on] Run commands on cluster hosts using ansible `shell` module
  Input: ansible hosts and command
  Output: N/A

[bin/gen-config] Create getupengine.env
  Input: cluster config from operator
  Output: /state/[cluster-name]/getupengine.env

[images/deploy] Create base images
  Input: /state/getupengine.env
  Output: provider specific images

[terraform/deploy] Create provider specific infrastructure
  Input: /state/getupengine.env
  Outputs: /state/terraform.tfstate

[ansible/deploy] Install the cluster
  Input: /state/terraform.tfstate
  Outputs: /state/hosts

[bin/gen-certificates] Generate Lets Encrypt certificates
  Input: /state/getupengine.env
  Output: certificates on $CERTS_DIR/
