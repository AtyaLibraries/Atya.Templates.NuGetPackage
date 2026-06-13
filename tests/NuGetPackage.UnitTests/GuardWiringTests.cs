using Atya.Foundation.Guards;

namespace Atya.Templates.NuGetPackage.UnitTests;

public sealed class GuardWiringTests
{
    [Fact]
    public void Guards_Are_Available()
    {
        var assembly = System.Reflection.Assembly.Load("Atya.Foundation.Guards");

        assembly.Should().NotBeNull();
        typeof(Guard).Assembly.GetName().Name.Should().Be("Atya.Foundation.Guards");
    }
}
