using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Lex.Module.AssessmentCreation;
public static class AssessmentCreationServiceRegistration
{
    public static IServiceCollection AddAssessmentCreationModule(
        this IServiceCollection services, IConfiguration configuration)
    {
        var cs = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Connection string 'Default' not configured.");
        services.AddDbContext<Lex.Module.AssessmentCreation.Persistence.AssessmentCreationDbContext>(o =>
            o.UseNpgsql(cs, b => b.MigrationsAssembly(typeof(AssessmentCreationServiceRegistration).Assembly.FullName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(AssessmentCreationPermissions).Assembly));
        services.AddValidatorsFromAssembly(typeof(AssessmentCreationPermissions).Assembly);
        // TODO: add repositories, consumers, external API clients
        return services;
    }
}
