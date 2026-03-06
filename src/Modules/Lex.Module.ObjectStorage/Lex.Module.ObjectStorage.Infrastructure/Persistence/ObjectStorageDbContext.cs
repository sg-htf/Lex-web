using Microsoft.EntityFrameworkCore;
namespace Lex.Module.ObjectStorage.Persistence;
public sealed class ObjectStorageDbContext : DbContext
{
    public ObjectStorageDbContext(DbContextOptions<ObjectStorageDbContext> options) : base(options) { }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema("objectstorage");
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ObjectStorageDbContext).Assembly);
    }
}
