using Microsoft.EntityFrameworkCore;
namespace Lex.Module.AssessmentCreation.Persistence;
public sealed class AssessmentCreationDbContext : DbContext
{
    public AssessmentCreationDbContext(DbContextOptions<AssessmentCreationDbContext> options) : base(options) { }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("assessmentcreation");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AssessmentCreationDbContext).Assembly);
    }
}
