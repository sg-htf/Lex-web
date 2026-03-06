using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.DiaryManagement;
public static class DiaryManagementServiceRegistration
{
    public static IServiceCollection AddDiaryManagementModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.DiaryManagement.Persistence.DiaryManagementDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(DiaryManagementServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(DiaryManagementPermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(DiaryManagementPermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
