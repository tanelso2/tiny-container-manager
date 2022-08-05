# Tiny Container Manager

tiny-container-manager (tcm for short, tiny-con-man for laughs) is my lightweight replacement for Kubernetes.

I was sure I could run all of my websites on one $5/month digital ocean machine, but the Kubernetes configurations were more expensive than that.

Also I just wanted to prove I could write something similar to Kubernetes.

It's.... similar.... if your glasses are fogged... but hey it works and is currently running my [personal website](https://thomasnelson.me)

# Development

## Building

```bash
    nimble build
```

## Running

```bash
    nimble run
```

# Future Work?

* `s3fs` to mount s3 buckets into a container
* mounts in general
* api for remote configuration, instead of relying on files
* automatic updates on the container images (probably related to the api)
