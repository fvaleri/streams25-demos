## Unidirectional Topic Operator

> This feature is available as a preview.
> It is not enabled by default, so you must configure the feature gate before using it.

The Unidirectional Topic Operator (UTO) only synchronizes the topic state from Kubernetes to Kafka (one way).
This is backwards compatible with the existing `KafkaTopic` resources, but any topic configuration change done in Kafka will be reverted.
You can un-manage a topic by simply setting the `strimzi.io/managed="false"` annotation.

<br>

---
Run the init script and enable the feature gate to setup your environment.

```sh
$ source init.sh
namespace/test created
Done

$ kubectl set env deploy strimzi-cluster-operator STRIMZI_FEATURE_GATES="+UnidirectionalTopicOperator"
deployment.apps/strimzi-cluster-operator updated

# patch the Subscription if you are using the OpenShift OperatorHub
$ kubectl -n openshift-operators patch sub my-streams --type merge -p '
  spec:
    config:
      env:
        - name: STRIMZI_FEATURE_GATES
          value: "+UnidirectionalTopicOperator"'
subscription.operators.coreos.com/my-streams patched
```

<br>

---
After the Cluster Operator restart, we can deploy a Kafka cluster with the new Topic Operator.

```sh
$ kubectl create -f sessions/002/install
kafka.kafka.strimzi.io/my-cluster created
kafkatopic.kafka.strimzi.io/my-topic created

$ kubectl get po
NAME                                          READY   STATUS    RESTARTS   AGE
my-cluster-entity-operator-564cbdb7cc-4scvq   2/2     Running   0          35s
my-cluster-kafka-0                            1/1     Running   0          64s
my-cluster-kafka-1                            1/1     Running   0          64s
my-cluster-kafka-2                            1/1     Running   0          64s
my-cluster-zookeeper-0                        1/1     Running   0          100s
my-cluster-zookeeper-1                        1/1     Running   0          100s
my-cluster-zookeeper-2                        1/1     Running   0          100s
```

<br>

---
Let's send and receive a message to confirm it works.

```sh
$ kubectl-kafka bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic
>hello uto
>^C

$ kubectl-kafka bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning
hello uto
^CProcessed a total of 1 messages
```

<br>

---
Finally, try to increase the number of topic partitions.
Reduction and changing the replication factor is not supported, but you can use the `kafka-reassign-tool` for that.

```sh
$ kubectl-kafka bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --describe
Topic: my-topic	TopicId: WyhsoDQRSXqa8k2myxQrrA	PartitionCount: 3	ReplicationFactor: 3	Configs: min.insync.replicas=2,message.format.version=3.0-IV1
	Topic: my-topic	Partition: 0	Leader: 1	Replicas: 1,0,2	Isr: 1,0,2
	Topic: my-topic	Partition: 1	Leader: 0	Replicas: 0,2,1	Isr: 0,2,1
	Topic: my-topic	Partition: 2	Leader: 2	Replicas: 2,1,0	Isr: 2,1,0

$ kubectl patch kt my-topic --type merge -p '
  spec:
    partitions: 5'

$ kubectl-kafka bin/kafka-topics.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --describe
Topic: my-topic	TopicId: CPgTTY5hShSiUn8iApkD-A	PartitionCount: 5	ReplicationFactor: 3	Configs: min.insync.replicas=2,message.format.version=3.0-IV1
	Topic: my-topic	Partition: 0	Leader: 1	Replicas: 1,0,2	Isr: 1,0,2
	Topic: my-topic	Partition: 1	Leader: 0	Replicas: 0,2,1	Isr: 0,2,1
	Topic: my-topic	Partition: 2	Leader: 2	Replicas: 2,1,0	Isr: 2,1,0
	Topic: my-topic	Partition: 3	Leader: 1	Replicas: 1,2,0	Isr: 1,2,0
	Topic: my-topic	Partition: 4	Leader: 2	Replicas: 2,0,1	Isr: 2,0,1
```

We disable them in this demo, but finalizers are used by default to avoid missing topic deletion events when the UTO is not running.
A common pitfall is that the namespace becomes stuck in a "terminating" state when you try to delete it without first deleting all topics.
If this happens, you can simply remove finalizers from all `KafkaTopic` resources at once with the following command.

```sh
kubectl get kt -o yaml | yq 'del(.items[].metadata.finalizers[])' | kubectl apply -f -
```
