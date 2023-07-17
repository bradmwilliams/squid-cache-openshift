# squid-cache-openshift

- [Introduction](#introduction)
- [Getting started](#getting-started)
  - [Warning](#warning)
  - [Building the image](#building-the-image)
    - [Podman](#podman)
    - [Make](#make)
- [Quickstart](#quickstart)
  - [Starting Squid Proxy](#starting-squid-proxy)
    - [Ephemeral cache](#ephemeral-cache)
    - [Persistent cache](#persistent-cache)
  - [Verify proxy is running](#verify-proxy-is-running)
    - [Curl](#curl)
    - [Cache info](#cache-info)
- [Openshift](#openshift)
	- [Contents](#contents)
	- [Deploy](#deploy)
- [References](#references)

# Introduction

I needed to replace a [Squid](http://www.squid-cache.org/) server, providing access to a private Jenkins environment, that was recently taken down.  Unfortunately, I wasn't involved with the initial setup/configuration of the environment and I had never dealt with Squid before.  I looked around for something that worked out-of-the-box, but had little success.  So, I dove in and this project is the result.  Hopefully, this it might save you some time if you're ever in a similar situation.

# Getting started

The root folder contains everything you need to create an image that is fully operational out-of-the-box.  In order to accomplish this, I modified a vanilla [squid.conf](squid.conf) file as follows:

  1.  Commented out the following line:
	  - http_access deny to_linklocal
  2.  Enabled caching by default
	  - cache_dir ufs /var/spool/squid 100 16 256
  3.  Specified an appropriate location for the PID file
	  - pid_filename /var/run/squid/squid.pid

## Warning
The default [squid.conf](squid.conf) file provided with this image should *NOT* be used in production as it provides little to no access control through the proxy and therefore can easily be exploited.

## Building the image

### Podman
```bash
$ podman build -t squid -f Dockerfile .
```

### Make
```bash
$ make image
```

# Quickstart

## Starting Squid proxy

### Ephemeral cache
```bash
$ podman run -it --rm -p 3128:3128 squid:latest
```

### Perisitent cache
```bash
$ podman run -it --rm -p 3128:3128 -v squid-cache:/var/spool/squid squid:latest
```

## Verifiy proxy is running
### Curl
```bash
$ curl -x localhost:3128 -L https://github.com/bradmwilliams/squid-cache-openshift
```

### Cache info
```bash
$ podman exec -it <continer> squidclient mgr:info
```

# Openshift
The [manifests](./manifests/) folder contains everything to create, configure, and launch the Squid image in OpenShift.

## Contents

  * [imagestream.yaml](./manifests/imagestream.yaml)
	  - Creates the **squid** imagestream
  * [bc.yaml](./manifests/bc.yaml)
	  - Creates the BuildConfig that produces the **squid:latest** imagestreamtag
  * [pvc.yaml](./manifests/pvc.yaml)
	  - Creates a 2GB volume for the persistent cache
  * [cm.yaml](./manifests/cm.yaml)
	  - This file contains a customizied *squid.conf* definition
		  + Squid service configuration
		    ```
		    http_port 3128
		    cache_dir ufs /var/spool/squid/cache 1500 16 256 
		    coredump_dir /var/spool/squid
		    pid_filename /var/run/squid/squid.pid
		    ```
		  + Allow inbound requests from the "internal" IP range of the cluster nodes
			```
			acl localnet src 172.16.0.0/12
			...
			http_access allow localnet
			```
          + Only allow requests for our specific domain
            ```
            acl jenkins dstdomain cr.ops.openshift.com
            ...
            http_access deny !jenkins
            http_access deny CONNECT !jenkins
            ```
          + Deny everything else
            ```
            http_access deny all
            ```
  * [deployment.yaml](./manifests/deployment.yaml)
	  - Creates the squid deployment
		  + Mounts the volumes
		    ```
            - name: squid-cache
		      persistentVolumeClaim:
	            claimName: squid-cache
	        - name: squid-config  
              configMap:
                name: squid-config
            - name: squid-logs
              emptyDir: {}
		    ```
		  + Specifies the corresponding environment variables
		    ```
            - name: SQUID_CONFIG_FILE
              value: /tmp/squid/squid.conf
            - name: SQUID_CACHE_DIR
              value: /var/spool/squid/cache
		    ``` 
		  + Creates 2 pods
		    1. squid
			    - The running server
		    2. access-log-watcher
			    - Tails the access.log

  * [service.yaml](./manifests/service.yaml)
	  - By default, squid uses a non-standard "web" port (`3128`) to communicate.  Therefore, the service must be configured as
	    ```
	    type: LoadBalancer
	    ```
        and rely on a specific `NodePort` to route traffic accordingly
        ```
        nodePort: 31280
        ```

  * [route.yaml](./manifests/route.yaml)

## Deploy
```bash
$ oc create -n <NAMESPACE> -f ./manifests 
```

# References
Pages that I found very helpful in getting this up and running
* [squid-cache.org](http://www.squid-cache.org/)
* [Adapting Docker and Kubernetes containers to run on Red Hat OpenShift Container Platform](https://developers.redhat.com/blog/2020/10/26/adapting-docker-and-kubernetes-containers-to-run-on-red-hat-openshift-container-platform#)
* [Openshift Docs: Creating Images](https://docs.openshift.com/container-platform/4.13/openshift_images/create-images.html)
* [boonkeato/openshift-squid](https://github.com/boonkeato/openshift-squid) * provided the basis for my Dockerfile and entrypoint.sh