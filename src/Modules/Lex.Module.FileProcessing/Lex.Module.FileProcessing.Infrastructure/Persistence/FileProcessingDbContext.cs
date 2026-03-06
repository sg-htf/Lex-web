using Microsoft.EntityFrameworkCore;
namespace Lex.Module.FileProcessing.Persistence;
public sealed class FileProcessingDbContext : DbContext
{
    public FileProcessingDbContext(DbContextOptions<FileProcessingDbContext> options) : base(options) { }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("fileprocessing");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(FileProcessingDbContext).Assembly);
    }
}
