using Microsoft.EntityFrameworkCore;
namespace Lex.Module.ImportExport.Persistence;
public sealed class ImportExportDbContext : DbContext
{
    public ImportExportDbContext(DbContextOptions<ImportExportDbContext> options) : base(options) { }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("importexport");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ImportExportDbContext).Assembly);
    }
}
