using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.ObjectStorage;
public static class ObjectStorageServiceRegistration
{
    public static IServiceCollection AddObjectStorageModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.ObjectStorage.Persistence.ObjectStorageDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(ObjectStorageServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(ObjectStoragePermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(ObjectStoragePermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
