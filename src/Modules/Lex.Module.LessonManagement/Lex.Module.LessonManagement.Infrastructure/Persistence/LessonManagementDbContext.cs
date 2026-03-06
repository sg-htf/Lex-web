using Microsoft.EntityFrameworkCore;
namespace Lex.Module.LessonManagement.Persistence;
public sealed class LessonManagementDbContext : DbContext
{
    public LessonManagementDbContext(DbContextOptions<LessonManagementDbContext> options) : base(options) { }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("lessonmanagement");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(LessonManagementDbContext).Assembly);
    }
}
