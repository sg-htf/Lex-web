using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.LessonManagement;
public static class LessonManagementServiceRegistration
{
    public static IServiceCollection AddLessonManagementModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.LessonManagement.Persistence.LessonManagementDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(LessonManagementServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(LessonManagementPermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(LessonManagementPermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
