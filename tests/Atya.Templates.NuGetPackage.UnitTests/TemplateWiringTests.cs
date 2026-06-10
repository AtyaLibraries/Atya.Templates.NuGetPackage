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
}
