# Risk Assessment: OneStream System Diagnostics (OSD)

**Tool Version:** PV8.5.0 SV111
**Assessment Date:** 2026-06-18
**Prepared By:** Security Architecture
**Methodology:** NIST SP 800-30 Rev. 1 | NIST SP 800-53 Rev. 5

---

## 1. Executive Summary

This document presents a security risk assessment of **OneStream System Diagnostics (OSD)**, version **PV8.5.0 SV111**, as deployed against a OneStream application environment that processes and stores data classified as **Treasury Sensitive But Unclassified / Controlled Unclassified Information (SBU/CUI)**. This data classification applies because the organization operates under a Congressional mandate through the Federal Reserve to perform software development and maintenance on behalf of the **U.S. Department of Treasury** and the **Bureau of Fiscal Service**. Data handled within this environment carries federal dissemination controls and handling requirements consistent with the SBU/CUI dual-marking transition framework currently in effect.

The assessment was conducted using the risk methodology defined in **NIST SP 800-30 Rev. 1** and maps control recommendations to **NIST SP 800-53 Rev. 5**.

OSD is a monitoring and diagnostics utility restricted to System Administrators. While it does not directly access SBU/CUI data values, it accesses application metadata, database server state, data volume statistics, and error logs — all of which carry material risk in an SBU/CUI-classified environment. Additionally, OSD's **Report Package** feature creates diagnostic bundles explicitly designed to be transmitted to a third party (OneStream Software Support), representing an uncontrolled external disclosure pathway for application schema and metadata associated with a federally mandated system.

**Eight (8) risks were identified.** Two are rated **High**, four are rated **Moderate**, and two are rated **Low**. The two High-rated risks require remediation or formal risk acceptance before deployment is recommended.

| Risk ID | Risk Title | Rating |
|---------|-----------|--------|
| R-01 | Unauthorized Access to Application Metadata | Moderate |
| R-02 | Third-Party Disclosure via Report Package | **High** |
| R-03 | Excessive SQL Server Privilege (VIEW SERVER STATE) | Moderate |
| R-04 | Cross-Application Exposure via Shared Framework Database | Low |
| R-05 | Automated Snapshot Collection Without Explicit Authorization | Moderate |
| R-06 | Error Log Exposure Containing SBU/CUI Fragments | **High** |
| R-07 | Insufficient Audit Trail for OSD Activities | Moderate |
| R-08 | Weak Separation of Duties — Single Security Role Gate | Low |

**Overall Assessment Rating: HIGH**

Remediation of R-02 and R-06 is required prior to or concurrent with authorization to operate. Remaining Moderate risks should be addressed through documented compensating controls accepted by the System Owner.

---

## 2. Purpose and Scope

### 2.1 Purpose

This risk assessment evaluates the security risks introduced by deploying OneStream System Diagnostics (OSD) in an environment where the OneStream application processes, stores, or transmits Treasury SBU/CUI. The goal is to identify threats and vulnerabilities relevant to OSD's capabilities, determine risk levels, and recommend NIST 800-53 Rev. 5 controls to reduce risk to an acceptable level.

### 2.2 Scope

**In scope:**

- The base OSD tool, version PV8.5.0 SV111, including all core functional modules: Environment Analysis, Application Analysis, Task Analysis, Environment Health, Task Health, and Report Package.
- The OneStream application server(s), database server(s), and Framework database to which OSD has access.
- The data access surface introduced by OSD installation and operation in a Treasury SBU/CUI-classified application environment operating under Federal Reserve Congressional mandate.

**Out of scope:**

- The AI System Diagnostics add-on (paid, Platform 9.0+ feature — not in scope per stakeholder decision).
- The underlying OneStream platform risk profile (assumed to be separately assessed).
- Network-layer controls (firewall, WAF, load balancer) — assumed in place per existing authorization boundary.

### 2.3 SBU/CUI in This Context

**Sensitive But Unclassified (SBU)** is a U.S. federal government designation for information that, while not classified for national security purposes, requires administrative controls and protection from unauthorized public disclosure. The Department of Treasury has historically applied SBU to financial regulatory data, examination reports, and system information related to federal financial operations.

**Controlled Unclassified Information (CUI)** was established by Executive Order 13556 to standardize and replace legacy SBU designations across the federal government. CUI requires safeguarding consistent with applicable law, regulation, and government-wide policy, and is governed by 32 CFR Part 2002 and NIST SP 800-171.

This organization is currently in a **dual-marking transition period**, using both SBU and CUI markings concurrently. Data within the assessed OneStream environment originates from or supports systems operated on behalf of the **U.S. Department of Treasury** and **Bureau of Fiscal Service** under a Congressional mandate administered through the Federal Reserve. This context imposes federal dissemination controls, transmission encryption requirements, and access restrictions that exceed standard commercial data protection practices.

---

## 3. System Characterization

### 3.1 Tool Description

**OneStream System Diagnostics (OSD)** is a Community Solution Dashboard deployed inside an existing OneStream CPM (Corporate Performance Management) application. It enables System Administrators to monitor environment performance, analyze application metrics and data volumes, and capture diagnostic snapshots. OSD version PV8.5.0 SV111 requires a minimum OneStream Platform version of 8.5.0 and was developed and is maintained by **OneStream Software LLC**.

Access to OSD is explicitly restricted to users holding the System Administrator security role. The OSD guide states that this restriction "should be strictly enforced because of the accessibility to application information and controls."

### 3.2 Architecture Overview

| Component | Description |
|-----------|-------------|
| Deployment Model | Installed as a Community Solution Dashboard within an existing OneStream application |
| Interface | Browser-based dashboard within the OneStream web client |
| Backend | Business Rules (VB.NET/C# extensions) and Data Management sequences |
| Data Store | Writes to ancillary tables in the **OneStream Framework database** |
| Scope | Although architecturally capable of analyzing all applications sharing the same Framework database, **OSD will be run against a single designated application only** in this deployment. Cross-application visibility remains a technical capability of the tool but will not be used operationally (see R-04). |
| Scheduler | Automatically creates a Task Scheduler job on first setup (monthly, third Saturday, 23:30 UTC) |
| External Path | Report Package exports a `.zip` to the OneStream File Share; designed for email transmission to OneStream Software Support |

### 3.3 Functional Modules and Data Access

| Module | Data Accessed | Contains SBU/CUI? |
|--------|--------------|-------------------|
| Environment Analysis | CPU, RAM, user concurrency counts, application and database server state | No — aggregate statistics only |
| Application Analysis | Record counts, DB table sizes, formula counts, data volume counts by cube/scenario/entity; entity names, workflow names | Schema-adjacent — entity and workflow names may reference SBU/CUI categories or subject matter |
| Task Analysis | Task logs, user login activity by type (per-minute granularity), task completion and failure counts | User identity data (login records) — PII-adjacent |
| Environment Health | Real-time CPU, RAM, blocking transactions, buffer cache ratios, I/O statistics, SQL connection and DML statement counts | No direct SBU/CUI |
| Task Health | Long-running task details, task error records, unhealthy task identification | Potentially — task error details may reference data objects by name |
| **Report Package** | Bundles all of the above into a `.zip` for external transmission to vendor support | **Yes — schema-adjacent data and potential error log fragments** |
| Error Log (Long Running Formulas report) | Error log entries from the past 30 days | **Potentially — exception handlers in financial applications may log SBU/CUI-adjacent values** |

### 3.4 Required Permissions

OSD requires the following non-default permissions, each representing a deliberate privilege extension:

- **SQL Server:** `VIEW SERVER STATE` granted at the **server level** — not database level. This exposes Dynamic Management Views (DMVs) across all databases on the SQL Server instance, not only the OneStream database.
- **OneStream Application Server:** `Can Create Ancillary Tables` and `Can Edit Ancillary Table Data` set to `True`.
- **OneStream Security:** A designated security role must be configured; only users in that role can access OSD.
- **File Share:** Write access required for Report Package output.

### 3.5 Data Flow Summary

```
[System Admin User]
        |
        v
[OSD Dashboard (OneStream Web Client)]
        |
        +----> [OneStream Application Server]
        |              |
        |              +----> [Application DB — metadata, record counts, table sizes]
        |              +----> [Framework DB — OSD snapshot tables (cross-application scope)]
        |              +----> [SQL Server DMVs (VIEW SERVER STATE) — server-wide health data]
        |              +----> [Error Logs — 30-day history via Long Running Formulas report]
        |
        +----> [Task Scheduler — automated monthly snapshots, no user action required]
        |
        +----> [File Share — Report Package .zip]
                        |
                        v
              [Email to OneStream Support] <-- EXTERNAL DISCLOSURE PATH / SBU/CUI RISK
```

---

## 4. Risk Register

### R-01 — Unauthorized Access to Application Metadata
**Rating: Moderate | Likelihood: Low | Impact: Moderate**

OSD's Application Analysis module surfaces entity names, cube names, workflow profile names, formula counts, stage workflow volume counts, and database table sizes for the SBU/CUI application. While OSD does not return actual data values, this structural information constitutes a reconnaissance asset. An adversary or malicious insider who understands the application's data model — including the names of entities and workflows tied to Treasury and Bureau of Fiscal Service operations — can more effectively target specific tables or data pathways in a follow-on attack.

This risk is partially mitigated by OSD's restriction to the System Administrator security role. The residual concern is that this role may be more broadly assigned than the principle of least privilege would warrant in a federally mandated data environment.

**Relevant NIST 800-53 Controls:** AC-2, AC-3, AC-6, AU-12

---

### R-02 — Third-Party Disclosure via Report Package
**Rating: HIGH | Likelihood: Moderate | Impact: High**

OSD's **Report Package** feature bundles environment and application snapshots — including database table sizes, data volume statistics by cube and entity, application metadata, and potentially error log content — into a `.zip` file stored in the OneStream File Share. The OSD guide explicitly instructs administrators to email this file to **OneStream Software Support**. This is a built-in, vendor-designed external disclosure pathway.

In a Treasury SBU/CUI environment, this pathway carries significant risk:

- Report Package contents include schema-adjacent metadata — entity names, cube names, workflow names, and table structures — that may directly reflect the organization's Treasury and Bureau of Fiscal Service system architecture.
- No documented data sanitization or content review step is required before transmission.
- SBU/CUI transmission controls require encryption to current NIST standards; email transmission of a Report Package is unencrypted by default unless organizational email controls enforce TLS end-to-end.
- A formal **Data Processing Agreement (DPA)** or **Information Sharing Agreement (ISA)** with OneStream Software LLC governing the handling of diagnostic data has not been confirmed. For federal data subject to CUI dissemination controls, transmitting application metadata to a vendor without a governing agreement is a compliance gap.

This risk is rated **High** because the transmission pathway is an intentionally designed feature — not an edge case — and the absence of a governing agreement or a formal review process means every Report Package transmission is currently an uncontrolled disclosure event.

**Relevant NIST 800-53 Controls:** SA-9, CA-3, SC-8, SI-12, PT-7

---

### R-03 — Excessive SQL Server Privilege (VIEW SERVER STATE)
**Rating: Moderate | Likelihood: Low | Impact: High**

OSD requires that the SQL Server service account used by OneStream be granted `VIEW SERVER STATE` at the **server level**. This permission unlocks Dynamic Management Views (DMVs) that expose all active connections, currently executing queries, memory and I/O statistics, and blocking information across **all databases on the SQL Server instance** — not only the OneStream database.

In an environment where the OneStream application database shares a SQL Server instance with other systems, this permission extends OSD's effective visibility beyond the OneStream boundary. A compromised OneStream SQL service account with this permission could be used to enumerate active query activity in adjacent systems. Given that this environment supports Treasury and Bureau of Fiscal Service operations, co-located systems may themselves hold SBU/CUI data.

The likelihood is rated Low because exploitation requires compromise of the SQL service account, and existing account management controls reduce that probability. The impact remains High due to the server-wide scope of the permission.

**Relevant NIST 800-53 Controls:** AC-6, CM-7, IA-5, SA-9

---

### R-04 — Cross-Application Exposure via Shared Framework Database
**Rating: Low | Likelihood: Very Low | Impact: Moderate**

OSD tables are created in and operate from the **OneStream Framework database**, a shared component common to all applications deployed on the same OneStream environment. Architecturally, a single OSD installation is capable of capturing metadata and data volume statistics for any application sharing that Framework — not only the application where OSD was installed.

In this deployment, however, **OSD will be run against a single designated application only**. This operational constraint reduces the likelihood of cross-application exposure through intentional use to Very Low, moving the overall risk rating from Moderate to Low. The constraint should be documented as a formal assumption and reflected in the System Security Plan, as it is a policy control rather than a technical restriction — a misconfigured or rogue administrator could still direct OSD at another application on the same Framework. The residual risk is the gap between the tool's technical capability and the documented operational boundary.

**Relevant NIST 800-53 Controls:** AC-4, SC-4, CM-7, AC-3

---

### R-05 — Automated Snapshot Collection Without Explicit Authorization
**Rating: Moderate | Likelihood: High | Impact: Low**

When OSD's tables are initialized during setup, the solution **automatically creates a Task Scheduler job** — "Snapshot Automation OSD" — that runs monthly on the third Saturday at 23:30 UTC without requiring administrator intervention. This task collects environment and application snapshots and stores them in the Framework database.

In a Treasury SBU/CUI environment, all background data collection activities should be formally authorized and documented in the system's configuration baseline before they begin. Because this task is created automatically during setup, it may be activated and begin collecting data before a formal authorization review has been conducted. Additionally, if multiple OSD installations exist on the same Framework, subsequent installs schedule additional tasks at 30-minute offsets, further extending the automated collection surface without explicit approval for each.

The likelihood is rated High because this behavior is automatic and certain. The impact is rated Low because the data collected is metadata and statistics rather than SBU/CUI values directly — but the absence of formal authorization is itself a compliance gap in this regulatory context.

**Relevant NIST 800-53 Controls:** CM-3, CM-6, AU-2, PL-2, CA-7

---

### R-06 — Error Log Exposure Containing SBU/CUI Fragments
**Rating: HIGH | Likelihood: Moderate | Impact: High**

OSD's **Long Running Formulas** report queries the OneStream error log for the past 30 days to surface formulas that exceeded runtime thresholds. The **Task Health** module similarly captures error details from unhealthy tasks. Both features make error log content visible through the OSD dashboard to any user holding the OSD security role.

In a financial application processing Treasury and Bureau of Fiscal Service data, OneStream error logs may contain unintentional SBU/CUI fragments. Common sources include:

- Exception handlers in Finance Rules or Member Formulas that log contextual data (entity identifiers, account references, calculation inputs) when a formula fails mid-execution.
- Stage processing errors that include source record identifiers from Treasury or BFS data feeds.
- Data Management sequence failures that capture record-level context in their error output.

If error logs contain SBU/CUI fragments, any user with OSD access can view that information through a standard dashboard — outside of the data handling controls that govern direct access to the application's primary data. There is currently no documented review of error log content for SBU/CUI, and no sanitization policy is in place.

This risk is rated **High** because error log contamination with sensitive data is common in financial application environments, the exposure pathway is a standard OSD feature rather than an edge case, and the regulatory consequences of uncontrolled SBU/CUI disclosure are significant in a federally mandated operational context.

**Relevant NIST 800-53 Controls:** AU-9, SI-12, AC-3, AC-6, SA-15

---

### R-07 — Insufficient Audit Trail for OSD Activities
**Rating: Moderate | Likelihood: Moderate | Impact: Moderate**

OSD activities — including snapshot creation, Report Package generation, health monitoring sessions, and configuration changes — may not generate granular audit records captured by the organization's centralized logging or SIEM infrastructure. The OSD documentation does not specify that these actions produce discrete audit events beyond standard OneStream platform task log entries.

For a system supporting Treasury SBU/CUI data under a federal mandate, NIST SP 800-53 AU-2 and AU-12 require that significant data access activities generate auditable events. Without adequate logging of OSD activity, two critical security functions are impaired: the ability to detect anomalous or unauthorized use of OSD in near-real-time, and the ability to reconstruct a timeline of access during an incident response investigation involving potential SBU/CUI exposure.

**Relevant NIST 800-53 Controls:** AU-2, AU-3, AU-12, IR-4

---

### R-08 — Weak Separation of Duties — Single Security Role Gate
**Rating: Low | Likelihood: Low | Impact: Low**

OSD provides a single configurable security role as its sole access control mechanism. All users assigned to that role have full access to every OSD capability: environment and application analysis, health monitoring, Report Package generation, global settings modification, and uninstall. No read-only access mode or sub-role separation is documented within OSD.

In an SBU/CUI environment with separation of duties requirements, the inability to grant a user read-only monitoring access without also granting Report Package generation and configuration capabilities is a control gap. However, because the overall OSD user population is limited to System Administrators — who by definition already hold broad platform privileges — the incremental risk introduced by this flat access model is lower than if OSD were accessible to a wider user population. The primary concern is the absence of a documented compensating control (such as a required two-administrator approval for Report Package transmissions).

**Relevant NIST 800-53 Controls:** AC-5, AC-6, PS-2

---

## 5. Required Actions

The following actions are required or recommended before and after authorization. Priority actions must be resolved before an Authorization to Operate (ATO) is granted.

| Priority | Action | Owner | Target |
|---|---|---|---|
| **Required** | Review OneStream error logs for SBU/CUI content; document findings; if present, implement sanitization controls (addresses R-06) | Application Owner / Security Architecture | Before ATO |
| **Required** | Confirm or establish a Data Processing Agreement (DPA) or Information Sharing Agreement (ISA) with OneStream Software LLC governing Report Package content and handling (addresses R-02) | Legal / Vendor Management | Before ATO |
| **Required** | Implement Report Package transmission controls: encrypted channel required; two-administrator approval before any transmission to OneStream Support (addresses R-02, R-08) | System Owner / IT Operations | Before ATO |
| **Required** | Formally authorize the Snapshot Automation OSD Task Scheduler job through change management; document in configuration baseline (addresses R-05) | Change Management / System Owner | Before ATO |
| Recommended | Evaluate whether `VIEW SERVER STATE` SQL permission can be scoped to minimum necessary DMVs; document finding (addresses R-03) | DBA / Security Architecture | 90 days post-ATO |
| Recommended | Validate OSD audit events are captured in SIEM at sufficient granularity (addresses R-07) | Security Operations | 90 days post-ATO |
| Recommended | Conduct formal least-privilege review of OSD security role population (addresses R-01, R-08) | IAM / System Owner | 90 days post-ATO |
| Recommended | Document Framework database cross-application scope in System Security Plan (SSP) (addresses R-04) | Security Architecture | 90 days post-ATO |
| Recommended | Establish coding standard prohibiting logging of SBU/CUI-adjacent values in OneStream exception handlers (addresses R-06 long-term) | Application Development / Security Architecture | 180 days post-ATO |

---

## 6. NIST 800-53 Control Recommendations

The following table maps recommended controls to the risks they address and states the specific action required. Full control definitions are available in NIST SP 800-53 Rev. 5.

| Control | Title | Risks Addressed | Action Required |
|---|---|---|---|
| AC-2 | Account Management | R-01, R-03 | Maintain and quarterly review inventory of users in the OSD security role and the SQL service account holding VIEW SERVER STATE |
| AC-3 | Access Enforcement | R-01, R-06 | Validate OSD role assignment is limited to personnel with documented operational need; restrict if error log SBU/CUI content is confirmed |
| AC-4 | Information Flow Enforcement | R-04 | Document and diagram the cross-application information flow through the shared Framework database in the SSP |
| AC-5 | Separation of Duties | R-08 | Implement compensating control: require two-administrator approval for all Report Package transmissions |
| AC-6 | Least Privilege | R-01, R-03, R-06 | Minimize OSD security role population; evaluate scoping VIEW SERVER STATE to database level; enforce no-SBU/CUI-logging coding standard |
| AU-2 | Event Logging | R-05, R-07 | Define auditable OSD events: snapshot creation, Report Package generation, settings changes, health monitoring sessions |
| AU-3 | Content of Audit Records | R-07 | Ensure audit records include timestamp, user identity, action performed, and data scope |
| AU-9 | Protection of Audit Information | R-06 | If error logs contain SBU/CUI fragments, classify them accordingly and apply appropriate access and retention controls |
| AU-12 | Audit Record Generation | R-07 | Verify OneStream platform generates audit records for all OSD-initiated actions including Task Scheduler executions |
| CA-3 | Information Exchange | R-02 | Establish ISA/DPA with OneStream Software LLC before any Report Package transmission occurs |
| CM-3 | Configuration Change Control | R-05 | Process the auto-created Snapshot Automation OSD task through formal change management before production deployment |
| CM-6 | Configuration Settings | R-05 | Include the OSD Task Scheduler job in the documented configuration baseline |
| CM-7 | Least Functionality | R-03, R-04 | Evaluate minimum necessary SQL permissions; document Framework DB scope as a known architectural constraint |
| IR-4 | Incident Handling | R-07 | Update the incident response plan to include OSD as a potential discovery or exfiltration vector |
| SA-9 | External System Services | R-02, R-03 | Treat OneStream Support Report Package receipt as an external service; verify vendor meets organizational security requirements |
| SC-8 | Transmission Confidentiality and Integrity | R-02 | Require encrypted channel (TLS-enforced email or secure file transfer) for all Report Package transmissions |
| SI-12 | Information Management and Retention | R-02, R-06 | Establish retention and deletion policy for OSD snapshot data in the Framework database and Report Package files in the File Share |

---

## 7. Overall Risk Rating and Recommended Disposition

**Overall Rating: HIGH**

The combined risk posture for OSD in a Treasury SBU/CUI environment is **High**, driven by two findings that represent uncontrolled compliance gaps under the current control baseline:

- **R-02:** The Report Package feature creates an uncontrolled third-party disclosure path to a commercial vendor without a confirmed data handling agreement — in an environment governed by federal SBU/CUI dissemination controls.
- **R-06:** OSD's access to error logs creates a potential SBU/CUI exposure pathway if application exception handlers log sensitive data values, and no review or sanitization process currently exists.

| Condition | Recommended Disposition |
|---|---|
| R-02 and R-06 unmitigated | **Do not authorize.** OSD should not be placed in production use against the SBU/CUI application until these risks are mitigated or formally accepted in writing by the Data Owner and System Owner. |
| R-02 and R-06 mitigated (ISA/DPA established; error log review completed with documented findings) | **Authorize to Operate** with standard conditions addressing the remaining Moderate risks via POAM. |
| R-02 or R-06 cannot be fully mitigated | **Conditional Authorization** only with written risk acceptance from the System Owner and Data Owner, and a formal Plan of Action and Milestones (POAM) for future remediation. |

---

## 8. Final Recommendations, Assumptions, and Approval Conditions

### 8.1 Key Assumptions

This assessment rests on the following assumptions. If any assumption proves incorrect, the affected risk ratings and recommendations should be revisited before authorization proceeds.

| # | Assumption | Risk(s) Affected |
|---|---|---|
| A-1 | OSD will be run against a single designated application only; administrators will not use OSD to analyze other applications on the same Framework database | R-04 |
| A-2 | The SQL Server service account used by OneStream is a dedicated service account, not shared with other systems or applications | R-03 |
| A-3 | Multi-factor authentication (MFA) is enforced for all accounts capable of being assigned to the OSD security role | R-01, R-08 |
| A-4 | The OneStream environment is protected by existing network segmentation and perimeter controls per the current authorization boundary | R-01, R-03 |
| A-5 | OneStream platform-level audit logging is active; whether OSD-specific actions generate discrete SIEM-visible events has not yet been confirmed | R-07 |
| A-6 | No Data Processing Agreement (DPA) or Information Sharing Agreement (ISA) with OneStream Software LLC governing diagnostic data transmission is currently in place | R-02 |
| A-7 | The content of OneStream error logs for the subject application has not been reviewed for SBU/CUI fragments | R-06 |

---

### 8.2 Conditions for Approval

The following conditions must be satisfied before OSD is authorized for use against the Treasury SBU/CUI application. Items are separated into pre-authorization requirements and post-authorization POAM commitments.

#### Required Before Authorization (Go/No-Go Gates)

**Condition 1 — Error Log Review (addresses R-06)**
The OneStream application error logs must be reviewed for SBU/CUI content prior to authorization. If sensitive data fragments are found, a sanitization plan and coding standards remediation must be completed — or a formal written risk acceptance must be obtained from the Data Owner — before OSD is authorized to operate.

**Condition 2 — Vendor Data Agreement (addresses R-02)**
A Data Processing Agreement (DPA) or Information Sharing Agreement (ISA) with OneStream Software LLC must be confirmed or established before any Report Package is transmitted to OneStream Support. Until a governing agreement is in place, use of the Report Package feature must be suspended and documented as prohibited in operating procedures.

**Condition 3 — Transmission Controls (addresses R-02, R-08)**
A documented procedure must be established requiring: (a) encrypted transmission channel for all Report Package files sent externally, and (b) two-administrator approval before any Report Package is transmitted to OneStream Support.

**Condition 4 — Change Management Authorization (addresses R-05)**
The Snapshot Automation OSD Task Scheduler job, which is created automatically during OSD setup, must be submitted through the formal change management process and approved before OSD is deployed to production. If setup has already been completed, the task must be submitted retroactively and approved or disabled pending approval.

#### Required Within 90 Days of Authorization (POAM)

| # | Action | Owner |
|---|---|---|
| P-1 | Evaluate whether `VIEW SERVER STATE` SQL permission can be scoped to the minimum necessary DMVs; document finding regardless of outcome (R-03) | DBA / Security Architecture |
| P-2 | Confirm OSD activities generate discrete audit records captured by SIEM at sufficient granularity (R-07) | Security Operations |
| P-3 | Conduct formal least-privilege review of OSD security role population; document justification for each user (R-01, R-08) | IAM / System Owner |
| P-4 | Update the System Security Plan to reflect the single-application operational constraint and the Framework database cross-application technical capability (R-04) | Security Architecture |
| P-5 | Establish a coding standard prohibiting logging of SBU/CUI-adjacent values in OneStream exception handlers (R-06 long-term) | Application Development / Security Architecture |

---

### 8.3 Security Architecture Recommendation

Based on the findings of this assessment, **Security Architecture does not recommend authorization** of OSD in the Treasury SBU/CUI environment until the four conditions in Section 8.2 are satisfied.

The two blocking risks — R-02 (Report Package external disclosure) and R-06 (error log SBU/CUI exposure) — represent gaps in governance and process controls surrounding the tool's use, not fundamental flaws in OSD's core monitoring capabilities. The tool itself provides legitimate and useful system administration value. Once the four pre-authorization conditions are met, the remaining risks are manageable through the POAM commitments above.

Upon satisfaction of all four conditions, Security Architecture **recommends conditional authorization** with the 90-day POAM items tracked to closure through the organization's risk management process.

---

## Appendix A: Risk Rating Methodology

Risk ratings are derived using a qualitative 5×5 matrix per NIST SP 800-30 Rev. 1. Likelihood and Impact are each scored 1–5; Risk Score = Likelihood × Impact.

**Likelihood:** 1 = Very Low (highly unlikely given existing controls) → 5 = Very High (near-certain; no meaningful deterrence)

**Impact:** 1 = Very Low (negligible, no SBU/CUI affected) → 5 = Very High (widespread SBU/CUI disclosure, regulatory action likely)

| Score | Rating |
|---|---|
| 1–4 | Low |
| 5–9 | Moderate |
| 10–14 | High |
| 15–25 | Critical |

No risks in this assessment were rated Critical under the current assumed control baseline.

---

## Appendix B: References

| Reference | Title |
|---|---|
| NIST SP 800-30 Rev. 1 | Guide for Conducting Risk Assessments |
| NIST SP 800-53 Rev. 5 | Security and Privacy Controls for Information Systems and Organizations |
| NIST SP 800-171 Rev. 2 | Protecting Controlled Unclassified Information in Nonfederal Systems and Organizations |
| 32 CFR Part 2002 | Controlled Unclassified Information (NARA/ISOO implementation rule) |
| Executive Order 13556 | Controlled Unclassified Information (November 4, 2010) |
| OneStream OSD Guide | System Diagnostics Guide, PV8.5.0 SV111 — documentation.onestream.com |

---

