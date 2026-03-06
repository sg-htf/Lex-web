namespace Lex.SharedKernel.Abstractions;
public interface ICurrentUser
{
    Guid Id { get; }
    string Email { get; }
    string[] Roles { get; }
    string[] Permissions { get; }
    bool IsAuthenticated { get; }
    bool HasPermission(string permission);
}
