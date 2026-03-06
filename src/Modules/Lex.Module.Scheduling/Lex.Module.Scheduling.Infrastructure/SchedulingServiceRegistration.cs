using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.Scheduling;
public static class SchedulingServiceRegistration
{
    public static IServiceCollection AddSchedulingModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.Scheduling.Persistence.SchedulingDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(SchedulingServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(SchedulingPermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(SchedulingPermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
