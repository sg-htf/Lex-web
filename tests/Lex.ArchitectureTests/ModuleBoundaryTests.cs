using NetArchTest.Rules;
using Xunit;
using FluentAssertions;

namespace Lex.ArchitectureTests;

/// <summary>
/// Enforces the project reference rules from the architecture reference (§2.2).
/// Runs on every CI build — boundary violations are caught before they compound.
/// </summary>
public sealed class ModuleBoundaryTests
{
    private static readonly string[] Modules =
    [
        "DiaryManagement", "Scheduling", "LessonManagement",
        "AssessmentCreation", "AssessmentDelivery", "GoogleIntegration",
        "FileProcessing", "ImportExport", "ObjectStorage",
        "Reporting", "Notifications"
    ];

    [Fact]
    public void ModuleCore_ShouldNotReference_EntityFramework()
    {
        foreach (var module in Modules)
        {
            var result = Types.InAssembly(GetCoreAssembly(module))
                .ShouldNot().HaveDependencyOn("Microsoft.EntityFrameworkCore").GetResult();
            result.IsSuccessful.Should().BeTrue($"{module}.Core must not reference EF Core");
        }
    }

    [Fact]
    public void ModuleCore_ShouldNotReference_MassTransit()
    {
        foreach (var module in Modules)
        {
            var result = Types.InAssembly(GetCoreAssembly(module))
                .ShouldNot().HaveDependencyOn("MassTransit").GetResult();
            result.IsSuccessful.Should().BeTrue($"{module}.Core must not reference MassTransit");
        }
    }

    [Fact]
    public void ModuleCore_ShouldNotReference_OtherModules()
    {
        foreach (var module in Modules)
        {
            foreach (var other in Modules.Where(m => m != module).Select(m => $"Lex.Module.{m}"))
            {
                var result = Types.InAssembly(GetCoreAssembly(module))
                    .ShouldNot().HaveDependencyOn(other).GetResult();
                result.IsSuccessful.Should().BeTrue($"{module}.Core must not reference {other}");
            }
        }
    }

    [Fact]
    public void Handlers_ShouldBeInternal()
    {
        foreach (var module in Modules)
        {
            var result = Types.InAssembly(GetCoreAssembly(module))
                .That().HaveNameEndingWith("Handler")
                .Should().NotBePublic().GetResult();
            result.IsSuccessful.Should().BeTrue($"Handlers in {module} should be internal");
        }
    }

    private static System.Reflection.Assembly GetCoreAssembly(string module) =>
        System.Reflection.Assembly.Load($"Lex.Module.{module}.Core");
}
