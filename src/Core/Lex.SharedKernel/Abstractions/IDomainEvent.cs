namespace Lex.SharedKernel.Abstractions;
/// <summary>
/// Marker for all domain events. Events are used for side-effects and
/// cross-module communication — NOT as the source of truth for state.
/// </summary>
public interface IDomainEvent
{
    Guid CorrelationId { get; }
    DateTimeOffset OccurredAt { get; }
}
