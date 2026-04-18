# f1-dataops
An automated, idempotent batch processing architecture for F1 data. Features GCS data lakes, BigQuery data warehousing, infrastructure as code with Terraform and CI/CD pipeline with Github Actions.
```mermaid
graph TD
    subgraph Orchestration Layer
        A[Cloud Scheduler<br>Cron: 0 9 * * 1] -->|Triggers| B(Cloud Function<br>Weekly Planner)
        B -->|Reads| C[(GCS Metadata Bucket<br>f1_calendar.json)]
        B -->|Enqueues| D[Cloud Tasks<br>Execution Queue]
    end

    subgraph Compute & Extraction Layer
        D -.->|Fires at T+2h| E[Cloud Run Job<br>Python Extractor]
        F[Artifact Registry<br>Docker Image] -->|Pulls| E
        E -->|API Request| G((OpenF1 API))
    end

    subgraph Data & Analytics Layer
        E -->|Saves .parquet| H[(GCS Data Lake Bucket)]
        I[BigQuery<br>External Table] -.->|Zero-ETL Query| H
    end

    classDef gcp fill:#e8f0fe,stroke:#1a73e8,stroke-width:2px;
    classDef external fill:#fce8e6,stroke:#ea4335,stroke-width:2px;
    
    class A,B,C,D,E,F,H,I gcp;
    class G external;
```
