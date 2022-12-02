# Cosmos DB Work

## Background

This document investigates the use of Cosmos DB as a data store for the DICOM
metadata, as well as other clinical data and other data types. Cosmos DB is
Microsoft's leading document store that is suited for storing, manipulating and
querying unstructured data at large scale owning to its distributed nature.

DICOM Data is data produced by medical imaging devices for MRI and CT scans and
other use cases. The DICOM data is represented as a binary file with extension
dcm, the binary representation is conformant to the DICOM standard. Elekta’s use
cases is to search over billions of these DICOM files for specific studies or
imaging characterization, since searching over binary data is slow since it
can’t be indexed easily, the metadata of the binary dcm file is extracted and
saved in JSON format. The metadata represents among other things information
such as Patient Name, Imaging type, tumor site, Physician’s name and specialty
and many other fields of interest for the data scientists. Moreover the Data
Science team needs to also search on certain patient data that is not part of
the DICOM data itself, for example, the patient name, sex or age. The DICOM data
only stores the patient id which can be used to join the DICOM Data with the
patient data.

## Use of Cosmos DB

Cosmos DB is Azure NOSQL Document store, it stores documents in JSON format and
can index every field in the JSON document tree (including deeply nested
fields). Cosmos DB is a managed database with no infrastructure to manage or
operational burdens on the user, it is fully distributed and can scale to serve
many Terabytes of data and can scale up to 1,000,000 Request Units per second,
where a Request Unit is defined as Reading 2 KB of data or writing 1 KB of data.
Cosmos DB is very suitable for “point lookups” which imply that the search terms
have to exactly match the data in the index. When avoiding entire document
scans, Cosmos DB can serve complicated queries in several milliseconds. On a
first look it may seem that Cosmos DB is a poor choice for Elekta’s use case
since the data is intended for analytics purposes, however after understanding
the requirements more, it becomes apparent that most of the filters the data
scientists are searching the data for are “exact point lookups”, such as patient
sex, MRI type, Modality, Date ranges, with a few exceptions that requires a full
text search such as Doctor Notes, description, etc.

## Data Ingestion

1. DICOM Files:
    - The data to be ingested is in JSON format and is the meta data of the
      DICOM file (no raw images or binary payload)
    - The files are located in a blob container.
    - the data is located at an external container and needs to be copied to a
      local storage account that is owned by the ingestion process.
    - The need for an extra copy step may seem wasteful and counterintuitive,
      but it is a common pattern where an application owns its data and manages
      its lifecycle, it also allows for many "replays" of the data without
      copying from the source multiple times
2. Patient Data:
   - The patient data is in CSV format and is typically located in one csv file.
     The CSV file is loaded into memory
   - The patient data is related to the DICOM file by the `patient_id` field.

## Architecture

1. The files are copied from the source using an azcopy script, and an Azure
   Event grid subscription is created for new blobs at the destination.
2. The Azure event grid emits event hub payloads that contain the new created
   blob URI. We use the maximum number of partitions allowed for a single
   Event Hub topic which is 32.
3. A consumer application (currently a simple Console App but can be an Azure
   function) listens to incoming events on the Event Hub, which contain the path
   of the DICOM metadata file.
4. The consumer application also reads the patient data at starts and has a map
   of [patientId -> patient].
5. The consumer application consumes the Event Hub topic containing the URI of
   the DICOM files, downloads each file locally
6. The consumer application adds to the DICOM File the patient information as
   well since each DICOM file has a patientID, and uploads it to Cosmos DB.

### Notes about data ingestion

1. We tested the data ingestion on a set of 2.5 Million DICOM files, and a set
of 13,000 patients. The time it takes to write the data to Cosmos DB is a
function of the Request Units available for the Cosmos DB container, Request
units can vary from 10,000/s to 1,000,000/s. With more request units being used
the faster the ingestion and the higher the cost. We tried different RU quotas
and the result are summarized below. It should be noted that our consumer
application applies back pressure to adjust the sending rate to Cosmos DB
whenever we encounter a 429 (throttling error) from Cosmos.

### Performance of Copy

1. Copying the metadata using `azcopy` takes about 40 minutes for 2.5 Million
   DICOM files
2. At the current rate 1 Event Hub Throughput Unit (TU), the 2.5 Million files
   are fired into event hubs in about 50 minutes (1 EH TU has a maximum of 1000
   events/s)
3. Moving the metadata into Cosmos DB takes about 50 minutes at 100,000 RU/s
   (which can be scaled down to 10,000 RU/s)

### Notes about azcopy

1. It is possible to automate the copy of DICOM files from the Azure file share
   to a container as explained
   [here](https://charbelnemnom.com/sync-between-azure-file-share-and-azure-blob-container/).
   The main idea is to use an Azure automation account and workbook to sync
   between the file share and the blob using the `azcopy sync`
   [functionality](https://docs.microsoft.com/en-us/azure/storage/common/storage-ref-azcopy-sync)

## Querying the Data

With a flattened document structure as explained above (data de-normalization)
where a copy of the patient data is also saved with each DICOM file, searching
and querying does not require joins any more. This is a classic example of
trading space complexity for time complexity where we sacrifice storage space in
favor of reduced querying time. With the sample 2.5 million DICOM files and
13,000 patients the Cosmos DB storage space is about 15 GB.

## Future extensions of the Data

We discussed querying the DICOM files and patients data. Those are currently the
only known data sources that can be queried. In the future, there may be extra
sources that need to be queried and correlated with the Patient and DICOM data,
We do not have access to this kind of data yet, however an example that was
given was certain machine diagnostic information. The machine information (for
example the kind of machine that took a particular MRI scan) is saved in the
DICOM file. Newly added data can be incorporated into Cosmos in 2 ways.

1. First the data is de-normalized again and each DICOM instance stored in
   Cosmos DB gets a reference of the new data.
2. The second approach is that new data can be stored into a separate Cosmos
container (similar to a table in SQL) and the data has to be manually joined in
memory with the original container. Each of these approaches has its pros and
cons which we will discuss here

### De-normalizing the Data

#### Pros

- Much faster lookup for the data and no change in query execution
- No change in the model for patient data and all data is standardized

#### Cons

- The individual document size can grow large very quickly and can exceed the 4
  MB doc limit for Cosmos
- The size bloat may increase the cost of storage very quickly

### Separate table

#### Advantages

- Less storage is needed

#### Disadvantages

- Cosmos DB does not support cross partition joins and hence a custom in memory
  client (Console app, function app for example) has to be written to separate
  the query into N pieces (one for each container) and dispatch one for each
  container and then perform the filtering and aggregation in memory.
- This becomes quickly infeasible in Cosmos DB since we can quickly hit
  performance limits and many edge cases
- This is similar to implementing a very important piece of relational databases
  on top of a distributed Document store which is no easy feat.

## Query Performance against Cosmos DB

We have done the following query performance analysis for Cosmos DB. We have set
the Maximum RU to 100,000 RUs and ran the data ingestion as described the
Architecture section. The DICOM dataset was 2.5 Million file and 13,000
patients.

1. `SELECT c.SOPInstanceUID from c` This query retrieves all DICOM instance uid.
   This took 40 seconds to execute and was done in 40 calls to Cosmos and
   retrieved the entire 2.5 million files.
2. `Select DISTINCT VALUE c.SOPInstanceUID FROM c ORDER BY c.SOPInstanceUID`.
   This took 4 minutes and retrieved the original 2.5 million files.
3. `Select c.studyUUID FROM c`. This took 40 seconds and retrieved all 2.5
   Million files
4. `Select DISTINCT VALUE c. studyUUID FROM c ORDER BY c. studyUUID`. This took
   4 minutes and returned 1128 items.

### Notes

1. The SOPInstanceUID was used as the partition key for the Cosmos DB
   collection.
2. Any query that involves the “DISTINCT” operator performed much worse than
   doing an in memory client filtering for uniqueness.
3. It is made clear in Cosmos DB documentation that Cosmos DB is not suitable
   for analytical workloads, but what was surprising is the query in line 4. I
   was under the impression that since there were only 1128 studies, a query
   such as (4) should have been very quick since everything in Cosmos DB is
   indexed. The surprise is that those indices are not organized in such a
   manner to be able to answer simple statistical questions like unique
   elements. This particular result was disappointing since it implied that we
   can’t answer such a simple question like “How many studies does the data have
   ” or “How many patients do this data represent” in Cosmos. On a similar line,
   any operation that would perform an in memory JOIN (see the above section,
   would be prohibitively slow)
4. The above results hold even when the Request Unit limit is doubled, hence
   throughput is not a bottle neck here

## Cost of Cosmos DB

1. Cosmos DB is a serverless offering where users are charged based on
   Throughput and Data storage, there are no tiers or SKUs to adjust from in
   Cosmos DB.
2. The main charge unit is the Request Unit (RU).
3. Each 100 RUs in Cosmos DB cost $6 per month
4. Each 1 GB of data costs $0.25 to store per month
5. For each 1 GB of data in Cosmos DB there has to be a minimum of 10 RUs
   assigned to the container. For example, for 50 GB of data, there needs to be
   500 RUs
6. The table below summarizes the total cost of Cosmos DB for different data
   sizes

|Number of DICOM Files|Data Size |Storage Cost (dollar)|Compute Cost (RU/s)|Compute Cost, High Storage Low Throughput Program|Total Cost|Total Cost ( with program)|
|:----|:----|:----|:----|:----|:----|:----|
|2.5 Million|15 GB|$4/month| | | | |
|10 Million|50 GB|$12.50/ month|$30 / month| | | |
|1 billion|5 TB|$1250 / month|$3000 / month|$300 / month|~ $4250 / month|~ $1600 / month|
|10 billion|50 TB|$12500 / month|$30000/ month|$3000 / month|~$42000 / month|~ $16000 / month|

### Notes 1

1. When assuming that we will have about 10 billion DICOM files, the storage
   requirements round up to about 50 TB of data. The corresponding RUs and
   Compute Cost becomes 3x the storage cost.
2. For Elekta’s use case where the data is analyzed by several data scientists
   several times in the day, we do not need that very high throughput
3. Even if the data is to be publicly opened to the public to query, that
   throughput is not needed to sustain a relatively high application concurrency

## High Storage Low Throughput program

1. The high storage low throughput program is a Cosmos DB program created to
   address this use case.
2. It allows the min required RUs for each 1 GB of storage to be lowered from 10
   RUs to just a single RU.
3. This equates to a cost saving of 10x for compute which is a huge reduction in
   costs

## Summary

We have investigated the use of Cosmos DB in storing very large sets of DICOM
and patient data as well as other auxiliary data that might be of interest later
in the course of the application. Cosmos DB main advantage is that it is a
document store allowing the entire dataset to be stored in the native DICOM JSON
format and allows very easy query pattern for any data field, no matter how
nested in the JSON tree structure. The lack of JOIN relationships in Cosmos DB
can be compensated by de-normalizing the data but this approach can quickly
become problematic from a storage perspective if there are multiple data tables
that need to be de-normalized. Alternatively, an in memory cross partition JOIN
operation can be performed, however it was shown that this can be prohibitively
slow and impractical for many of the queries of interest. Cost-wise, Cosmos DB
when paired with the high storage low throughput program is somewhat cost
effective (although not the optimal solution) if it were not lacking in other
regards as discussed above.

## Appendices

### Appendix 1: Real time result streaming

Although Cosmos DB has proved itself too slow when performing certain kinds of
artificial joins and queries, data can still be obtained in real time since the
first batch of data is served in several seconds.  The “preview” set of results
can be shown to the data scientist in real time as they are interacting with the
query analyzer. Once they preview the data, a “job” is dispatched to perform the
query and copy the DICOM files to the destination storage account. When
measuring the performance of the various queries issued, the first batch of data
arrives in ~2 seconds.

### Appendix 2: Full text search with Cognitive Search

Another big advantage that Cosmos DB would have offered if it were more suitable
to our use case would have been a tight integration between Azure Cognitive
Search (ACS) services. Currently to get good performance out of Cosmos DB, the
queried elements must exactly the field being queried over (hitting the index).
If a full text search capability or a fuzzy search ability was needed that would
require a full database scan which can be prohibitively slow and expensive for
large volumes of data. With ACS integration, data is synchronized automatically
to an ACS index where it can be queried very easily. The data sync allows us to
specify which fields are required to be full text searchable (for example
Doctor’s notes or description or case narrative and so on). ACS will only store
those fields in the index along with the document ID. The data can be queried in
the following way, first the application responsible for query processing will
parse the query and deduce which fields belongs to ACS (the full text search
one) and the remaining fields will be issued to Cosmos DB. An in memory join can
be issued to combine the results from ACS and Cosmos DB. A good reference for
indexing Cosmos db data with ACS can be found
[here.](https://docs.microsoft.com/en-us/azure/search/search-howto-index-cosmosdb)
