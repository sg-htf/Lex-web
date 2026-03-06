using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.Reporting;
public static class ReportingServiceRegistration
{
    public static IServiceCollection AddReportingModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.Reporting.Persistence.ReportingDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(ReportingServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(ReportingPermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(ReportingPermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
