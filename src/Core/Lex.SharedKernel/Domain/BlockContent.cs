namespace Lex.SharedKernel.Domain;

/// <summary>
/// Portable block-list content model.
/// Used by LessonManagement and DiaryManagement.
/// Rendered as document / outline / diagram / mind-map depending on block types.
/// </summary>
public sealed record BlockContent(IReadOnlyList<ContentBlock> Blocks)
{
    public static BlockContent Empty() => new([]);
}

public sealed record ContentBlock(
    Guid   Id,
    string Type,       // "paragraph"|"heading"|"bullet"|"node"|"edge"|"image"
    string? Text,
    Guid?  ParentId,   // null = root; set for nested/diagram children
    int    Order,
    IReadOnlyDictionary<string, string>? Metadata  // extensible per block type
);
