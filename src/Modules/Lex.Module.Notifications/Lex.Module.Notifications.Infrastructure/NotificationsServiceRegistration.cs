using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.Notifications;
public static class NotificationsServiceRegistration
{
    public static IServiceCollection AddNotificationsModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.Notifications.Persistence.NotificationsDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(NotificationsServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(NotificationsPermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(NotificationsPermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
