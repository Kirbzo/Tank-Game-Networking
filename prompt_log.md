# Prompt log

Dates use America/Regina. IDs are assigned in conversation order. Historical entries are reconstructed from the visible conversation and the dated documentation record; no runtime results are inferred. Historical prompt path references have been normalized to source filenames for portability; other wording is preserved.

## P001 ? October 13, 2026

Prompt:

> create a readme and agents.md file based on the requirements. Do not alter or change anything outside the Codex for COMP214 folder and only add the readme and agents.md files into the folder with an extra text file describing what your thought process. Also, do not change the Requirements Document pdf and just read from it
>
> Requirements Documents is in the file path: Requirements Document.pdf

Result: created README.md, AGENTS.md, and documentation_rationale.txt based on the earlier PDF. The prior task recorded an unchanged PDF checksum. These files are now located in the COMP214 subfolder.

Associated status.md: none existed at that time; requirement tracking was introduced by the updated DOCX. Historical snapshot: documentation created; no game implementation verified.

## P002 ? October 16, 2026

Prompt:

> read the updated requirements docs located in Requirements Document and update the current AGENTS.md and README.md and create any extra files that come with the requirements docs.

Result: read Requirements Document.docx, updated README.md and AGENTS.md, and created status.md and this prompt log. Documented the revised hosting-only alpha, disabled Join until WP2, AR5 scope restriction, and source ambiguities. Preserved the historical rationale and source document.

Associated status.md: [status.md](status.md), revision S-2026-10-16-01. Snapshot: AR1?AR4 and FR1?FR12 not implemented; AR5 unverified; FR13?FR15 complete as documentation deliverables.

Validation: checked all 20 requirement IDs in README.md and status.md, relative links, unchanged source checksum, and that only the four intended documentation files changed. No runnable project is present; no gameplay tests performed.

## P003 - October 16, 2026

Prompt:

> update any places that spesifies a filepath on my local machine and change it to make it possible on any machine

Result: replaced machine-specific absolute paths and Downloads assumptions across README.md, AGENTS.md, status.md, prompt_log.md, and documentation_rationale.txt. Project paths now resolve from the repository root; the current requirements document is referenced by its repository-relative path, `MoozeTanks/Requirements Document.docx`. Historical external sources are identified by filename. Historical prompt paths were normalized with an explicit note.

Associated status.md: [status.md](status.md), revision S-2026-10-16-02. Requirement completion statuses remain unchanged.

Validation: scanned project files (excluding Git metadata) for machine-specific paths, verified local Markdown links and all 20 requirement IDs, and checked that changes were limited to the five documentation files. Source requirements documents were not modified. No runtime tests were needed.
