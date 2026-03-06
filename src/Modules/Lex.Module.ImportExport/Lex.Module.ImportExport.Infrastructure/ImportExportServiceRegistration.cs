using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.ImportExport;
public static class ImportExportServiceRegistration
{
    public static IServiceCollection AddImportExportModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.ImportExport.Persistence.ImportExportDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(ImportExportServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(ImportExportPermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(ImportExportPermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
