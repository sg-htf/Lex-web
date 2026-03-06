using Microsoft.EntityFrameworkCore;
namespace Lex.Module.DiaryManagement.Persistence;
public sealed class DiaryManagementDbContext : DbContext
{
    public DiaryManagementDbContext(DbContextOptions<DiaryManagementDbContext> options) : base(options) { }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("diarymanagement");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(DiaryManagementDbContext).Assembly);
    }
}
