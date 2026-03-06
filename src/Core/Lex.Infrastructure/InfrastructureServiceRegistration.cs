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
