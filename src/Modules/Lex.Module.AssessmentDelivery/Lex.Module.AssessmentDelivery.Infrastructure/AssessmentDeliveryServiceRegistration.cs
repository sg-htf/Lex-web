using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.AssessmentDelivery;
public static class AssessmentDeliveryServiceRegistration
{
    public static IServiceCollection AddAssessmentDeliveryModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.AssessmentDelivery.Persistence.AssessmentDeliveryDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(AssessmentDeliveryServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(AssessmentDeliveryPermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(AssessmentDeliveryPermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
