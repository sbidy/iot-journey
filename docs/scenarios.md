# Scenarios

:memo: I'm not sure where this content should live. Should it be part of the [journal's introduction][journal-intro]?

We have established five scenario that we want to address in our first pass at the IoT guidance. 
These scenarios are implicit in the logical architecture in the [journal's introduction][journal-intro].
Here we will describe each scenario (as we currently understand them) and we will identify the relevant technologies.

## Event Processing Scenarios

The first three scenarios all center around the processing of an event stream. 
The technology stacks required for each scenario have these logical components:

- **Ingesting** A service that handles receiving the events.
- **Processing** A service that "processes" the events. This might include filtering, aggregation, and other things.
- **Storaging** A storage location for the results of processing the events.
- **Interacting** A meaningful way to interact with the results located in storage.

For each of the logical components, there are more than one choice available on Azure. 
For _ingestion_ and _processing_ the technologies are much the same for the three scenarios. 
However, _storing_ and _interacting_ differ for each scenario.

For each of the _Event Processing Scenarios_ we will do a comparative analysis of the technology choices.

#### Ingesting

- Kafka
- Event Hubs

We will be using Event Hubs for our reference implementation. 

> TODO: explain why we are not using Kafka in this project.

#### Processing

 - Azure Stream Analytics
 - Apache Storm
 - Apache Spark Streaming
 - custom code 
 
In our case, the custom code will be a .NET implementation of the [`IEventProcessor`](https://msdn.microsoft.com/en-us/library/microsoft.servicebus.messaging.ieventprocessor.aspx).

> TODO: we do not expect to use Spark in this project. Explain why.

### Cold Storage Scenario

We consider storage "cold" if it is cheap and easy to store the event data indefinitely. 
The trade-off here is that data is cold storage is often harder to interact with.
Sometimes there is a need to store eveything. That is, all of the incoming events are retained in their raw format.
For example, the data might be needed for auditing.
Sometimes the data is analyzed.

#### Storing

- Azure Storage blobs
- HDFS

#### Interating

- HDInsight

We will be executing Hive queries.

### Warm Storage for Ad Hoc Exploration Scenario
 
We consider storage "warm" if it is easy for a user to access. 
The trade-off is that many warm storage technologies lack the capacity and simplicity associated with cold storage.
In this scenario, we want to be able to query recent raw events at will.
This means that the storage technology needs to be able to keep up with the overall throughput of the _ingesting_ service.
Since capacity is limited, we expect that we'll periodically remove older data.
For example, perhaps we want to see all of the events that originated with device XYZ between 6AM and 7AM on Tuesday. 
 
#### Storing

- Elasticsearch
- Document DB

#### Interating

- Kibana

### Warm Storage for Aggregrated Stream Scenario

In this scenario, the _processing_ service will be performing computations against the stream and emitting derivative events (most likely aggregated values).
We want to stores these derivative events in a way that makes them accessible to users.
For example, perhaps we want to see the average temperature for a given device over the last five minutes.

#### Storing

- SQL
- Azure Storage tables

#### Interating

- PowerBI

## Others Scenarios

### Device Provisioning

### Translation

[journal-intro]: journal/00-introducing-the-journey.md