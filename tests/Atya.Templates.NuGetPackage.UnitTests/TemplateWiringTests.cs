namespace Atya.Templates.NuGetPackage.UnitTests;

public sealed class TemplateWiringTests
{
    [Fact]
    public void LibraryAssembly_Can_Be_Loaded()
    {
        var assembly = typeof(Atya.Templates.NuGetPackage.__PACKAGE_MARKER_NAME__Marker).Assembly;

        assembly.Should().NotBeNull();
        assembly.GetName().Name.Should().Be("Atya.Templates.NuGetPackage");
    }

    [Fact]
    public void Guards_Are_Available()
    {
        var assembly = System.Reflection.Assembly.Load("Atya.Foundation.Guards");

        assembly.Should().NotBeNull();
        typeof(Guard).Assembly.GetName().Name.Should().Be("Atya.Foundation.Guards");
    }
}
