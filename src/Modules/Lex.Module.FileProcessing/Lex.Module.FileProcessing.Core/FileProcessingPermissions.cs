namespace Lex.Module.FileProcessing;
public static class FileProcessingPermissions
{
    private const string Prefix = "fileprocessing";
    public const string View   = $"{Prefix}.view";
    public const string Create = $"{Prefix}.create";
    public const string Edit   = $"{Prefix}.edit";
    public const string Delete = $"{Prefix}.delete";
}
