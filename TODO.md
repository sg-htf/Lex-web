This is a checklist — pure prose/list output, no need for a docx. Let me put together a comprehensive, well-reasoned sequential list based on everything I know about Lex.
The sequence follows a few rules: foundational layers before dependent modules, load-bearing SharedKernel pieces before anything that consumes them, write-path before read-path, and simpler modules before complex ones (so you build confidence and patterns early).

Lex — Sequential Implementation Checklist
Phase 0 — Foundation (nothing works without this)
	∙	DECIDED - Garage used as primary always - Finalize and write ADR-013 (object storage dual-provider design: PostgreSQL bytea + Garage, metadata model, auth model, migration path)
	∙	DONE - Stabilize BlockContent model in SharedKernel — define the base block types (text, image, embedded diagram, custom block), versioning strategy, and serialization contract before any module consumes it
	∙	DONE - Define Result<T> and Error types in SharedKernel with all error categories (NotFound, Validation, Forbidden, Conflict, Infrastructure)
	∙	Define IDomainEvent base interface and event envelope (correlation ID, timestamp, source module) in SharedKernel
	∙	Define ICurrentUser service interface in SharedKernel (userId, roles, tenantId)
	∙	Write IObjectStorageService / IFileStorageService adapter interfaces in SharedKernel per ADR-002
	∙	Implement PostgreSQL bytea storage provider in ObjectStorage module infrastructure
	∙	Implement Garage (S3-compatible) storage provider in ObjectStorage module infrastructure, behind the same adapter interface
	∙	Write file_records metadata table migration and repository in ObjectStorage module (provider-agnostic)
	∙	Implement FileController streaming endpoint — all file access mediated through API with permission check before byte delivery
	∙	Write architecture tests covering all project reference rules from the architecture reference (this enforces the boundary rules on every CI run going forward)

Phase 1 — Auth & Identity wiring
	∙	Write spec for Keycloak realm bootstrap — default realm JSON, client config, roles (Teacher, Admin, Student), claim mappings
	∙	Define permission constants structure convention (one static class per module’s Core project)
	∙	Spec and implement ICurrentUser concrete implementation reading from JWT claims in YourApp.Infrastructure
	∙	Spec role-to-policy mapping in YourApp.Infrastructure (which roles map to which ASP.NET Core policy names)
	∙	Write install.sh Keycloak bootstrap step spec — what the script must configure automatically on first run

Phase 2 — Scheduling module (foundational, everything references it)
Scheduling is load-bearing because DiaryManagement, LessonManagement, and AssessmentDelivery all depend on the concept of a scheduled period/slot.
	∙	Spec Scheduling domain model — Period, Slot, Class, Classroom, AcademicYear, Term entities and their relationships
	∙	Spec commands: CreateAcademicYear, CreateTerm, CreatePeriod, AssignClassToSlot, UpdateSlot
	∙	Spec queries: GetScheduleForClass, GetScheduleForTeacher, GetPeriodsForDate
	∙	Spec published events: SlotAssignedEvent, SlotRemovedEvent, AcademicYearCreatedEvent
	∙	Define Scheduling database schema (scheduling.*) and write initial EF Core migration
	∙	Spec Scheduling API surface (REST routes, request/response shapes)
	∙	Spec Scheduling frontend views — weekly timetable grid, slot detail, teacher view vs class view

Phase 3 — DiaryManagement module
	∙	Spec DiaryEntry domain model — entry, subject, date, period reference (FK to Scheduling concept via ID only, no direct join), BlockContent body
	∙	Spec commands: CreateDiaryEntry, UpdateDiaryEntry, SubmitDiaryEntry, ApproveDiaryEntry
	∙	Spec queries: GetDiaryEntriesForClass, GetDiaryEntriesForDate, GetDiaryEntryById
	∙	Spec published events: DiaryEntrySubmittedEvent, DiaryEntryApprovedEvent
	∙	Define DiaryManagement database schema (diary.*) and initial migration
	∙	Spec file attachment flow — diary entries can have attachments; attachment upload/download routes through FileController in ObjectStorage
	∙	Spec DiaryManagement API surface
	∙	Spec DiaryManagement frontend views — diary feed, entry editor (Tiptap BlockContent renderer), submission flow, approval flow

Phase 4 — LessonManagement module
	∙	Spec Lesson domain model — LessonPlan, LessonResource, Subject reference, Scheduling slot reference, BlockContent body
	∙	Spec commands: CreateLessonPlan, UpdateLessonPlan, PublishLessonPlan, AttachResource
	∙	Spec queries: GetLessonPlanById, GetLessonPlansForSubject, GetLessonPlansForPeriod
	∙	Spec published events: LessonPlanPublishedEvent, LessonResourceAttachedEvent
	∙	Define LessonManagement database schema (lesson.*) and initial migration
	∙	Spec LessonManagement API surface
	∙	Spec LessonManagement frontend views — lesson plan editor (Tiptap), lesson library, resource panel

Phase 5 — AssessmentCreation module
	∙	Spec Assessment domain model — Assessment, Question (with question type variants: MCQ, short answer, essay, file upload), Section, QuestionBank
	∙	Spec commands: CreateAssessment, AddQuestion, UpdateQuestion, ReorderQuestions, PublishAssessment, ArchiveAssessment
	∙	Spec queries: GetAssessmentById, GetAssessmentQuestions, GetQuestionBank
	∙	Spec snapshot contract — exactly what gets snapshotted at publish time and the format AssessmentDelivery will consume (this is the handoff contract between the two modules)
	∙	Spec published events: AssessmentPublishedEvent (carries the full snapshot payload)
	∙	Define AssessmentCreation database schema (assessment_creation.*) and initial migration
	∙	Spec AssessmentCreation API surface
	∙	Spec AssessmentCreation frontend views — assessment builder (drag-and-drop question ordering with React Flow or custom list), question editor, question bank, publish flow

Phase 6 — AssessmentDelivery module
	∙	Spec AssessmentDelivery domain model — DeliverySession, Submission, SubmissionAnswer, SubmissionStatus (in-progress, submitted, graded)
	∙	Spec snapshot ingestion — consumer for AssessmentPublishedEvent, how the snapshot is stored in assessment_delivery.* schema
	∙	Spec commands: StartSession, SaveAnswer, SubmitSession, GradeSubmission, ReturnGradedSubmission
	∙	Spec queries: GetSessionForStudent, GetSubmissionById, GetSessionResults
	∙	Spec published events: AssessmentSubmittedEvent, AssessmentGradedEvent
	∙	Define AssessmentDelivery database schema (assessment_delivery.*) and initial migration — note snapshot tables are separate from creation tables
	∙	Spec timed assessment logic — countdown, auto-submit on expiry (async job pattern via MassTransit)
	∙	Spec AssessmentDelivery API surface
	∙	Spec AssessmentDelivery frontend views — student submission UI (question renderer per type), teacher grading view, results view

Phase 7 — FileProcessing module
	∙	Spec FileProcessing domain model — ProcessingJob, ProcessingStatus, ProcessingResult
	∙	Spec what processing means for each file type: PDF text extraction, image thumbnail generation, video transcoding (or deferral)
	∙	Spec commands: EnqueueProcessingJob (triggered by FileUploadedEvent from ObjectStorage)
	∙	Spec published events: FileProcessingCompletedEvent, FileProcessingFailedEvent
	∙	Spec async job pattern integration — long-running jobs use the 202 Accepted + SignalR push pattern
	∙	Define FileProcessing database schema (file_processing.*) and initial migration
	∙	Spec FileProcessing API surface (status query endpoint)

Phase 8 — Notifications module (cross-cutting)
	∙	Spec Notification domain model — Notification, NotificationChannel (in-app, email), NotificationTemplate, DeliveryStatus
	∙	Spec which domain events trigger notifications and what each notification says — map every *Event already specced to zero or more notification rules
	∙	Spec in-app notification delivery path (SignalR push to NotificationHub)
	∙	Spec email notification delivery path (SMTP via configured provider)
	∙	Spec commands: MarkNotificationRead, MarkAllRead, UpdateNotificationPreferences
	∙	Spec queries: GetNotificationsForUser (paged), GetUnreadCount
	∙	Define Notifications database schema (notifications.*) and initial migration
	∙	Spec Notifications API surface
	∙	Spec Notifications frontend views — notification drawer/bell, notification list, preference settings

Phase 9 — Reporting module (cross-cutting read model)
	∙	Spec which cross-module views are needed — list every dashboard, summary table, or report that requires data from more than one module
	∙	Spec read model tables for each cross-module view (denormalized, event-sourced from domain events)
	∙	Spec consumer list — one consumer per source event per read model that needs updating
	∙	Spec queries: all report/dashboard query handlers (read from reporting.* schema only)
	∙	Define Reporting database schema (reporting.*) and initial migration
	∙	Spec Reporting API surface
	∙	Spec Reporting frontend views — dashboard cards, summary tables, charts (if any)

Phase 10 — GoogleIntegration module
	∙	Spec adapter interface IGoogleCalendarService, IGoogleDriveService in GoogleIntegration Core (pure adapter, no domain logic)
	∙	Spec OAuth2 flow for per-teacher Google account linking (authorization code flow, token storage, refresh)
	∙	Spec Calendar sync — which Scheduling or DiaryManagement events trigger calendar writes
	∙	Spec Drive import/export — what can be imported from Drive (lesson resources, assessment files) and exported to Drive
	∙	Spec published events: GoogleSyncCompletedEvent, GoogleImportCompletedEvent
	∙	Spec resilience policy — circuit breaker, retry, graceful degradation when Google is unavailable (on-prem with no internet must not break)
	∙	Define GoogleIntegration database schema (google_integration.*) and initial migration (token storage)
	∙	Spec GoogleIntegration API surface (OAuth callback, sync trigger, status)
	∙	Spec GoogleIntegration frontend views — account link/unlink, sync status, import file picker

Phase 11 — ImportExport module
	∙	Spec what can be imported: lesson plans, assessments, diary templates — from CSV, DOCX, PDF, or Google Drive
	∙	Spec what can be exported: the same, plus results/reports as CSV or PDF
	∙	Spec orchestration flow — ImportExport is the most complex integration surface; map its event dependencies on FileProcessing, GoogleIntegration, and ObjectStorage explicitly
	∙	Spec commands: StartImport, StartExport, CancelJob
	∙	Spec published events: ImportCompletedEvent, ImportFailedEvent, ExportReadyEvent
	∙	Spec async job pattern — all import/export jobs use 202 Accepted + SignalR push for progress
	∙	Define ImportExport database schema (import_export.*) and initial migration
	∙	Spec ImportExport API surface
	∙	Spec ImportExport frontend views — import wizard, export options, job progress indicator, download link

Phase 12 — Frontend infrastructure (can be parallelized with Phase 1–3)
	∙	Spec and implement apiFetch wrapper in lib/api/client.ts with token attachment, ProblemDetails error normalization, 401 silent refresh, 403 handling
	∙	Spec and implement tokenManager in lib/auth/ (in-memory access token, httpOnly refresh cookie, silent refresh lifecycle)
	∙	Spec and implement middleware.ts auth guard — protected vs public routes, Keycloak redirect
	∙	Spec and implement SignalRProvider and connectionManager.ts — hub lifecycle, reconnect, token refresh on reconnect, cache invalidation on reconnect
	∙	Spec and implement useAuthStore (Zustand) — current user identity, decoded JWT claims, auth status
	∙	Spec and implement useSignalRStore (Zustand) — connection status per hub
	∙	Spec and implement usePermissions() hook — reads claims from auth store, exposes permission check interface
	∙	Spec and implement useAsyncJob() hook — subscribes to JobStatusHub, returns status for a given jobId
	∙	Spec and implement app shell layout — nav, sidebar, notification bell, user menu, connection status indicator
	∙	Spec and implement PWA manifest and service worker — icons, display: standalone, cache strategies, offline fallback, update banner
	∙	Spec and implement DocumentEditor component (Tiptap) — toolbar, auto-save hook, save status display, DiagramBlock extension
	∙	Spec and implement DiagramCanvas component (React Flow) — base canvas, toolbar, custom node chrome, useDiagramSync for SignalR updates
	∙	Spec and implement PresentationViewer component — full-screen shell, keyboard nav, Framer Motion transitions, slide renderer
	∙	Spec MSW handler baseline — mirror every API endpoint as it’s specced, so frontend tests are never blocked by backend availability

Phase 13 — Observability & ops hardening
	∙	Spec custom business metrics per module — list every counter, histogram, and gauge each module should emit (follow module.{name}.{metric} convention)
	∙	Spec dead-letter queue health check — one per MassTransit consumer, surfaced as degraded health check
	∙	Spec module-level readiness checks — what each module checks in /readyz (its own DB schema, its own consumers)
	∙	Write backup.sh spec — pg_dump per-module schema coverage, Keycloak realm export, Seq volume, restore ordering
	∙	Write upgrade.sh spec — migration-first ordering, rollback abort condition, post-upgrade readiness check
	∙	Spec air-gapped install — docker save/load flow, offline Keycloak/Seq config, verification step
	∙	Write end-to-end install walkthrough (README-install.md spec) — what an institution operator sees from download to first login

Phase 14 — Integration and E2E tests
	∙	Write integration test baseline for each module: real Postgres via Testcontainers, MassTransit in-memory harness, WireMock for external HTTP
	∙	Write cross-module integration tests for the critical event chains: DiaryEntry submitted → Notification sent, Assessment published → Delivery session created, File uploaded → FileProcessing completed
	∙	Write ImportExport integration tests — the most complex orchestration surface; cover happy path and failure/retry paths
	∙	Write Playwright E2E smoke tests (optional but high value): login → create diary entry → submit → verify notification received
