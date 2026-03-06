using Microsoft.EntityFrameworkCore;
namespace Lex.Module.GoogleIntegration.Persistence;
public sealed class GoogleIntegrationDbContext : DbContext
{
    public GoogleIntegrationDbContext(DbContextOptions<GoogleIntegrationDbContext> options) : base(options) { }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("googleintegration");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(GoogleIntegrationDbContext).Assembly);
    }
}
