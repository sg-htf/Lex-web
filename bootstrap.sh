#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh
# One-shot scaffold for the Lex platform — modular monolith on .NET 8.
#
# Run ONCE in an empty directory (or a fresh git repo):
#   chmod +x bootstrap.sh && ./bootstrap.sh
#
# What this creates:
#   ├── Lex.sln + global.json + .editorconfig + .gitignore
#   ├── src/Core/          SharedKernel, Infrastructure
#   ├── src/Host/          Lex.API (entry point)
#   ├── src/Modules/       11 domain modules (Core + Infrastructure each)
#   ├── tests/             11 module test projects + ArchitectureTests + IntegrationTests
#   ├── client/            Next.js 15 + TypeScript + Tailwind + shadcn-ready
#   ├── infra/             docker-compose.yml, .env.template, install/upgrade/backup scripts
#   ├── .github/workflows/ ci.yml, cd-staging.yml, cd-release.yml, dependabot.yml
#   └── docs/adr/          ready for ADR files
#
# Prerequisites:
#   - .NET 8 SDK      https://dotnet.microsoft.com/download
#   - Node.js 20+     https://nodejs.org
#   - git             https://git-scm.com
#   - docker          (needed to RUN the stack, not to scaffold)
# =============================================================================

set -euo pipefail

APP="Lex"
APP_LOWER="lex"

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}==>${RESET} $*"; }
success() { echo -e "${GREEN}  ✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}  !${RESET} $*"; }
section() { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}\n"; }

# ── Pre-flight ────────────────────────────────────────────────────────────────
section "Pre-flight checks"

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}ERROR:${RESET} '$1' not found. $2"; exit 1
  fi
  success "$1  ($(command -v "$1"))"
}

check_cmd dotnet "Install .NET 8 SDK: https://dotnet.microsoft.com/download"
check_cmd node   "Install Node.js 20+: https://nodejs.org"
check_cmd npm    "Comes with Node.js"
check_cmd git    "Install git: https://git-scm.com"

DOTNET_MAJOR=$(dotnet --version | cut -d. -f1)
if [[ "$DOTNET_MAJOR" -lt 8 ]]; then
  echo -e "${RED}ERROR:${RESET} .NET 8+ required. Found: $(dotnet --version)"; exit 1
fi

info "dotnet $(dotnet --version) | node $(node --version)"

# ── Git repo ──────────────────────────────────────────────────────────────────
section "Git repository"
if [[ ! -d ".git" ]]; then git init; success "git init"; else warn "git repo already initialised"; fi

# ── Solution root files ───────────────────────────────────────────────────────
section ".NET solution"

dotnet new globaljson --sdk-version "$(dotnet --version)" --roll-forward latestMinor --force
success "global.json"

dotnet new sln --name "$APP" --output . --force
success "$APP.sln"

cat > .editorconfig << 'EDITORCONFIG'
root = true
[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
[*.{csproj,props,targets,yml,yaml,json}]
indent_size = 2
[*.{ts,tsx,js,jsx,css}]
indent_size = 2
[Makefile]
indent_style = tab
EDITORCONFIG
success ".editorconfig"

cat > .gitignore << 'GITIGNORE'
bin/
obj/
*.user
.vs/
.idea/
TestResults/
coverage/
.env
*.env.local
secrets/
node_modules/
.next/
.turbo/
dist/
.DS_Store
Thumbs.db
GITIGNORE
success ".gitignore"

# ── Directory skeleton ────────────────────────────────────────────────────────
section "Directory skeleton"

for d in \
  "src/Host/$APP.API" \
  "src/Core/$APP.SharedKernel" \
  "src/Core/$APP.Infrastructure" \
  "src/Modules" \
  "tests/$APP.ArchitectureTests" \
  "tests/$APP.IntegrationTests" \
  "client" \
  "infra/k8s" \
  "infra/scripts" \
  "infra/keycloak" \
  "docs/adr/client" \
  ".github/workflows"; do
  mkdir -p "$d" && success "  $d/"
done

# ── SharedKernel ──────────────────────────────────────────────────────────────
section "SharedKernel"

SK="src/Core/$APP.SharedKernel"
dotnet new classlib --name "$APP.SharedKernel" --output "$SK" --framework net10.0 --force
rm -f "$SK/Class1.cs"

cat > "$SK/$APP.SharedKernel.csproj" << 'CSPROJ'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="MediatR" Version="12.*" />
  </ItemGroup>
</Project>
CSPROJ

mkdir -p "$SK/Abstractions" "$SK/Primitives" "$SK/Domain"

cat > "$SK/Abstractions/IDomainEvent.cs" << 'CS'
namespace Lex.SharedKernel.Abstractions;
/// <summary>
/// Marker for all domain events. Events are used for side-effects and
/// cross-module communication — NOT as the source of truth for state.
/// </summary>
public interface IDomainEvent
{
    Guid CorrelationId { get; }
    DateTimeOffset OccurredAt { get; }
}
CS

cat > "$SK/Abstractions/ICurrentUser.cs" << 'CS'
namespace Lex.SharedKernel.Abstractions;
public interface ICurrentUser
{
    Guid Id { get; }
    string Email { get; }
    string[] Roles { get; }
    string[] Permissions { get; }
    bool IsAuthenticated { get; }
    bool HasPermission(string permission);
}
CS

cat > "$SK/Primitives/Result.cs" << 'CS'
namespace Lex.SharedKernel.Primitives;

/// <summary>
/// Railway-oriented result. All handlers return Result&lt;T&gt;.
/// Exceptions are reserved for unrecoverable infrastructure failures.
/// </summary>
public sealed record Result<T>
{
    public T? Value { get; }
    public Error? Error { get; }
    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;

    private Result(T value)     { Value = value; IsSuccess = true; }
    private Result(Error error) { Error = error; IsSuccess = false; }

    public static Result<T> Success(T value)     => new(value);
    public static Result<T> Failure(Error error) => new(error);
    public static implicit operator Result<T>(T value)     => Success(value);
    public static implicit operator Result<T>(Error error) => Failure(error);
}

public sealed record Error(string Code, string Message, ErrorType Type = ErrorType.Failure)
{
    public static Error NotFound(string code, string message)   => new(code, message, ErrorType.NotFound);
    public static Error Validation(string code, string message) => new(code, message, ErrorType.Validation);
    public static Error Conflict(string code, string message)   => new(code, message, ErrorType.Conflict);
    public static Error Unauthorized(string code, string message) => new(code, message, ErrorType.Unauthorized);
}

public enum ErrorType { Failure, NotFound, Validation, Conflict, Unauthorized }
CS

cat > "$SK/Primitives/Entity.cs" << 'CS'
using Lex.SharedKernel.Abstractions;

namespace Lex.SharedKernel.Primitives;

public abstract class Entity
{
    public Guid Id { get; protected set; } = Guid.NewGuid();
    private readonly List<IDomainEvent> _domainEvents = [];
    public IReadOnlyList<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();
    protected void RaiseDomainEvent(IDomainEvent e) => _domainEvents.Add(e);
    public void ClearDomainEvents() => _domainEvents.Clear();
}

public abstract class AggregateRoot : Entity { }
CS

# Block content model — shared between Lesson and DiaryEntry
cat > "$SK/Domain/BlockContent.cs" << 'CS'
namespace Lex.SharedKernel.Domain;

/// <summary>
/// Portable block-list content model.
/// Used by LessonManagement and DiaryManagement.
/// Rendered as document / outline / diagram / mind-map depending on block types.
/// </summary>
public sealed record BlockContent(IReadOnlyList<ContentBlock> Blocks)
{
    public static BlockContent Empty() => new([]);
}

public sealed record ContentBlock(
    Guid   Id,
    string Type,       // "paragraph"|"heading"|"bullet"|"node"|"edge"|"image"
    string? Text,
    Guid?  ParentId,   // null = root; set for nested/diagram children
    int    Order,
    IReadOnlyDictionary<string, string>? Metadata  // extensible per block type
);
CS

dotnet sln add "$SK/$APP.SharedKernel.csproj"
success "SharedKernel"

# ── Infrastructure ────────────────────────────────────────────────────────────
section "Infrastructure"

INFRA="src/Core/$APP.Infrastructure"
dotnet new classlib --name "$APP.Infrastructure" --output "$INFRA" --framework net10.0 --force
rm -f "$INFRA/Class1.cs"

cat > "$INFRA/$APP.Infrastructure.csproj" << 'CSPROJ'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="..\..\Core\Lex.SharedKernel\Lex.SharedKernel.csproj" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore"                  Version="8.*" />
    <PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL"          Version="8.*" />
    <PackageReference Include="MassTransit.RabbitMQ"                           Version="8.*" />
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer"  Version="8.*" />
    <PackageReference Include="Yarp.ReverseProxy"                              Version="2.*" />
    <PackageReference Include="Serilog.AspNetCore"                             Version="8.*" />
    <PackageReference Include="Serilog.Sinks.Seq"                              Version="6.*" />
    <PackageReference Include="OpenTelemetry.Extensions.Hosting"               Version="1.*" />
    <PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore"       Version="1.*" />
    <PackageReference Include="OpenTelemetry.Instrumentation.EntityFrameworkCore" Version="1.*" />
    <PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol"   Version="1.*" />
    <PackageReference Include="Microsoft.AspNetCore.SignalR.StackExchangeRedis" Version="8.*" />
    <PackageReference Include="Minio"                                          Version="6.*" />
  </ItemGroup>
</Project>
CSPROJ

mkdir -p "$INFRA/Persistence" "$INFRA/Messaging" "$INFRA/Auth" "$INFRA/Observability"

cat > "$INFRA/InfrastructureServiceRegistration.cs" << 'CS'
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Serilog;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;

namespace Lex.Infrastructure;

public static class InfrastructureServiceRegistration
{
    public static WebApplicationBuilder AddLexInfrastructure(this WebApplicationBuilder builder)
    {
        builder.AddLexSerilog().AddLexOpenTelemetry().AddLexMassTransit()
               .AddLexKeycloak().AddLexRedis().AddLexMinio().AddLexHealthChecks();
        return builder;
    }

    private static WebApplicationBuilder AddLexSerilog(this WebApplicationBuilder builder)
    {
        builder.Host.UseSerilog((ctx, lc) => lc
            .ReadFrom.Configuration(ctx.Configuration)
            .Enrich.FromLogContext()
            .Enrich.WithProperty("Application", "Lex")
            .WriteTo.Console()
            .WriteTo.Seq(ctx.Configuration["Observability:SeqUrl"] ?? "http://seq:5341"));
        return builder;
    }

    private static WebApplicationBuilder AddLexOpenTelemetry(this WebApplicationBuilder builder)
    {
        builder.Services.AddOpenTelemetry()
            .ConfigureResource(r => r.AddService("Lex"))
            .WithTracing(t => t
                .AddAspNetCoreInstrumentation()
                .AddEntityFrameworkCoreInstrumentation()
                .AddSource("MassTransit")
                .AddOtlpExporter(o => o.Endpoint = new Uri(
                    builder.Configuration["Observability:OtlpEndpoint"] ?? "http://seq:5341/ingest/otlp")))
            .WithMetrics(m => m
                .AddAspNetCoreInstrumentation()
                .AddRuntimeInstrumentation()
                .AddOtlpExporter());
        return builder;
    }

    private static WebApplicationBuilder AddLexMassTransit(this WebApplicationBuilder builder)
    {
        builder.Services.AddMassTransit(x =>
        {
            x.SetKebabCaseEndpointNameFormatter();
            x.UsingRabbitMq((ctx, cfg) =>
            {
                cfg.Host(builder.Configuration["RabbitMq:Host"] ?? "rabbitmq", h =>
                {
                    h.Username(builder.Configuration["RabbitMq:Username"] ?? "lex");
                    h.Password(builder.Configuration["RabbitMq:Password"] ?? "");
                });
                cfg.UseMessageRetry(r => r.Incremental(3, TimeSpan.FromMilliseconds(500), TimeSpan.FromSeconds(1)));
                cfg.UseDelayedRedelivery(r => r.Exponential(5, TimeSpan.FromSeconds(5), TimeSpan.FromMinutes(5), TimeSpan.FromSeconds(5)));
                cfg.ConfigureEndpoints(ctx);
            });
        });
        return builder;
    }

    private static WebApplicationBuilder AddLexKeycloak(this WebApplicationBuilder builder)
    {
        builder.Services.AddAuthentication().AddJwtBearer(o =>
        {
            o.Authority = builder.Configuration["Keycloak:Authority"];
            o.Audience  = builder.Configuration["Keycloak:ClientId"];
            o.RequireHttpsMetadata = false;
            o.Events = new() { OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) && ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                    ctx.Token = token;
                return Task.CompletedTask;
            }};
        });
        builder.Services.AddAuthorization();
        return builder;
    }

    private static WebApplicationBuilder AddLexRedis(this WebApplicationBuilder builder)
    {
        builder.Services.AddSignalR()
            .AddStackExchangeRedis(builder.Configuration.GetConnectionString("Redis") ?? "redis:6379");
        return builder;
    }

    private static WebApplicationBuilder AddLexMinio(this WebApplicationBuilder builder)
    {
        builder.Services.AddSingleton<global::Minio.IMinioClient>(_ =>
            new global::Minio.MinioClient()
                .WithEndpoint(builder.Configuration["MinIO:Endpoint"] ?? "minio:9000")
                .WithCredentials(
                    builder.Configuration["MinIO:AccessKey"] ?? "",
                    builder.Configuration["MinIO:SecretKey"] ?? "")
                .Build());
        return builder;
    }

    private static WebApplicationBuilder AddLexHealthChecks(this WebApplicationBuilder builder)
    {
        builder.Services.AddHealthChecks()
            .AddNpgsql(builder.Configuration.GetConnectionString("Default") ?? "", name: "postgres")
            .AddRedis(builder.Configuration.GetConnectionString("Redis") ?? "redis:6379", name: "redis");
        return builder;
    }
}
CS

dotnet sln add "$INFRA/$APP.Infrastructure.csproj"
success "Infrastructure"

# ── API Host ──────────────────────────────────────────────────────────────────
section "API Host"

API="src/Host/$APP.API"
dotnet new webapi --name "$APP.API" --output "$API" --framework net10.0 --no-openapi --force
rm -f "$API/WeatherForecast.cs" 2>/dev/null || true

cat > "$API/$APP.API.csproj" << 'CSPROJ'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <UserSecretsId>lex-api-dev</UserSecretsId>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="..\..\Core\Lex.Infrastructure\Lex.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.DiaryManagement\Lex.Module.DiaryManagement.Infrastructure\Lex.Module.DiaryManagement.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.Scheduling\Lex.Module.Scheduling.Infrastructure\Lex.Module.Scheduling.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.LessonManagement\Lex.Module.LessonManagement.Infrastructure\Lex.Module.LessonManagement.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.AssessmentCreation\Lex.Module.AssessmentCreation.Infrastructure\Lex.Module.AssessmentCreation.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.AssessmentDelivery\Lex.Module.AssessmentDelivery.Infrastructure\Lex.Module.AssessmentDelivery.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.GoogleIntegration\Lex.Module.GoogleIntegration.Infrastructure\Lex.Module.GoogleIntegration.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.FileProcessing\Lex.Module.FileProcessing.Infrastructure\Lex.Module.FileProcessing.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.ImportExport\Lex.Module.ImportExport.Infrastructure\Lex.Module.ImportExport.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.ObjectStorage\Lex.Module.ObjectStorage.Infrastructure\Lex.Module.ObjectStorage.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.Reporting\Lex.Module.Reporting.Infrastructure\Lex.Module.Reporting.Infrastructure.csproj" />
    <ProjectReference Include="..\..\Modules\Lex.Module.Notifications\Lex.Module.Notifications.Infrastructure\Lex.Module.Notifications.Infrastructure.csproj" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="Yarp.ReverseProxy"          Version="2.*" />
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="8.*" />
    <PackageReference Include="Scalar.AspNetCore"           Version="1.*" />
  </ItemGroup>
</Project>
CSPROJ

cat > "$API/Program.cs" << 'CS'
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
CS

# appsettings
cat > "$API/appsettings.json" << 'JSON'
{
  "ConnectionStrings": {
    "Default": "Host=postgres;Port=5432;Database=lex;Username=lex;Password=${DB_PASSWORD}",
    "Redis": "redis:6379"
  },
  "RabbitMq": { "Host": "rabbitmq", "Username": "lex", "Password": "${RABBITMQ_PASSWORD}" },
  "Keycloak": { "Authority": "http://keycloak:8080/realms/lex", "ClientId": "lex-api" },
  "MinIO": { "Endpoint": "minio:9000", "AccessKey": "${MINIO_ACCESS_KEY}", "SecretKey": "${MINIO_SECRET_KEY}" },
  "Observability": { "SeqUrl": "http://seq:5341", "OtlpEndpoint": "http://seq:5341/ingest/otlp" },
  "ReverseProxy": {
    "Routes": {
      "diary-route":       { "ClusterId": "api", "Match": { "Path": "/api/diary/{**catch-all}" } },
      "scheduling-route":  { "ClusterId": "api", "Match": { "Path": "/api/scheduling/{**catch-all}" } },
      "lessons-route":     { "ClusterId": "api", "Match": { "Path": "/api/lessons/{**catch-all}" } },
      "assessments-route": { "ClusterId": "api", "Match": { "Path": "/api/assessments/{**catch-all}" } },
      "delivery-route":    { "ClusterId": "api", "Match": { "Path": "/api/delivery/{**catch-all}" } },
      "files-route":       { "ClusterId": "api", "Match": { "Path": "/api/files/{**catch-all}" } },
      "storage-route":     { "ClusterId": "api", "Match": { "Path": "/api/storage/{**catch-all}" } },
      "reporting-route":   { "ClusterId": "api", "Match": { "Path": "/api/reporting/{**catch-all}" } },
      "web-route":         { "ClusterId": "web", "Match": { "Path": "/{**catch-all}" } }
    },
    "Clusters": {
      "api": { "Destinations": { "api/0": { "Address": "http://localhost:5000" } } },
      "web": { "Destinations": { "web/0": { "Address": "http://web:3000" } } }
    }
  }
}
JSON

cat > "$API/appsettings.Development.json" << 'JSON'
{
  "ConnectionStrings": {
    "Default": "Host=localhost;Port=5432;Database=lex_dev;Username=lex;Password=devpassword",
    "Redis": "localhost:6379"
  },
  "RabbitMq": { "Host": "localhost" },
  "Keycloak": { "Authority": "http://localhost:8080/realms/lex" },
  "MinIO": { "Endpoint": "localhost:9000", "AccessKey": "minioadmin", "SecretKey": "minioadmin" },
  "Observability": { "SeqUrl": "http://localhost:5341" }
}
JSON

cat > "$API/Dockerfile" << 'DOCKERFILE'
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish src/Host/Lex.API/Lex.API.csproj -c Release -o /app/publish --no-self-contained

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD curl -f http://localhost:8080/healthz || exit 1
ENTRYPOINT ["dotnet", "Lex.API.dll"]
DOCKERFILE

dotnet sln add "$API/$APP.API.csproj"
success "API host"

# ── Domain modules ────────────────────────────────────────────────────────────
section "Domain modules (11)"

MODULES=(
  "DiaryManagement"
  "Scheduling"
  "LessonManagement"
  "AssessmentCreation"
  "AssessmentDelivery"
  "GoogleIntegration"
  "FileProcessing"
  "ImportExport"
  "ObjectStorage"
  "Reporting"
  "Notifications"
)

scaffold_module() {
  local MOD="$1"
  local MOD_LOWER="${MOD,,}"
  local BASE="src/Modules/$APP.Module.$MOD"
  local CORE="$BASE/$APP.Module.$MOD.Core"
  local INFRA="$BASE/$APP.Module.$MOD.Infrastructure"

  mkdir -p "$CORE/Features" "$CORE/Domain" "$CORE/Abstractions"
  mkdir -p "$INFRA/Persistence" "$INFRA/Consumers" "$INFRA/ExternalApis"

  cat > "$CORE/$APP.Module.$MOD.Core.csproj" << CSPROJ
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <!-- Core may ONLY reference SharedKernel. No EF, no MassTransit, no other modules. -->
  <ItemGroup>
    <ProjectReference Include="..\..\..\Core\Lex.SharedKernel\Lex.SharedKernel.csproj" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="MediatR"           Version="12.*" />
    <PackageReference Include="FluentValidation"  Version="11.*" />
  </ItemGroup>
</Project>
CSPROJ

  cat > "$INFRA/$APP.Module.$MOD.Infrastructure.csproj" << CSPROJ
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <!-- Infrastructure may NOT reference other Module.*.Core or Module.*.Infrastructure -->
  <ItemGroup>
    <ProjectReference Include="..\$APP.Module.$MOD.Core\$APP.Module.$MOD.Core.csproj" />
    <ProjectReference Include="..\..\..\Core\Lex.Infrastructure\Lex.Infrastructure.csproj" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore"          Version="8.*" />
    <PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL"  Version="8.*" />
    <PackageReference Include="MassTransit.RabbitMQ"                   Version="8.*" />
    <PackageReference Include="Refit.HttpClientFactory"                Version="7.*" />
    <PackageReference Include="Microsoft.Extensions.Http.Resilience"   Version="8.*" />
  </ItemGroup>
</Project>
CSPROJ

  cat > "$CORE/${MOD}Permissions.cs" << CS
namespace Lex.Module.$MOD;
public static class ${MOD}Permissions
{
    private const string Prefix = "$MOD_LOWER";
    public const string View   = \$"{Prefix}.view";
    public const string Create = \$"{Prefix}.create";
    public const string Edit   = \$"{Prefix}.edit";
    public const string Delete = \$"{Prefix}.delete";
}
CS

  cat > "$INFRA/Persistence/${MOD}DbContext.cs" << CS
using Microsoft.EntityFrameworkCore;
namespace Lex.Module.$MOD.Persistence;
public sealed class ${MOD}DbContext : DbContext
{
    public ${MOD}DbContext(DbContextOptions<${MOD}DbContext> options) : base(options) { }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("$MOD_LOWER");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(${MOD}DbContext).Assembly);
    }
}
CS

  cat > "$INFRA/${MOD}ServiceRegistration.cs" << CS
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.$MOD;
public static class ${MOD}ServiceRegistration
{
    public static IServiceCollection Add${MOD}Module(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.$MOD.Persistence.${MOD}DbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(${MOD}ServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(${MOD}Permissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(${MOD}Permissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
CS

  dotnet sln add "$CORE/$APP.Module.$MOD.Core.csproj"
  dotnet sln add "$INFRA/$APP.Module.$MOD.Infrastructure.csproj"
  success "$MOD"
}

for MOD in "${MODULES[@]}"; do scaffold_module "$MOD"; done

# ── Test projects ─────────────────────────────────────────────────────────────
section "Test projects"

for MOD in "${MODULES[@]}"; do
  TEST="tests/$APP.Module.$MOD.Tests"
  mkdir -p "$TEST"
  cat > "$TEST/$APP.Module.$MOD.Tests.csproj" << CSPROJ
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="..\..\src\Modules\Lex.Module.$MOD\Lex.Module.$MOD.Core\Lex.Module.$MOD.Core.csproj" />
    <ProjectReference Include="..\..\src\Modules\Lex.Module.$MOD\Lex.Module.$MOD.Infrastructure\Lex.Module.$MOD.Infrastructure.csproj" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk"        Version="17.*" />
    <PackageReference Include="xunit"                         Version="2.*" />
    <PackageReference Include="xunit.runner.visualstudio"     Version="2.*" />
    <PackageReference Include="FluentAssertions"              Version="6.*" />
    <PackageReference Include="Moq"                           Version="4.*" />
    <PackageReference Include="Testcontainers.PostgreSql"     Version="3.*" />
    <PackageReference Include="WireMock.Net"                  Version="1.*" />
    <PackageReference Include="MassTransit.TestFramework"     Version="8.*" />
  </ItemGroup>
</Project>
CSPROJ
  dotnet sln add "$TEST/$APP.Module.$MOD.Tests.csproj"
  success "$MOD.Tests"
done

# Architecture tests
ARCH="tests/$APP.ArchitectureTests"
cat > "$ARCH/$APP.ArchitectureTests.csproj" << 'CSPROJ'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk"    Version="17.*" />
    <PackageReference Include="xunit"                     Version="2.*" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.*" />
    <PackageReference Include="NetArchTest.Rules"         Version="1.*" />
    <PackageReference Include="FluentAssertions"          Version="6.*" />
  </ItemGroup>
</Project>
CSPROJ

cat > "$ARCH/ModuleBoundaryTests.cs" << 'CS'
using NetArchTest.Rules;
using Xunit;
using FluentAssertions;

namespace Lex.ArchitectureTests;

/// <summary>
/// Enforces the project reference rules from the architecture reference (§2.2).
/// Runs on every CI build — boundary violations are caught before they compound.
/// </summary>
public sealed class ModuleBoundaryTests
{
    private static readonly string[] Modules =
    [
        "DiaryManagement", "Scheduling", "LessonManagement",
        "AssessmentCreation", "AssessmentDelivery", "GoogleIntegration",
        "FileProcessing", "ImportExport", "ObjectStorage",
        "Reporting", "Notifications"
    ];

    [Fact]
    public void ModuleCore_ShouldNotReference_EntityFramework()
    {
        foreach (var module in Modules)
        {
            var result = Types.InAssembly(GetCoreAssembly(module))
                .ShouldNot().HaveDependencyOn("Microsoft.EntityFrameworkCore").GetResult();
            result.IsSuccessful.Should().BeTrue($"{module}.Core must not reference EF Core");
        }
    }

    [Fact]
    public void ModuleCore_ShouldNotReference_MassTransit()
    {
        foreach (var module in Modules)
        {
            var result = Types.InAssembly(GetCoreAssembly(module))
                .ShouldNot().HaveDependencyOn("MassTransit").GetResult();
            result.IsSuccessful.Should().BeTrue($"{module}.Core must not reference MassTransit");
        }
    }

    [Fact]
    public void ModuleCore_ShouldNotReference_OtherModules()
    {
        foreach (var module in Modules)
        {
            foreach (var other in Modules.Where(m => m != module).Select(m => $"Lex.Module.{m}"))
            {
                var result = Types.InAssembly(GetCoreAssembly(module))
                    .ShouldNot().HaveDependencyOn(other).GetResult();
                result.IsSuccessful.Should().BeTrue($"{module}.Core must not reference {other}");
            }
        }
    }

    [Fact]
    public void Handlers_ShouldBeInternal()
    {
        foreach (var module in Modules)
        {
            var result = Types.InAssembly(GetCoreAssembly(module))
                .That().HaveNameEndingWith("Handler")
                .Should().NotBePublic().GetResult();
            result.IsSuccessful.Should().BeTrue($"Handlers in {module} should be internal");
        }
    }

    private static System.Reflection.Assembly GetCoreAssembly(string module) =>
        System.Reflection.Assembly.Load($"Lex.Module.{module}.Core");
}
CS

dotnet sln add "$ARCH/$APP.ArchitectureTests.csproj"
success "ArchitectureTests"

INT="tests/$APP.IntegrationTests"
cat > "$INT/$APP.IntegrationTests.csproj" << 'CSPROJ'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="..\..\src\Host\Lex.API\Lex.API.csproj" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk"              Version="17.*" />
    <PackageReference Include="xunit"                               Version="2.*" />
    <PackageReference Include="xunit.runner.visualstudio"           Version="2.*" />
    <PackageReference Include="FluentAssertions"                    Version="6.*" />
    <PackageReference Include="Testcontainers.PostgreSql"           Version="3.*" />
    <PackageReference Include="Testcontainers.RabbitMq"             Version="3.*" />
    <PackageReference Include="WireMock.Net"                        Version="1.*" />
    <PackageReference Include="Respawn"                             Version="6.*" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing"    Version="8.*" />
  </ItemGroup>
</Project>
CSPROJ
dotnet sln add "$INT/$APP.IntegrationTests.csproj"
success "IntegrationTests"

# ── Docker / infra ────────────────────────────────────────────────────────────
section "Docker Compose stack"

cat > "infra/docker-compose.yml" << 'YAML'
name: lex

services:
  api:
    image: ghcr.io/your-org/lex-api:${LEX_VERSION:-latest}
    restart: unless-stopped
    depends_on:
      postgres:  { condition: service_healthy }
      rabbitmq:  { condition: service_healthy }
      redis:     { condition: service_healthy }
      keycloak:  { condition: service_healthy }
    environment:
      ASPNETCORE_ENVIRONMENT: Production
      ASPNETCORE_URLS: http://+:8080
      ConnectionStrings__Default: "Host=postgres;Port=5432;Database=lex;Username=lex;Password=${DB_PASSWORD}"
      ConnectionStrings__Redis: "redis:6379"
      RabbitMq__Host: rabbitmq
      RabbitMq__Username: lex
      RabbitMq__Password: ${RABBITMQ_PASSWORD}
      Keycloak__Authority: "http://keycloak:8080/realms/lex"
      Keycloak__ClientId: lex-api
      MinIO__Endpoint: "minio:9000"
      MinIO__AccessKey: ${MINIO_ACCESS_KEY}
      MinIO__SecretKey: ${MINIO_SECRET_KEY}
      Observability__SeqUrl: "http://seq:5341"
    ports: ["443:8443", "80:8080"]
    networks: [lex-net]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 30s; timeout: 10s; retries: 3; start_period: 60s

  web:
    image: ghcr.io/your-org/lex-web:${LEX_VERSION:-latest}
    restart: unless-stopped
    environment:
      NODE_ENV: production
      NEXT_PUBLIC_APP_NAME: Lex
      NEXT_PUBLIC_KEYCLOAK_URL: ${KEYCLOAK_PUBLIC_URL}
      NEXT_PUBLIC_KEYCLOAK_REALM: lex
      NEXT_PUBLIC_KEYCLOAK_CLIENT_ID: lex-web
    networks: [lex-net]

  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment: { POSTGRES_DB: lex, POSTGRES_USER: lex, POSTGRES_PASSWORD: "${DB_PASSWORD}" }
    volumes: [pgdata:/var/lib/postgresql/data]
    networks: [lex-net]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U lex -d lex"]
      interval: 10s; timeout: 5s; retries: 5

  rabbitmq:
    image: rabbitmq:3-management-alpine
    restart: unless-stopped
    environment: { RABBITMQ_DEFAULT_USER: lex, RABBITMQ_DEFAULT_PASS: "${RABBITMQ_PASSWORD}" }
    volumes: [rabbitmq-data:/var/lib/rabbitmq]
    networks: [lex-net]
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 10s; timeout: 5s; retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    networks: [lex-net]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s; timeout: 3s; retries: 5

  keycloak:
    image: quay.io/keycloak/keycloak:24.0
    restart: unless-stopped
    command: ["start", "--optimized"]
    environment:
      KC_DB: postgres
      KC_DB_URL: "jdbc:postgresql://postgres:5432/lex"
      KC_DB_USERNAME: lex
      KC_DB_PASSWORD: ${DB_PASSWORD}
      KC_HOSTNAME: ${KEYCLOAK_PUBLIC_URL}
      KC_PROXY: edge
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD}
    volumes:
      - keycloak-data:/opt/keycloak/data
      - ./keycloak/lex-realm.json:/opt/keycloak/data/import/lex-realm.json:ro
    depends_on: { postgres: { condition: service_healthy } }
    networks: [lex-net]
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/health/ready || exit 1"]
      interval: 30s; timeout: 10s; retries: 5; start_period: 90s

  minio:
    image: minio/minio:RELEASE.2024-01-01T00-00-00Z
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment: { MINIO_ROOT_USER: "${MINIO_ACCESS_KEY}", MINIO_ROOT_PASSWORD: "${MINIO_SECRET_KEY}" }
    volumes: [minio-data:/data]
    networks: [lex-net]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s; timeout: 10s; retries: 3

  seq:
    image: datalust/seq:latest
    restart: unless-stopped
    environment: { ACCEPT_EULA: "Y" }
    volumes: [seq-data:/data]
    ports: ["8083:80"]
    networks: [lex-net]

volumes:
  pgdata:
  rabbitmq-data:
  keycloak-data:
  minio-data:
  seq-data:

networks:
  lex-net:
    driver: bridge
YAML
success "docker-compose.yml"

cat > "infra/docker-compose.override.yml" << 'YAML'
name: lex
services:
  api:
    build: { context: .., dockerfile: src/Host/Lex.API/Dockerfile }
    image: lex-api:dev
    environment: { ASPNETCORE_ENVIRONMENT: Development }
    ports: ["5000:8080"]
  web:
    build: { context: ../client, dockerfile: Dockerfile }
    image: lex-web:dev
    ports: ["3000:3000"]
  postgres:
    ports: ["5432:5432"]
  rabbitmq:
    ports: ["5672:5672", "15672:15672"]
  redis:
    ports: ["6379:6379"]
  keycloak:
    command: ["start-dev", "--import-realm"]
    ports: ["8080:8080"]
  minio:
    ports: ["9000:9000", "9001:9001"]
  seq:
    ports: ["5341:5341", "8082:80"]
YAML
success "docker-compose.override.yml"

cat > "infra/.env.template" << 'ENV'
# Lex Platform — copy to .env and fill in all values. Never commit .env.

LEX_VERSION=1.0.0

# Database
DB_PASSWORD=

# RabbitMQ
RABBITMQ_PASSWORD=

# Keycloak
KEYCLOAK_PUBLIC_URL=https://your-domain.com
KEYCLOAK_ADMIN_PASSWORD=

# MinIO
MINIO_ACCESS_KEY=
MINIO_SECRET_KEY=

# Google OAuth (optional — enables "Continue with Google" and gAPI integration)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# SMTP (for Notifications module)
SMTP_HOST=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM=noreply@your-institution.com
ENV
success ".env.template"

cat > "infra/keycloak/lex-realm.json" << 'JSON'
{
  "realm": "lex",
  "displayName": "Lex Platform",
  "enabled": true,
  "sslRequired": "external",
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "resetPasswordAllowed": true,
  "bruteForceProtected": true,
  "clients": [
    {
      "clientId": "lex-web",
      "name": "Lex Web",
      "enabled": true,
      "publicClient": true,
      "standardFlowEnabled": true,
      "directAccessGrantsEnabled": false,
      "attributes": { "pkce.code.challenge.method": "S256" },
      "redirectUris": ["https://*", "http://localhost:3000/*"],
      "webOrigins": ["https://*", "http://localhost:3000"]
    },
    {
      "clientId": "lex-api",
      "enabled": true,
      "publicClient": false,
      "serviceAccountsEnabled": true,
      "bearerOnly": true
    }
  ],
  "roles": {
    "realm": [
      { "name": "admin",   "description": "Platform administrator" },
      { "name": "teacher", "description": "Teaching staff" },
      { "name": "student", "description": "Student" }
    ]
  },
  "identityProviders": [{
    "alias": "google",
    "displayName": "Continue with Google",
    "providerId": "google",
    "enabled": false,
    "config": { "clientId": "${GOOGLE_CLIENT_ID}", "clientSecret": "${GOOGLE_CLIENT_SECRET}", "syncMode": "IMPORT" }
  }]
}
JSON
success "Keycloak realm config"

cat > "infra/scripts/install.sh" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

command -v docker &>/dev/null        || { echo "ERROR: docker not found."; exit 1; }
command -v docker compose &>/dev/null || { echo "ERROR: docker compose not found."; exit 1; }

[[ -f .env ]] || { cp .env.template .env; echo "Created .env — fill in values then re-run."; exit 0; }

source .env
for v in DB_PASSWORD RABBITMQ_PASSWORD KEYCLOAK_ADMIN_PASSWORD MINIO_ACCESS_KEY MINIO_SECRET_KEY; do
  [[ -n "${!v:-}" ]] || { echo "ERROR: $v not set in .env"; exit 1; }
done

docker compose pull
docker compose up -d postgres rabbitmq redis minio seq

echo "Waiting for infrastructure..."
for s in postgres rabbitmq redis; do
  for i in $(seq 1 30); do
    docker compose ps "$s" | grep -q "healthy" && break
    sleep 2; [[ $i -eq 30 ]] && { echo "ERROR: $s not healthy"; exit 1; }
  done
  echo "  ✓ $s"
done

echo "Starting Keycloak (may take 90s)..."
docker compose up -d keycloak
for i in $(seq 1 60); do
  docker compose ps keycloak | grep -q "healthy" && break
  sleep 3; [[ $i -eq 60 ]] && { echo "ERROR: Keycloak not healthy"; exit 1; }
done
echo "  ✓ keycloak"

docker compose up -d api
for i in $(seq 1 30); do
  curl -sf http://localhost:80/readyz &>/dev/null && break
  sleep 3; [[ $i -eq 30 ]] && { echo "ERROR: API /readyz failed"; exit 1; }
done
echo "  ✓ api"

docker compose up -d web
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Lex installed!"
echo "  App       : http://localhost"
echo "  Keycloak  : http://localhost:8080  (admin / ${KEYCLOAK_ADMIN_PASSWORD})"
echo "  MinIO     : http://localhost:9001  (${MINIO_ACCESS_KEY})"
echo "  Seq       : http://localhost:8083"
echo "  RabbitMQ  : http://localhost:15672"
echo ""
echo "  ⚠  Change Keycloak admin password immediately."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BASH
chmod +x "infra/scripts/install.sh"

cat > "infra/scripts/upgrade.sh" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
source .env
docker compose pull api web
docker compose run --rm api dotnet Lex.API.dll --migrate-only || { echo "Migration failed — aborting."; exit 1; }
docker compose up -d --no-deps api web
sleep 10
curl -sf http://localhost:80/readyz && echo "✓ Upgrade successful" || { echo "ERROR: /readyz failed after upgrade"; exit 1; }
BASH
chmod +x "infra/scripts/upgrade.sh"

cat > "infra/scripts/backup.sh" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
source .env
DIR="backups/$(date '+%Y%m%d_%H%M%S')"
mkdir -p "$DIR"
docker compose exec -T postgres pg_dump -U lex lex | gzip > "$DIR/postgres.sql.gz"
curl -su "lex:${RABBITMQ_PASSWORD}" http://localhost:15672/api/definitions > "$DIR/rabbitmq.json"
echo "✓ Backup: $DIR  ($(du -sh "$DIR" | cut -f1))"
BASH
chmod +x "infra/scripts/backup.sh"
success "Install / upgrade / backup scripts"

# ── GitHub Actions ────────────────────────────────────────────────────────────
section "GitHub Actions CI/CD"

GH=".github/workflows"

cat > "$GH/ci.yml" << 'YAML'
name: CI
on:
  push:
    branches: ["**"]
  pull_request:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
env:
  DOTNET_NOLOGO: true
  DOTNET_CLI_TELEMETRY_OPTOUT: true

jobs:
  dotnet:
    name: .NET Build & Test
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_DB: lex_test, POSTGRES_USER: lex, POSTGRES_PASSWORD: testpassword }
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
      rabbitmq:
        image: rabbitmq:3-alpine
        ports: ["5672:5672"]
        options: --health-cmd "rabbitmq-diagnostics ping" --health-interval 10s --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with: { global-json-file: global.json }
      - uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: nuget-${{ hashFiles('**/*.csproj') }}
      - run: dotnet restore Lex.sln
      - run: dotnet build Lex.sln --no-restore -c Release
      - run: dotnet test Lex.sln --no-build -c Release --filter "Category!=Integration" --logger "trx" --collect:"XPlat Code Coverage"
      - run: dotnet format Lex.sln --verify-no-changes
      - uses: codecov/codecov-action@v4
        with: { files: "**/coverage.cobertura.xml" }

  client:
    name: Next.js Build & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "20", cache: "npm", cache-dependency-path: client/package-lock.json }
      - run: npm ci
        working-directory: client
      - run: npx tsc --noEmit
        working-directory: client
      - run: npm run lint
        working-directory: client
      - run: npm run test
        working-directory: client
      - run: npm run build
        working-directory: client

  docker:
    name: Validate Dockerfiles
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -f src/Host/Lex.API/Dockerfile . -t lex-api:ci
      - run: docker build -f client/Dockerfile client/ -t lex-web:ci
YAML
success "ci.yml"

cat > "$GH/cd-staging.yml" << 'YAML'
name: CD — Staging
on:
  push:
    branches: [main]
env:
  IMAGE_API: ghcr.io/${{ github.repository_owner }}/lex-api
  IMAGE_WEB: ghcr.io/${{ github.repository_owner }}/lex-web
jobs:
  build-push:
    runs-on: ubuntu-latest
    permissions: { contents: read, packages: write }
    outputs:
      sha: ${{ steps.meta.outputs.sha }}
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with: { registry: ghcr.io, username: "${{ github.actor }}", password: "${{ secrets.GITHUB_TOKEN }}" }
      - id: meta
        run: echo "sha=${GITHUB_SHA::8}" >> "$GITHUB_OUTPUT"
      - uses: docker/build-push-action@v5
        with: { context: ".", file: src/Host/Lex.API/Dockerfile, push: true, tags: "${{ env.IMAGE_API }}:${{ steps.meta.outputs.sha }},${{ env.IMAGE_API }}:staging" }
      - uses: docker/build-push-action@v5
        with: { context: client, file: client/Dockerfile, push: true, tags: "${{ env.IMAGE_WEB }}:${{ steps.meta.outputs.sha }},${{ env.IMAGE_WEB }}:staging" }
  deploy:
    needs: build-push
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USER }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script: |
            cd /opt/lex
            LEX_VERSION=${{ needs.build-push.outputs.sha }} ./infra/scripts/upgrade.sh
YAML
success "cd-staging.yml"

cat > "$GH/cd-release.yml" << 'YAML'
name: CD — Release
on:
  push:
    tags: ["v*.*.*"]
env:
  IMAGE_API: ghcr.io/${{ github.repository_owner }}/lex-api
  IMAGE_WEB: ghcr.io/${{ github.repository_owner }}/lex-web
jobs:
  release:
    runs-on: ubuntu-latest
    permissions: { contents: write, packages: write }
    steps:
      - uses: actions/checkout@v4
      - id: version
        run: echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"
      - uses: docker/login-action@v3
        with: { registry: ghcr.io, username: "${{ github.actor }}", password: "${{ secrets.GITHUB_TOKEN }}" }
      - uses: docker/build-push-action@v5
        with: { context: ".", file: src/Host/Lex.API/Dockerfile, push: true, tags: "${{ env.IMAGE_API }}:${{ steps.version.outputs.version }}" }
      - uses: docker/build-push-action@v5
        with: { context: client, file: client/Dockerfile, push: true, tags: "${{ env.IMAGE_WEB }}:${{ steps.version.outputs.version }}" }
      - name: Save air-gap tarballs
        run: |
          V=${{ steps.version.outputs.version }}
          docker pull ${{ env.IMAGE_API }}:$V
          docker pull ${{ env.IMAGE_WEB }}:$V
          docker save ${{ env.IMAGE_API }}:$V | gzip > lex-api-$V.tar.gz
          docker save ${{ env.IMAGE_WEB }}:$V | gzip > lex-web-$V.tar.gz
      - name: Assemble release ZIP
        run: |
          V=${{ steps.version.outputs.version }}
          D="lex-$V"
          mkdir -p "$D/images"
          sed "s|:latest|:$V|g" infra/docker-compose.yml > "$D/docker-compose.yml"
          cp infra/.env.template "$D/.env.template"
          cp infra/scripts/install.sh infra/scripts/upgrade.sh infra/scripts/backup.sh "$D/"
          cp -r infra/keycloak "$D/"
          mv lex-api-$V.tar.gz lex-web-$V.tar.gz "$D/images/"
          zip -r "lex-$V.zip" "$D/"
      - uses: softprops/action-gh-release@v2
        with: { name: "Lex ${{ github.ref_name }}", generate_release_notes: true, files: "lex-${{ steps.version.outputs.version }}.zip" }
YAML
success "cd-release.yml"

cat > ".github/dependabot.yml" << 'YAML'
version: 2
updates:
  - package-ecosystem: nuget
    directory: "/"
    schedule: { interval: weekly }
    groups:
      aspnetcore: { patterns: ["Microsoft.AspNetCore.*", "Microsoft.EntityFrameworkCore.*"] }
      masstransit: { patterns: ["MassTransit*"] }
  - package-ecosystem: npm
    directory: "/client"
    schedule: { interval: weekly }
  - package-ecosystem: docker
    directory: "/infra"
    schedule: { interval: weekly }
  - package-ecosystem: github-actions
    directory: "/"
    schedule: { interval: weekly }
YAML
success "dependabot.yml"

# ── Next.js client ────────────────────────────────────────────────────────────
section "Next.js client scaffold"

C="client"
for d in \
  "$C/app/(auth)/login" "$C/app/(app)/dashboard" \
  "$C/app/(app)/diary" "$C/app/(app)/scheduling" "$C/app/(app)/lessons" \
  "$C/app/(app)/assessments" "$C/app/(app)/delivery" \
  "$C/app/(app)/files" "$C/app/(app)/reporting" \
  "$C/components/ui" "$C/components/layout" "$C/components/forms" \
  "$C/components/diagrams" "$C/components/documents" \
  "$C/lib/api" "$C/lib/signalr" "$C/lib/auth" \
  "$C/lib/store" "$C/lib/types" "$C/lib/utils" "$C/lib/pwa" \
  "$C/public/icons" "$C/public/screenshots" \
  "$C/styles" "$C/tests/mocks"; do
  mkdir -p "$d"
done

cat > "$C/package.json" << 'JSON'
{
  "name": "lex-web",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev":        "next dev --turbopack",
    "build":      "next build",
    "start":      "next start",
    "lint":       "next lint",
    "test":       "vitest run",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "next": "15.0.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "@tanstack/react-query": "^5.0.0",
    "@tanstack/react-query-devtools": "^5.0.0",
    "zustand": "^4.5.0",
    "react-hook-form": "^7.52.0",
    "@hookform/resolvers": "^3.9.0",
    "zod": "^3.23.0",
    "@microsoft/signalr": "^8.0.0",
    "keycloak-js": "^24.0.0",
    "@radix-ui/react-dialog": "^1.1.0",
    "@radix-ui/react-dropdown-menu": "^2.1.0",
    "@radix-ui/react-toast": "^1.2.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.0",
    "tailwind-merge": "^2.3.0",
    "lucide-react": "^0.400.0",
    "reactflow": "^11.11.0",
    "@tiptap/react": "^2.4.0",
    "@tiptap/starter-kit": "^2.4.0",
    "framer-motion": "^11.0.0"
  },
  "devDependencies": {
    "typescript": "^5.5.0",
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@types/node": "^20.0.0",
    "tailwindcss": "^3.4.0",
    "postcss": "^8.4.0",
    "autoprefixer": "^10.4.0",
    "eslint": "^8.57.0",
    "eslint-config-next": "15.0.0",
    "vitest": "^1.6.0",
    "@vitest/ui": "^1.6.0",
    "@testing-library/react": "^16.0.0",
    "@testing-library/user-event": "^14.5.0",
    "msw": "^2.3.0",
    "jsdom": "^24.0.0"
  }
}
JSON

cat > "$C/tsconfig.json" << 'JSON'
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
JSON

cat > "$C/next.config.ts" << 'TS'
import type { NextConfig } from "next";
const config: NextConfig = {
  output: "standalone",
  reactStrictMode: true,
  poweredByHeader: false,
  async headers() {
    return [{ source: "/(.*)", headers: [
      { key: "X-Frame-Options",        value: "DENY" },
      { key: "X-Content-Type-Options", value: "nosniff" },
      { key: "Referrer-Policy",        value: "strict-origin-when-cross-origin" },
    ]}];
  },
};
export default config;
TS

cat > "$C/tailwind.config.ts" << 'TS'
import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary:    "hsl(var(--color-primary))",
        secondary:  "hsl(var(--color-secondary))",
        background: "hsl(var(--color-background))",
        foreground: "hsl(var(--color-foreground))",
        muted:      "hsl(var(--color-muted))",
        border:     "hsl(var(--color-border))",
      },
    },
  },
  plugins: [],
};
export default config;
TS

cat > "$C/styles/globals.css" << 'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;
@layer base {
  :root {
    --color-primary:    221 71% 35%;
    --color-secondary:  199 80% 40%;
    --color-background: 0 0% 100%;
    --color-foreground: 222 47% 11%;
    --color-muted:      210 40% 96%;
    --color-border:     214 32% 91%;
  }
}
CSS

# Root pages
cat > "$C/app/layout.tsx" << 'TSX'
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "@/styles/globals.css";
const inter = Inter({ subsets: ["latin"] });
export const metadata: Metadata = { title: { default: "Lex", template: "%s | Lex" }, manifest: "/manifest.webmanifest" };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body className={inter.className}>{children}</body></html>;
}
TSX
cat > "$C/app/page.tsx" << 'TSX'
import { redirect } from "next/navigation";
export default function RootPage() { redirect("/dashboard"); }
TSX
cat > "$C/app/(auth)/login/page.tsx" << 'TSX'
export default function LoginPage() {
  return <main className="flex min-h-screen items-center justify-center"><p>Redirecting to login…</p></main>;
}
TSX
cat > "$C/app/(app)/layout.tsx" << 'TSX'
"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
export default function AppLayout({ children }: { children: React.ReactNode }) {
  const [qc] = useState(() => new QueryClient({ defaultOptions: { queries: { staleTime: 30_000, retry: 1 } } }));
  return <QueryClientProvider client={qc}><div className="flex min-h-screen">{children}</div></QueryClientProvider>;
}
TSX
cat > "$C/app/(app)/dashboard/page.tsx" << 'TSX'
export const metadata = { title: "Dashboard" };
export default function DashboardPage() {
  return <div className="p-6"><h1 className="text-2xl font-semibold">Dashboard</h1></div>;
}
TSX

# Module page stubs
for MOD in diary scheduling lessons assessments delivery files reporting; do
  cat > "$C/app/(app)/$MOD/page.tsx" << TSX
export const metadata = { title: "${MOD^}" };
export default function ${MOD^}Page() {
  return <div className="p-6"><h1 className="text-2xl font-semibold">${MOD^}</h1></div>;
}
TSX
done

# API client
cat > "$C/lib/api/client.ts" << 'TS'
import type { ProblemDetails } from "@/lib/types/common";
export class ApiError extends Error {
  constructor(public readonly problem: ProblemDetails, public readonly status: number) {
    super(problem.title ?? "API error");
  }
}
export interface ApiFetchOptions extends RequestInit { params?: Record<string, string | number | boolean | undefined>; body?: unknown; }
export async function apiFetch<T>(url: string, options: ApiFetchOptions = {}): Promise<T> {
  const { params, body, ...rest } = options;
  const fullUrl = params ? `${url}?${new URLSearchParams(Object.entries(params).filter(([,v]) => v !== undefined).map(([k,v]) => [k, String(v)]))}` : url;
  const response = await fetch(fullUrl, { ...rest, headers: { "Content-Type": "application/json", ...rest.headers }, body: body !== undefined ? JSON.stringify(body) : rest.body });
  if (response.status === 204) return undefined as T;
  if (!response.ok) { const p = await response.json().catch(() => ({ title: "Unknown error", status: response.status })) as ProblemDetails; throw new ApiError(p, response.status); }
  return response.json() as Promise<T>;
}
TS

cat > "$C/lib/types/common.ts" << 'TS'
export interface ProblemDetails { type?: string; title?: string; status?: number; detail?: string; errors?: Array<{ field: string; message: string }>; }
export interface PagedResult<T> { items: T[]; totalCount: number; pageNumber: number; pageSize: number; hasNextPage: boolean; }
TS

# Zustand stores
cat > "$C/lib/store/useAuthStore.ts" << 'TS'
import { create } from "zustand";
interface AuthState { userId: string | null; email: string | null; roles: string[]; isAuthenticated: boolean; setUser: (u: { userId: string; email: string; roles: string[] }) => void; clearUser: () => void; }
export const useAuthStore = create<AuthState>(set => ({ userId: null, email: null, roles: [], isAuthenticated: false, setUser: ({ userId, email, roles }) => set({ userId, email, roles, isAuthenticated: true }), clearUser: () => set({ userId: null, email: null, roles: [], isAuthenticated: false }) }));
TS
cat > "$C/lib/store/useSignalRStore.ts" << 'TS'
import { create } from "zustand";
type S = "disconnected" | "connecting" | "connected" | "reconnecting";
export const useSignalRStore = create<{ status: S; setStatus: (s: S) => void }>(set => ({ status: "disconnected", setStatus: status => set({ status }) }));
TS

cat > "$C/public/manifest.webmanifest" << 'JSON'
{ "name": "Lex", "short_name": "Lex", "start_url": "/dashboard", "display": "standalone", "background_color": "#ffffff", "theme_color": "#1A3A52", "icons": [{ "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" }, { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" }] }
JSON

cat > "$C/Dockerfile" << 'DOCKERFILE'
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static     ./.next/static
COPY --from=build /app/public           ./public
EXPOSE 3000
CMD ["node", "server.js"]
DOCKERFILE

cat > "$C/middleware.ts" << 'TS'
import { NextRequest, NextResponse } from "next/server";
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (pathname.startsWith("/(auth)") || pathname === "/") return NextResponse.next();
  const session = request.cookies.get("session");
  if (!session) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("returnTo", pathname);
    return NextResponse.redirect(loginUrl);
  }
  return NextResponse.next();
}
export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico|icons|manifest).*)"] };
TS

cat > "$C/tests/mocks/handlers.ts" << 'TS'
import { http, HttpResponse } from "msw";
export const handlers = [
  http.get("/healthz", () => HttpResponse.json({ status: "ok" })),
  // Add module handlers here as you build features:
  // ...diaryHandlers,
];
TS

success "Next.js client"

# ── Makefile ──────────────────────────────────────────────────────────────────
section "Makefile"

cat > "Makefile" << 'MAKEFILE'
# =============================================================================
# Lex Platform — developer workflow
# make help   — list all targets
# =============================================================================
SHELL := /usr/bin/env bash
APP   ?= Lex
MOD   ?=
FEAT  ?=
TYPE  ?= command
SVC   ?=
FORM  ?=
TITLE ?=

SCRIPTS := scripts

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -v '^_' \
	  | awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2}'

# ── Dev stack ──────────────────────────────────────────────────────────────
.PHONY: up down logs
up:   ## Start the full dev stack
	docker compose -f infra/docker-compose.yml -f infra/docker-compose.override.yml up -d
down: ## Stop the dev stack
	docker compose -f infra/docker-compose.yml -f infra/docker-compose.override.yml down
logs: ## Tail API logs
	docker compose -f infra/docker-compose.yml -f infra/docker-compose.override.yml logs -f api

# ── Build & test ───────────────────────────────────────────────────────────
.PHONY: build test test-arch lint
build:     ## Build the .NET solution
	dotnet build Lex.sln -c Release
test:      ## Run all tests
	dotnet test Lex.sln -c Release --filter "Category!=Integration"
test-arch: ## Run architecture boundary tests only
	dotnet test tests/Lex.ArchitectureTests -c Release
lint:      ## Verify .NET formatting
	dotnet format Lex.sln --verify-no-changes

# ── Database ───────────────────────────────────────────────────────────────
.PHONY: migrate
migrate: ## Add EF Core migration. Requires MOD= e.g. make migrate MOD=DiaryManagement
	$(call require-var,MOD,"module name (PascalCase)")
	dotnet ef migrations add InitialCreate \
	  --project src/Modules/Lex.Module.$(MOD)/Lex.Module.$(MOD).Infrastructure \
	  --startup-project src/Host/Lex.API

# ── Scaffolding ────────────────────────────────────────────────────────────
.PHONY: new-module new-feature new-integration new-adr new-adr-client new-client-module new-form new-module-full
new-module: ## New backend module. MOD=PascalName
	$(call require-var,MOD,"module name")
	@chmod +x $(SCRIPTS)/new-module.sh && $(SCRIPTS)/new-module.sh "$(MOD)" "$(APP)"

new-feature: ## New vertical slice. MOD= FEAT= TYPE=[command|query|event]
	$(call require-var,MOD,"module name")
	$(call require-var,FEAT,"feature name")
	@chmod +x $(SCRIPTS)/new-feature.sh && $(SCRIPTS)/new-feature.sh "$(MOD)" "$(FEAT)" "$(TYPE)" "$(APP)"

new-integration: ## New external API integration. MOD= SVC=
	$(call require-var,MOD,"module name")
	$(call require-var,SVC,"service name")
	@chmod +x $(SCRIPTS)/new-integration.sh && $(SCRIPTS)/new-integration.sh "$(MOD)" "$(SVC)" "$(APP)"

new-adr: ## New backend ADR. TITLE="..."
	$(call require-var,TITLE,"ADR title")
	@chmod +x $(SCRIPTS)/new-adr.sh && $(SCRIPTS)/new-adr.sh "$(TITLE)"

new-adr-client: ## New frontend ADR. TITLE="..."
	$(call require-var,TITLE,"ADR title")
	@chmod +x $(SCRIPTS)/new-adr.sh && $(SCRIPTS)/new-adr.sh "$(TITLE)" --client

new-client-module: ## New frontend module. MOD=lowercase
	$(call require-var,MOD,"module name (lowercase)")
	@chmod +x $(SCRIPTS)/new-client-module.sh && $(SCRIPTS)/new-client-module.sh "$(MOD)"

new-form: ## New React form component. FORM= MOD=
	$(call require-var,FORM,"form name")
	$(call require-var,MOD,"module name")
	@chmod +x $(SCRIPTS)/new-form.sh && $(SCRIPTS)/new-form.sh "$(FORM)" "$(MOD)"

new-module-full: ## Scaffold backend + frontend module pair. MOD=PascalName
	$(call require-var,MOD,"module name (PascalCase)")
	@chmod +x $(SCRIPTS)/new-module.sh && $(SCRIPTS)/new-module.sh "$(MOD)" "$(APP)"
	@chmod +x $(SCRIPTS)/new-client-module.sh && $(SCRIPTS)/new-client-module.sh "$$(echo '$(MOD)' | tr '[:upper:]' '[:lower:]')"

# ── Ops ─────────────────────────────────────────────────────────────────────
.PHONY: install upgrade backup
install: ## Run on-prem installer (from infra/)
	cd infra && bash scripts/install.sh
upgrade: ## Zero-downtime upgrade (from infra/)
	cd infra && bash scripts/upgrade.sh
backup:  ## Point-in-time backup (from infra/)
	cd infra && bash scripts/backup.sh

define require-var
  @if [ -z "$($(1))" ]; then echo ""; echo "  ERROR: $(1) is required.  make $(MAKECMDGOALS) $(1)=<$(2)>"; echo ""; exit 1; fi
endef
MAKEFILE
success "Makefile"

# ── First ADRs ────────────────────────────────────────────────────────────────
section "Initial ADRs"

mkdir -p docs/adr

cat > "docs/adr/ADR-001.md" << 'MD'
# ADR-001: Modular Monolith over Microservices

## Status
Accepted

## Date
$(date '+%Y-%m-%d')

## Context
Lex is an on-premises educational platform. Institutions install it on a single server.
The team is small and needs operational simplicity without sacrificing the ability to scale
specific modules independently if needed in future.

## Decision
Build as a modular monolith: a single deployable unit composed of strictly isolated modules.
Each module may be extracted to a microservice when a concrete operational need (independent
scaling, independent deployment cadence, team ownership) justifies it.

## Consequences
- Single docker compose stack, single DB instance, one deployment unit
- Module boundaries enforced by architecture tests on every CI build
- Extraction is possible at any time because modules never reference each other directly
MD

cat > "docs/adr/ADR-002.md" << 'MD'
# ADR-002: MinIO for Object Storage

## Status
Accepted

## Date
$(date '+%Y-%m-%d')

## Context
Lex needs to store images, attachments, and generated files (PDFs, exports).
The platform must run entirely on-prem with no mandatory cloud dependency.
AWS S3-compatible APIs are widely supported.

## Decision
Self-hosted MinIO provides S3-compatible object storage in a single container.
The ObjectStorage module wraps the MinIO SDK behind a domain interface (IObjectStorageService)
so the backing implementation can be swapped to AWS S3 or Azure Blob Storage
without changing any domain or application code.

## Consequences
- No cloud dependency for file storage
- S3-compatible: future migration to a managed service requires only a connection string change
- MinIO console exposed on port 9001 for administration
MD

cat > "docs/adr/ADR-003.md" << 'MD'
# ADR-003: AssessmentCreation and AssessmentDelivery as Separate Modules

## Status
Accepted

## Date
$(date '+%Y-%m-%d')

## Context
Assessments have two distinct lifecycles: authoring (teacher creates and configures)
and delivery (students receive, take, and submit; teacher processes results).
These have different actors, different performance characteristics, and different
future scaling needs.

## Decision
Split into AssessmentCreation and AssessmentDelivery modules.
AssessmentDelivery consumes AssessmentCreatedEvent from AssessmentCreation via MassTransit.
There is no direct project reference between them.

## Consequences
- Clear separation of authoring from delivery concerns
- AssessmentDelivery can be extracted and scaled independently if needed
- Slightly more coordination required when adding features that span both lifecycles
MD

success "Initial ADRs"

# ── Final summary ──────────────────────────────────────────────────────────────
section "Done!"

echo -e "${BOLD}Lex platform scaffold complete.${RESET}"
echo ""
echo "  Solution        : Lex.sln"
echo "  Modules (11)    : DiaryManagement, Scheduling, LessonManagement,"
echo "                    AssessmentCreation, AssessmentDelivery, GoogleIntegration,"
echo "                    FileProcessing, ImportExport, ObjectStorage,"
echo "                    Reporting, Notifications"
echo "  Test projects   : 11 module + ArchitectureTests + IntegrationTests"
echo "  Client          : client/ (Next.js 15)"
echo "  Infra           : docker-compose + install/upgrade/backup scripts"
echo "  CI/CD           : .github/workflows/ (ci, cd-staging, cd-release)"
echo "  ADRs            : docs/adr/ (3 initial)"
echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo ""
echo "  1. dotnet restore Lex.sln"
echo "  2. cd client && npm install"
echo "  3. cp infra/.env.template infra/.env  && fill in values"
echo "  4. make up                            # start the dev stack"
echo "  5. make migrate MOD=DiaryManagement   # add first migration"
echo "  6. make new-feature MOD=DiaryManagement FEAT=CreateDiaryEntry TYPE=command"
echo ""
echo "  In GitHub repository settings, create Environments:"
echo "    staging  → add secrets: STAGING_HOST, STAGING_USER, STAGING_SSH_KEY"
echo ""
echo "  make help  — see all available commands"
echo ""