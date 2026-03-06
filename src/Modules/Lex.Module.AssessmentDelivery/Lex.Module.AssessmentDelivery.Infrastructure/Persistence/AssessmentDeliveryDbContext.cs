using Microsoft.EntityFrameworkCore;
namespace Lex.Module.AssessmentDelivery.Persistence;
public sealed class AssessmentDeliveryDbContext : DbContext
{
    public AssessmentDeliveryDbContext(DbContextOptions<AssessmentDeliveryDbContext> options) : base(options) { }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("assessmentdelivery");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AssessmentDeliveryDbContext).Assembly);
    }
}
