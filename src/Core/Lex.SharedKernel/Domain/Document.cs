public class Document
{
    public Guid Id { get; set; }
    public string Title { get; set; }
    public List<IContentBlock> Blocks { get; init; }
}
