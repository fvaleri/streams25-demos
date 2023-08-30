## KRaft mode

> This is experimental, because Kafka support for JBOD storage and dynamic configurations are still missing.
> Additionally, Strimzi does not support the rolling update of dedicated controller nodes, and KRaft cluster upgrade.

KIP-500 removes the dependency on ZooKeeper for managing cluster metadata (KRaft mode).
As of Kafka 3.5.0, ZooKeeper mode is being deprecated, and it will be completely removed in Kafka 4.0.0.
Deploying Streams with Node Pools and UTO features, it is now possible to run a KRaft-based cluster on OpenShift.

<br>

---
Run the init script and enable the feature gates to setup your environment.

```sh
$ source init.sh
namespace/test created
Done

$ kubectl set env deploy strimzi-cluster-operator STRIMZI_FEATURE_GATES="+UseKRaft,+KafkaNodePools,+UnidirectionalTopicOperator"
deployment.apps/strimzi-cluster-operator updated

# patch the Subscription if you are using the OpenShift OperatorHub
$ kubectl -n openshift-operators patch sub my-streams --type merge -p '
  spec:
    config:
      env:
        - name: STRIMZI_FEATURE_GATES
          value: "+UseKRaft,+KafkaNodePools,+UnidirectionalTopicOperator"'
subscription.operators.coreos.com/my-streams patched
```

<br>

---
After the Cluster Operator restart, we can now deploy a Kafka cluster with just 2 pods (a single combined Kafka node, plus the Entity Operators).
This can be useful for development and testing, but you would probably need two dedicated pools in production (controllers and brokers).

```sh
$ kubectl create -f demos/003/resources
kafkanodepool.kafka.strimzi.io/combined created
kafka.kafka.strimzi.io/my-cluster created
kafkatopic.kafka.strimzi.io/my-topic created

$ kubectl get po
NAME                                          READY   STATUS    RESTARTS   AGE
my-cluster-combined-0                         1/1     Running   0          3m34s
my-cluster-entity-operator-564cbdb7cc-q84z7   2/2     Running   0          3m
```

<br>

---
Let's send and receive a message to confirm it works.

```sh
$ krun kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic
>hello kraft
>^C

$ krun kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning
hello kraft
^CProcessed a total of 1 messages
```
