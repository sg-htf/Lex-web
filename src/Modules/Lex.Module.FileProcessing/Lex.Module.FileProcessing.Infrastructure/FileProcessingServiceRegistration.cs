using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.FileProcessing;
public static class FileProcessingServiceRegistration
{
    public static IServiceCollection AddFileProcessingModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.FileProcessing.Persistence.FileProcessingDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(FileProcessingServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(FileProcessingPermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(FileProcessingPermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
