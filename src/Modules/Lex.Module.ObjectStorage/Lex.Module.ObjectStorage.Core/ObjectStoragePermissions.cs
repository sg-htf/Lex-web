namespace Lex.Module.ObjectStorage;
public static class ObjectStoragePermissions
{
    private const string Prefix = "objectstorage";
    public const string View   = $"{Prefix}.view";
    public const string Create = $"{Prefix}.create";
    public const string Edit   = $"{Prefix}.edit";
    public const string Delete = $"{Prefix}.delete";
}
