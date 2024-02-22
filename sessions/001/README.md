## Kafka Node Pools

> This feature is available as a preview.
> It is not enabled by default, so you must configure the feature gate before using it.

Node Pools represent different groups of Kafka nodes and are configured using a new custom resource named `KafkaNodePool`
All nodes from a given pool share the same configuration, but you can have pools with different roles and specs.
Existing clusters can be migrated by creating a `KafkaNodePool` named kafka, with the same configuration and broker role.

All `KafkaNodePool` resources must include the `strimzi.io/cluster` label set to the name of the `Kafka` resource to which it belongs.
This `Kafka` resource must have the `strimzi.io/node-pools: enabled` annotation.

A `KafkaNodePool` resource supports 6 different configurations:

- Number of replicas (required)
- Role(s) of the nodes (required)
- Storage configuration (required)
- Resource requirements (e.g. memory and CPU)
- JVM configuration
- Template for customizing the resources belonging to this pool (pods or containers)

In ZooKeeper mode the role must be set to `broker`, while in KRaft mode the role can be `controller` and/or `broker`.
When not set, the optional configurations are inherited from the `Kafka` resource.

<br>

---
Run the init script and enable the feature gate to setup your environment.

```sh
$ source init.sh
namespace/test created
Done

$ kubectl set env deploy strimzi-cluster-operator STRIMZI_FEATURE_GATES="+KafkaNodePools"
deployment.apps/strimzi-cluster-operator updated

# patch the Subscription if you are using the OpenShift OperatorHub
$ kubectl -n openshift-operators patch sub my-streams --type merge -p '
  spec:
    config:
      env:
        - name: STRIMZI_FEATURE_GATES
          value: "+KafkaNodePools"'
subscription.operators.coreos.com/my-streams patched
```

<br>

---
After the Cluster Operator restart, we can verify if the Kafka cluster is formed correctly.

```sh
$ kubectl create -f sessions/001/resources
kafkanodepool.kafka.strimzi.io/pool-a created
kafkanodepool.kafka.strimzi.io/pool-b created
kafka.kafka.strimzi.io/my-cluster created

$ kubectl get po
NAME                                          READY   STATUS    RESTARTS   AGE
my-cluster-entity-operator-5cdb4b874d-wnj5w   3/3     Running   0          115s
my-cluster-pool-a-0                           1/1     Running   0          2m31s
my-cluster-pool-a-1                           1/1     Running   0          2m31s
my-cluster-pool-a-2                           1/1     Running   0          2m31s
my-cluster-pool-b-3                           1/1     Running   0          2m31s
my-cluster-pool-b-4                           1/1     Running   0          2m31s
my-cluster-zookeeper-0                        1/1     Running   0          3m9s
my-cluster-zookeeper-1                        1/1     Running   0          3m9s
my-cluster-zookeeper-2                        1/1     Running   0          3m9s

$ kubectl get k my-cluster -o yaml | yq '.status | (.clusterId, .kafkaNodePools)'
kWaWWDe5SUagT7J3Xi9xLw
- name: pool-a
- name: pool-b

$ kubectl get knp pool-a -o yaml | yq '.status.clusterId'
kWaWWDe5SUagT7J3Xi9xLw

$ kubectl get knp pool-b -o yaml | yq '.status.clusterId'
kWaWWDe5SUagT7J3Xi9xLw
```

<br>

---
Let's send and receive a message to confirm it works.

```sh
$ kubectl-kafka bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic
>hello nodepools
>^C

$ kubectl-kafka bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning
hello nodepools
^CProcessed a total of 1 messages
```

<br>

---
Finally, you can try to scale up pool-a to see which IDs will be used for the pods.

```sh
$ kubectl scale knp/pool-a --replicas=5
kafkanodepool.kafka.strimzi.io/pool-a scaled

$ kubectl get po
NAME                                          READY   STATUS    RESTARTS   AGE
my-cluster-entity-operator-5784d854f9-d825s   3/3     Running   0          7m26s
my-cluster-pool-a-0                           1/1     Running   0          8m
my-cluster-pool-a-1                           1/1     Running   0          8m
my-cluster-pool-a-2                           1/1     Running   0          8m
my-cluster-pool-a-5                           1/1     Running   0          35s
my-cluster-pool-a-6                           1/1     Running   0          27s
my-cluster-pool-b-3                           1/1     Running   0          8m
my-cluster-pool-b-4                           1/1     Running   0          8m
my-cluster-zookeeper-0                        1/1     Running   0          8m57s
my-cluster-zookeeper-1                        1/1     Running   0          8m57s
my-cluster-zookeeper-2                        1/1     Running   0          8m57s
strimzi-cluster-operator-7ffcf6c67c-gkzv8     1/1     Running   0          16m
```
