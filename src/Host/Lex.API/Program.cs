using Lex.Infrastructure;
using Lex.Module.DiaryManagement;
using Lex.Module.Scheduling;
using Lex.Module.LessonManagement;
using Lex.Module.AssessmentCreation;
using Lex.Module.AssessmentDelivery;
using Lex.Module.GoogleIntegration;
using Lex.Module.FileProcessing;
using Lex.Module.ImportExport;
using Lex.Module.ObjectStorage;
using Lex.Module.Reporting;
using Lex.Module.Notifications;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.AddLexInfrastructure();

builder.Services
    .AddDiaryManagementModule(builder.Configuration)
    .AddSchedulingModule(builder.Configuration)
    .AddLessonManagementModule(builder.Configuration)
    .AddAssessmentCreationModule(builder.Configuration)
    .AddAssessmentDeliveryModule(builder.Configuration)
    .AddGoogleIntegrationModule(builder.Configuration)
    .AddFileProcessingModule(builder.Configuration)
    .AddImportExportModule(builder.Configuration)
    .AddObjectStorageModule(builder.Configuration)
    .AddReportingModule(builder.Configuration)
    .AddNotificationsModule(builder.Configuration);

builder.Services.AddReverseProxy().LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));
builder.Services.AddOpenApi();

var app = builder.Build();

app.UseSerilogRequestLogging();
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment()) app.MapOpenApi();

app.MapHealthChecks("/healthz");
app.MapHealthChecks("/readyz");
app.MapReverseProxy();

app.Run();
