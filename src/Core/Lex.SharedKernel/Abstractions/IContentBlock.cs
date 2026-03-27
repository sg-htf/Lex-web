using System;
using System.Collections.Generic;

namespace Lex.SharedKernel.Domain.Models;
//TODO Add docs

/// <summary>
/// A generic base for blocks that carry specific data models.
/// </summary>
public interface IContentBlock<out TData>
{
    Guid Id { get; }
    Date CreatedDate {get;} //TODO find correct type
    IReadDictionary<string, string>? Metadata {get;}
    TData Content { get; }
}

// --- ContentBlock Data Models ---

public record TextData(string Text, TextStyle Style);
public record AttachmentData(Uri Source, FileType Type, string Caption);
public record DynamicData(string Script, DynamicInteractivity Engine);
public record LinkData(Uri Url, string DisplayName);

// --- Enums ---

public enum TextStyle { Title, H1, H2, H3, Body, Caption }
public enum FileType { RasterImage, VectorImage, Video, Audio, Unknown }
public enum DynamicInteractivity { DSL, Python, JavaScript, None }
